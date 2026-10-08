from datetime import date, datetime, time, timedelta
from pathlib import Path
from uuid import uuid4
from hashlib import sha1
from time import time as unix_time
from urllib.parse import urlparse

from fastapi import HTTPException, UploadFile
import httpx
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from .config import settings
from .models import (
    Alert,
    CarePlan,
    CarePlanStatus,
    MedicationEvent,
    MedicationSchedule,
    Medicine,
    Patient,
    PrescriptionDocument,
)

ALLOWED_UPLOADS = {
    "application/pdf": ".pdf",
    "image/jpeg": ".jpg",
    "image/png": ".png",
}


def patient_for_user(db: Session, user_id: str) -> Patient:
    patient = db.scalar(select(Patient).where(Patient.user_id == user_id))
    if patient is None:
        raise HTTPException(status_code=404, detail="Patient profile not found")
    return patient


def next_plan_version(db: Session, patient_id: str) -> int:
    current = db.scalar(
        select(func.max(CarePlan.version)).where(CarePlan.patient_id == patient_id)
    )
    return (current or 0) + 1


def active_plan(db: Session, patient_id: str) -> CarePlan | None:
    return db.scalar(
        select(CarePlan)
        .where(
            CarePlan.patient_id == patient_id,
            CarePlan.status == CarePlanStatus.ACTIVE.value,
        )
        .order_by(CarePlan.version.desc())
    )


async def store_upload(patient_id: str, document: UploadFile) -> tuple[str, str]:
    if document.content_type not in ALLOWED_UPLOADS:
        raise HTTPException(status_code=415, detail="Only PDF, JPG, and PNG files are supported")
    data = await document.read(settings.max_upload_bytes + 1)
    if len(data) > settings.max_upload_bytes:
        raise HTTPException(status_code=413, detail="Document exceeds the 10 MB limit")
    if settings.cloudinary_url:
        secure_url, _ = await upload_to_cloudinary(
            patient_id,
            document.filename or "upload",
            document.content_type,
            data,
        )
        return secure_url, ""
    safe_name = f"{patient_id}-{uuid4()}{ALLOWED_UPLOADS[document.content_type]}"
    settings.upload_dir.mkdir(parents=True, exist_ok=True)
    path = settings.upload_dir / safe_name
    path.write_bytes(data)
    return str(path), data.decode("utf-8", errors="ignore") if document.content_type == "text/plain" else ""


async def upload_to_cloudinary(
    patient_id: str,
    filename: str,
    content_type: str | None,
    data: bytes,
) -> tuple[str, str]:
    parsed = urlparse(settings.cloudinary_url or "")
    if parsed.scheme != "cloudinary" or not parsed.hostname or not parsed.username or not parsed.password:
        raise HTTPException(status_code=500, detail="CLOUDINARY_URL is not configured correctly")

    timestamp = str(int(unix_time()))
    folder = f"caresync/{patient_id}"
    public_id = f"{uuid4()}"
    signature_payload = (
        f"folder={folder}&public_id={public_id}&timestamp={timestamp}{parsed.password}"
    )
    signature = sha1(signature_payload.encode("utf-8")).hexdigest()
    endpoint = f"https://api.cloudinary.com/v1_1/{parsed.hostname}/auto/upload"
    files = {
        "file": (filename, data, content_type or "application/octet-stream"),
    }
    form = {
        "api_key": parsed.username,
        "timestamp": timestamp,
        "folder": folder,
        "public_id": public_id,
        "signature": signature,
    }
    try:
        async with httpx.AsyncClient(timeout=30) as client:
            response = await client.post(endpoint, data=form, files=files)
            response.raise_for_status()
    except httpx.HTTPError as error:
        raise HTTPException(status_code=502, detail="Cloudinary upload failed") from error
    result = response.json()
    secure_url = result.get("secure_url")
    if not secure_url:
        raise HTTPException(status_code=502, detail="Cloudinary returned no secure URL")
    return secure_url, f"{folder}/{public_id}"


def add_medicines(
    db: Session,
    plan: CarePlan,
    medicines: list,
) -> list[Medicine]:
    result = []
    for item in medicines:
        medicine = Medicine(
            care_plan_id=plan.id,
            name=item.name,
            dose=item.dose,
            frequency=item.frequency,
            food_instruction=item.food_instruction,
            start_date=item.start_date,
            end_date=item.end_date,
            quantity=item.quantity,
        )
        db.add(medicine)
        db.flush()
        for scheduled_time in item.scheduled_times:
            db.add(
                MedicationSchedule(
                    medicine_id=medicine.id,
                    scheduled_time=scheduled_time,
                )
            )
        result.append(medicine)
    return result


def create_daily_events(db: Session, patient_id: str, plan: CarePlan, on_date: date) -> None:
    medicines = db.scalars(select(Medicine).where(Medicine.care_plan_id == plan.id)).all()
    for medicine in medicines:
        schedules = db.scalars(
            select(MedicationSchedule).where(MedicationSchedule.medicine_id == medicine.id)
        ).all()
        for schedule in schedules:
            scheduled_for = datetime.combine(on_date, schedule.scheduled_time)
            existing = db.scalar(
                select(MedicationEvent).where(
                    MedicationEvent.schedule_id == schedule.id,
                    MedicationEvent.scheduled_for == scheduled_for,
                )
            )
            if existing is None:
                db.add(
                    MedicationEvent(
                        patient_id=patient_id,
                        care_plan_id=plan.id,
                        schedule_id=schedule.id,
                        scheduled_for=scheduled_for,
                    )
                )


def create_hospital_alert_if_needed(db: Session, patient_id: str, event: MedicationEvent) -> None:
    day = event.scheduled_for.date()
    recent = db.scalars(
        select(MedicationEvent)
        .where(
            MedicationEvent.patient_id == patient_id,
            MedicationEvent.status == "MISSED",
            MedicationEvent.scheduled_for >= datetime.combine(
                day - timedelta(days=settings.hospital_missed_days_threshold - 1),
                time.min,
            ),
            MedicationEvent.scheduled_for <= datetime.combine(day, time.max),
        )
    ).all()
    missed_days = {item.scheduled_for.date() for item in recent}
    if len(missed_days) >= settings.hospital_missed_days_threshold:
        already_open = db.scalar(
            select(Alert).where(
                Alert.patient_id == patient_id,
                Alert.type == "HOSPITAL_ESCALATION",
                Alert.status != "RESOLVED",
            )
        )
        if already_open is None:
            db.add(
                Alert(
                    patient_id=patient_id,
                    type="HOSPITAL_ESCALATION",
                    severity="HIGH",
                    message="Repeated missed medication requires hospital follow-up.",
                )
            )
