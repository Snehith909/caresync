from contextlib import asynccontextmanager
from datetime import date, datetime, time, timedelta

from fastapi import Depends, FastAPI, File, Form, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import select
from sqlalchemy.orm import Session

from .config import settings
from .db import get_db, init_db
from .dependencies import Actor, get_actor, get_existing_user, require_roles, require_user
from .models import (
    Alert,
    AlertStatus,
    AuditLog,
    CarePlan,
    CarePlanStatus,
    FollowUp,
    MedicationEvent,
    MedicationSchedule,
    Medicine,
    Patient,
    PrescriptionDocument,
    Role,
    User,
    CompanionCheckIn,
    CompanionConversation,
    DoctorRequest,
    HealthSummary,
)
from .schemas import (
    AdherenceResponse,
    AlertResponse,
    CarePlanDetail,
    CarePlanDraftRequest,
    CarePlanResponse,
    ConditionRequest,
    FollowUpCreate,
    FollowUpResponse,
    HealthResponse,
    MedicationEventResponse,
    MedicationStatusRequest,
    MedicineCreate,
    PatientCreate,
    PatientResponse,
    RefillRequest,
    RefillResponse,
    UserCreate,
    UserResponse,
    UploadResponse,
    TranscriptionResponse,
    VoiceRequest,
    VoiceResponse,
    CompanionCheckInRequest,
    CompanionCheckInResponse,
    CompanionConversationRequest,
    CompanionConversationResponse,
    DoctorRequestCreate,
    DoctorRequestResponse,
    HealthSummaryResponse,
    HealthSummarySubmitResponse,
)
from .services import (
    active_plan,
    add_medicines,
    create_daily_events,
    create_hospital_alert_if_needed,
    next_plan_version,
    patient_for_user,
    store_upload,
    upload_to_cloudinary,
    generate_care_plan_with_gemini,
    generate_companion_answer,
)
from .transcription import transcribe_audio

@asynccontextmanager
async def lifespan(_: FastAPI):
    init_db()
    yield


app = FastAPI(
    title="CareSync API",
    description="REST API for doctor-approved post-discharge care plans.",
    version="1.0.0",
    lifespan=lifespan,
)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/health", response_model=HealthResponse)
def health() -> HealthResponse:
    return HealthResponse(status="ok", service="caresync-api")


@app.post("/voice/transcribe", response_model=TranscriptionResponse)
async def transcribe_voice(
    audio: UploadFile = File(...),
    _: Actor = Depends(get_actor),
) -> TranscriptionResponse:
    allowed_types = {
        "audio/wav": ".wav",
        "audio/x-wav": ".wav",
        "audio/mpeg": ".mp3",
        "audio/mp4": ".m4a",
        "audio/aac": ".aac",
        "audio/ogg": ".ogg",
        "audio/webm": ".webm",
    }
    suffix = allowed_types.get(audio.content_type or "")
    if suffix is None:
        raise HTTPException(status_code=415, detail="Unsupported audio format")
    data = await audio.read(settings.max_audio_upload_bytes + 1)
    if len(data) > settings.max_audio_upload_bytes:
        raise HTTPException(status_code=413, detail="Audio exceeds the 25 MB limit")
    text, language = transcribe_audio(data, suffix)
    return TranscriptionResponse(text=text, language=language)


@app.post("/auth/users", response_model=UserResponse, status_code=201)
def create_user(payload: UserCreate, db: Session = Depends(get_db)) -> User:
    user = User(**payload.model_dump())
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


@app.post("/patients", response_model=PatientResponse, status_code=201)
def create_patient(
    payload: PatientCreate,
    db: Session = Depends(get_db),
    _: Actor = Depends(require_roles(Role.DOCTOR, Role.HOSPITAL_ADMIN)),
) -> Patient:
    get_existing_user(db, payload.user_id)
    patient = Patient(**payload.model_dump())
    db.add(patient)
    db.commit()
    db.refresh(patient)
    return patient


@app.get("/patients/{patient_id}", response_model=PatientResponse)
def get_patient(
    patient_id: str,
    db: Session = Depends(get_db),
    actor: Actor = Depends(get_actor),
) -> Patient:
    patient = db.get(Patient, patient_id)
    if patient is None:
        raise HTTPException(status_code=404, detail="Patient not found")
    require_user(actor, patient.user_id)
    return patient


@app.post("/patients/{patient_id}/condition", response_model=CarePlanResponse)
def save_condition(
    patient_id: str,
    request: ConditionRequest,
    db: Session = Depends(get_db),
    actor: Actor = Depends(get_actor),
) -> CarePlan:
    patient = db.get(Patient, patient_id)
    if patient is None:
        raise HTTPException(status_code=404, detail="Patient not found")
    require_user(actor, patient.user_id)
    plan = db.scalar(
        select(CarePlan)
        .where(
            CarePlan.patient_id == patient_id,
            CarePlan.status == CarePlanStatus.DRAFT.value,
        )
        .order_by(CarePlan.version.desc())
    )
    if plan is None:
        plan = CarePlan(
            patient_id=patient_id,
            version=next_plan_version(db, patient_id),
        )
        db.add(plan)
    plan.condition = request.description
    db.commit()
    db.refresh(plan)
    return plan


@app.post("/prescriptions/upload", response_model=CarePlanResponse, status_code=201)
async def upload_prescription(
    patient_id: str,
    document: UploadFile = File(...),
    db: Session = Depends(get_db),
    actor: Actor = Depends(get_actor),
) -> CarePlan:
    patient = db.get(Patient, patient_id)
    if patient is None:
        raise HTTPException(status_code=404, detail="Patient not found")
    require_user(actor, patient.user_id)
    storage_path, extracted_text = await store_upload(patient_id, document)
    record = PrescriptionDocument(
        patient_id=patient_id,
        filename=document.filename or "upload",
        content_type=document.content_type or "application/octet-stream",
        storage_path=storage_path,
        extraction_status="COMPLETED" if extracted_text else "PENDING_OCR",
        extracted_text=extracted_text or None,
    )
    db.add(record)
    db.flush()
    plan = CarePlan(
        patient_id=patient_id,
        version=next_plan_version(db, patient_id),
        status=CarePlanStatus.DRAFT.value,
        source_document_id=record.id,
    )
    db.add(plan)
    db.commit()
    db.refresh(plan)
    return plan


@app.post("/patients/{patient_id}/condition-image", response_model=UploadResponse)
async def upload_condition_image(
    patient_id: str,
    image: UploadFile = File(...),
    db: Session = Depends(get_db),
    actor: Actor = Depends(get_actor),
) -> UploadResponse:
    patient = db.get(Patient, patient_id)
    if patient is None:
        raise HTTPException(status_code=404, detail="Patient not found")
    require_user(actor, patient.user_id)
    if image.content_type not in {"image/jpeg", "image/png"}:
        raise HTTPException(status_code=415, detail="Only JPG and PNG images are supported")
    data = await image.read(settings.max_upload_bytes + 1)
    if len(data) > settings.max_upload_bytes:
        raise HTTPException(status_code=413, detail="Image exceeds the 10 MB limit")
    if not settings.cloudinary_url:
        raise HTTPException(status_code=503, detail="Cloudinary storage is not configured")
    secure_url, public_id = await upload_to_cloudinary(
        patient_id,
        image.filename or "condition-image",
        image.content_type,
        data,
    )
    return UploadResponse(
        secure_url=secure_url,
        public_id=public_id,
        filename=image.filename or "condition-image",
    )


@app.post(
    "/patients/{patient_id}/care-plans/submit",
    response_model=CarePlanDetail,
    status_code=201,
)
async def submit_care_plan(
    patient_id: str,
    condition: str = Form(..., min_length=1, max_length=2000),
    prescription: UploadFile = File(...),
    db: Session = Depends(get_db),
    actor: Actor = Depends(get_actor),
) -> CarePlanDetail:
    patient = db.get(Patient, patient_id)
    if patient is None:
        patient = db.scalar(select(Patient).where(Patient.user_id == patient_id))
    if patient is None:
        raise HTTPException(status_code=404, detail="Patient not found")
    require_user(actor, patient.user_id)
    patient_id = patient.id
    if prescription.content_type not in {"image/jpeg", "image/png", "application/pdf"}:
        raise HTTPException(status_code=415, detail="Prescription must be JPG, PNG, or PDF")
    data = await prescription.read(settings.max_upload_bytes + 1)
    if len(data) > settings.max_upload_bytes:
        raise HTTPException(status_code=413, detail="Prescription exceeds the 10 MB limit")
    if not settings.cloudinary_url:
        raise HTTPException(status_code=503, detail="Cloudinary storage is not configured")
    storage_path, public_id = await upload_to_cloudinary(
        patient_id,
        prescription.filename or "prescription",
        prescription.content_type,
        data,
    )
    record = PrescriptionDocument(
        patient_id=patient_id,
        filename=prescription.filename or "prescription",
        content_type=prescription.content_type,
        storage_path=storage_path,
        extraction_status="PENDING_REVIEW",
    )
    db.add(record)
    db.flush()
    medicines = await generate_care_plan_with_gemini(
        condition,
        data,
        prescription.content_type,
    )
    plan = CarePlan(
        patient_id=patient_id,
        version=next_plan_version(db, patient_id),
        status=CarePlanStatus.PENDING_REVIEW.value,
        source_document_id=record.id,
        condition=condition,
    )
    db.add(plan)
    db.flush()
    validated = []
    try:
        for item in medicines:
            normalized = dict(item)
            normalized.setdefault("start_date", date.today().isoformat())
            normalized.setdefault("food_instruction", None)
            normalized.setdefault("end_date", None)
            normalized.setdefault("quantity", None)
            validated.append(MedicineCreate.model_validate(normalized))
    except (TypeError, ValueError) as error:
        raise HTTPException(status_code=502, detail="Gemini returned invalid medicine data") from error
    add_medicines(db, plan, validated)
    db.add(
        AuditLog(
            actor_id=actor.id,
            action="SUBMIT_FOR_REVIEW",
            entity_type="CARE_PLAN",
            entity_id=plan.id,
        )
    )
    db.commit()
    return care_plan_detail(db, plan)


@app.post("/care-plans/{plan_id}/draft", response_model=CarePlanDetail)
def save_draft(
    plan_id: str,
    payload: CarePlanDraftRequest,
    db: Session = Depends(get_db),
    actor: Actor = Depends(get_actor),
) -> CarePlanDetail:
    plan = db.get(CarePlan, plan_id)
    if plan is None:
        raise HTTPException(status_code=404, detail="Care plan not found")
    if plan.status != CarePlanStatus.DRAFT.value:
        raise HTTPException(status_code=409, detail="Only draft plans can be edited")
    patient = db.get(Patient, plan.patient_id)
    require_user(actor, patient.user_id)
    plan.follow_up_date = payload.follow_up_date
    add_medicines(db, plan, payload.medicines)
    db.commit()
    return care_plan_detail(db, plan)


@app.get("/care-plans/{plan_id}", response_model=CarePlanDetail)
def get_care_plan(
    plan_id: str,
    db: Session = Depends(get_db),
    actor: Actor = Depends(get_actor),
) -> CarePlanDetail:
    plan = db.get(CarePlan, plan_id)
    if plan is None:
        raise HTTPException(status_code=404, detail="Care plan not found")
    patient = db.get(Patient, plan.patient_id)
    require_user(actor, patient.user_id)
    return care_plan_detail(db, plan)


@app.patch("/care-plans/{plan_id}/approve", response_model=CarePlanResponse)
def approve_care_plan(
    plan_id: str,
    db: Session = Depends(get_db),
    actor: Actor = Depends(require_roles(Role.DOCTOR, Role.HOSPITAL_ADMIN)),
) -> CarePlan:
    plan = db.get(CarePlan, plan_id)
    if plan is None:
        raise HTTPException(status_code=404, detail="Care plan not found")
    if plan.status not in {
        CarePlanStatus.DRAFT.value,
        CarePlanStatus.PENDING_REVIEW.value,
    }:
        raise HTTPException(
            status_code=409,
            detail="Care plan is not awaiting approval",
        )
    previous = active_plan(db, plan.patient_id)
    if previous is not None:
        previous.status = CarePlanStatus.SUPERSEDED.value
    plan.status = CarePlanStatus.ACTIVE.value
    plan.doctor_id = actor.id
    plan.approved_at = datetime.utcnow()
    db.add(
        AuditLog(
            actor_id=actor.id,
            action="APPROVE",
            entity_type="CARE_PLAN",
            entity_id=plan.id,
        )
    )
    db.commit()
    db.refresh(plan)
    return plan


@app.post(
    "/patients/{patient_id}/care-plans/new-version",
    response_model=CarePlanResponse,
    status_code=201,
)
def new_care_plan_version(
    patient_id: str,
    db: Session = Depends(get_db),
    _: Actor = Depends(require_roles(Role.DOCTOR, Role.HOSPITAL_ADMIN)),
) -> CarePlan:
    if db.get(Patient, patient_id) is None:
        raise HTTPException(status_code=404, detail="Patient not found")
    plan = CarePlan(
        patient_id=patient_id,
        version=next_plan_version(db, patient_id),
    )
    db.add(plan)
    db.commit()
    db.refresh(plan)
    return plan


@app.get(
    "/patients/{patient_id}/care-plans",
    response_model=list[CarePlanDetail],
)
def care_plan_history(
    patient_id: str,
    db: Session = Depends(get_db),
    actor: Actor = Depends(get_actor),
) -> list[CarePlan]:
    patient = db.get(Patient, patient_id)
    if patient is None:
        patient = db.scalar(select(Patient).where(Patient.user_id == patient_id))
    if patient is None:
        raise HTTPException(status_code=404, detail="Patient not found")
    require_user(actor, patient.user_id)
    plans = list(
        db.scalars(
            select(CarePlan)
            .where(CarePlan.patient_id == patient.id)
            .order_by(CarePlan.version.desc())
        ).all()
    )
    return [care_plan_detail(db, plan) for plan in plans]


@app.get("/doctor/patients", response_model=list[PatientResponse])
def doctor_patients(
    db: Session = Depends(get_db),
    _: Actor = Depends(require_roles(Role.DOCTOR, Role.HOSPITAL_ADMIN)),
) -> list[Patient]:
    return list(db.scalars(select(Patient).order_by(Patient.id)).all())


@app.get("/doctor/care-plans", response_model=list[CarePlanDetail])
def doctor_care_plans(
    status: str = CarePlanStatus.PENDING_REVIEW.value,
    db: Session = Depends(get_db),
    _: Actor = Depends(require_roles(Role.DOCTOR, Role.HOSPITAL_ADMIN)),
) -> list[CarePlanDetail]:
    plans = db.scalars(
        select(CarePlan)
        .where(CarePlan.status == status)
        .order_by(CarePlan.created_at.desc())
    ).all()
    return [care_plan_detail(db, plan) for plan in plans]


@app.get("/patients/{patient_id}/today", response_model=list[MedicationEventResponse])
def get_today(
    patient_id: str,
    db: Session = Depends(get_db),
    actor: Actor = Depends(get_actor),
) -> list[MedicationEventResponse]:
    patient = db.get(Patient, patient_id)
    if patient is None:
        raise HTTPException(status_code=404, detail="Patient not found")
    require_user(actor, patient.user_id)
    plan = active_plan(db, patient_id)
    if plan is None:
        return []
    create_daily_events(db, patient_id, plan, date.today())
    db.commit()
    return medication_events(db, patient_id, date.today())


@app.post(
    "/medications/{event_id}/status",
    response_model=MedicationEventResponse,
)
def record_medication(
    event_id: str,
    payload: MedicationStatusRequest,
    db: Session = Depends(get_db),
    actor: Actor = Depends(get_actor),
) -> MedicationEventResponse:
    event = db.get(MedicationEvent, event_id)
    if event is None:
        raise HTTPException(status_code=404, detail="Medication event not found")
    patient = db.get(Patient, event.patient_id)
    require_user(actor, patient.user_id)
    event.status = payload.status
    event.confirmed_at = datetime.utcnow()
    if payload.status == "MISSED":
        db.add(
            Alert(
                patient_id=event.patient_id,
                type="MISSED_DOSE",
                severity="MEDIUM",
                message="A scheduled medicine was marked as missed.",
            )
        )
        create_hospital_alert_if_needed(db, event.patient_id, event)
    db.commit()
    return medication_event_response(db, event)


@app.get(
    "/patients/{patient_id}/adherence",
    response_model=AdherenceResponse,
)
def adherence(
    patient_id: str,
    start: date | None = None,
    end: date | None = None,
    db: Session = Depends(get_db),
    actor: Actor = Depends(get_actor),
) -> AdherenceResponse:
    patient = db.get(Patient, patient_id)
    if patient is None:
        raise HTTPException(status_code=404, detail="Patient not found")
    require_user(actor, patient.user_id)
    end = end or date.today()
    start = start or end - timedelta(days=6)
    events = db.scalars(
        select(MedicationEvent).where(
            MedicationEvent.patient_id == patient_id,
            MedicationEvent.scheduled_for >= datetime.combine(start, time.min),
            MedicationEvent.scheduled_for <= datetime.combine(end, time.max),
        )
    ).all()
    taken = sum(event.status == "TAKEN" for event in events)
    scheduled = len(events)
    return AdherenceResponse(
        start_date=start,
        end_date=end,
        scheduled_doses=scheduled,
        taken_doses=taken,
        missed_doses=sum(event.status == "MISSED" for event in events),
        percentage=round(taken / scheduled * 100, 2) if scheduled else 0,
    )


@app.get(
    "/patients/{patient_id}/reminders",
    response_model=list[MedicationEventResponse],
)
def patient_reminders(
    patient_id: str,
    on_date: date | None = None,
    db: Session = Depends(get_db),
    actor: Actor = Depends(get_actor),
) -> list[MedicationEventResponse]:
    patient = db.get(Patient, patient_id)
    if patient is None:
        raise HTTPException(status_code=404, detail="Patient not found")
    require_user(actor, patient.user_id)
    target_date = on_date or date.today()
    plan = active_plan(db, patient_id)
    if plan is None:
        return []
    create_daily_events(db, patient_id, plan, target_date)
    db.commit()
    now = datetime.now()
    events = db.scalars(
        select(MedicationEvent)
        .where(
            MedicationEvent.patient_id == patient_id,
            MedicationEvent.scheduled_for >= datetime.combine(
                target_date,
                time.min,
            ),
            MedicationEvent.scheduled_for <= datetime.combine(
                target_date,
                time.max,
            ),
            MedicationEvent.status == "PENDING",
            MedicationEvent.scheduled_for <= now,
        )
        .order_by(MedicationEvent.scheduled_for)
    ).all()
    return [medication_event_response(db, event) for event in events]


@app.post("/reminders/run", response_model=dict[str, int])
def run_reminder_engine(
    on_date: date | None = None,
    db: Session = Depends(get_db),
    _: Actor = Depends(require_roles(Role.DOCTOR, Role.HOSPITAL_ADMIN)),
) -> dict[str, int]:
    target_date = on_date or date.today()
    now = datetime.now()
    overdue = db.scalars(
        select(MedicationEvent).where(
            MedicationEvent.scheduled_for >= datetime.combine(
                target_date,
                time.min,
            ),
            MedicationEvent.scheduled_for
            <= now - timedelta(minutes=settings.reminder_grace_minutes),
            MedicationEvent.status == "PENDING",
        )
    ).all()
    for event in overdue:
        event.status = "MISSED"
        event.confirmed_at = now
        db.add(
            Alert(
                patient_id=event.patient_id,
                type="NOMINEE_ESCALATION",
                severity="MEDIUM",
                message=(
                    "A scheduled medicine remains unconfirmed after "
                    "the grace period."
                ),
            )
        )
        create_hospital_alert_if_needed(db, event.patient_id, event)
    db.commit()
    return {"processed": len(overdue)}


@app.get("/doctor/alerts", response_model=list[AlertResponse])
def doctor_alerts(
    status: AlertStatus | None = None,
    db: Session = Depends(get_db),
    _: Actor = Depends(require_roles(Role.DOCTOR, Role.HOSPITAL_ADMIN)),
) -> list[Alert]:
    query = select(Alert).order_by(Alert.created_at.desc())
    if status:
        query = query.where(Alert.status == status.value)
    return list(db.scalars(query).all())


@app.patch("/alerts/{alert_id}/resolve", response_model=AlertResponse)
def resolve_alert(
    alert_id: str,
    db: Session = Depends(get_db),
    actor: Actor = Depends(require_roles(Role.DOCTOR, Role.HOSPITAL_ADMIN)),
) -> Alert:
    alert = db.get(Alert, alert_id)
    if alert is None:
        raise HTTPException(status_code=404, detail="Alert not found")
    alert.status = AlertStatus.RESOLVED.value
    alert.resolved_at = datetime.utcnow()
    db.add(
        AuditLog(
            actor_id=actor.id,
            action="RESOLVE",
            entity_type="ALERT",
            entity_id=alert.id,
        )
    )
    db.commit()
    db.refresh(alert)
    return alert


@app.patch("/alerts/{alert_id}/acknowledge", response_model=AlertResponse)
def acknowledge_alert(
    alert_id: str,
    db: Session = Depends(get_db),
    actor: Actor = Depends(require_roles(Role.DOCTOR, Role.HOSPITAL_ADMIN)),
) -> Alert:
    alert = db.get(Alert, alert_id)
    if alert is None:
        raise HTTPException(status_code=404, detail="Alert not found")
    alert.status = AlertStatus.ACKNOWLEDGED.value
    db.add(
        AuditLog(
            actor_id=actor.id,
            action="ACKNOWLEDGE",
            entity_type="ALERT",
            entity_id=alert.id,
        )
    )
    db.commit()
    db.refresh(alert)
    return alert


@app.post(
    "/patients/{patient_id}/follow-ups",
    response_model=FollowUpResponse,
    status_code=201,
)
def create_follow_up(
    patient_id: str,
    payload: FollowUpCreate,
    db: Session = Depends(get_db),
    actor: Actor = Depends(require_roles(Role.DOCTOR, Role.HOSPITAL_ADMIN)),
) -> FollowUp:
    plan = active_plan(db, patient_id)
    if plan is None:
        raise HTTPException(
            status_code=409,
            detail="Patient has no active care plan",
        )
    follow_up = FollowUp(
        patient_id=patient_id,
        care_plan_id=plan.id,
        scheduled_date=payload.scheduled_date,
        notes=payload.notes,
        doctor_id=actor.id,
    )
    db.add(follow_up)
    db.commit()
    db.refresh(follow_up)
    return follow_up


@app.get(
    "/patients/{patient_id}/follow-ups",
    response_model=list[FollowUpResponse],
)
def list_follow_ups(
    patient_id: str,
    db: Session = Depends(get_db),
    actor: Actor = Depends(get_actor),
) -> list[FollowUp]:
    patient = db.get(Patient, patient_id)
    if patient is None:
        raise HTTPException(status_code=404, detail="Patient not found")
    require_user(actor, patient.user_id)
    return list(
        db.scalars(
            select(FollowUp)
            .where(FollowUp.patient_id == patient_id)
            .order_by(FollowUp.scheduled_date)
        ).all()
    )


@app.patch("/follow-ups/{follow_up_id}", response_model=FollowUpResponse)
def update_follow_up(
    follow_up_id: str,
    status: str,
    notes: str | None = None,
    db: Session = Depends(get_db),
    _: Actor = Depends(require_roles(Role.DOCTOR, Role.HOSPITAL_ADMIN)),
) -> FollowUp:
    if status not in {"SCHEDULED", "COMPLETED", "CANCELLED"}:
        raise HTTPException(status_code=422, detail="Invalid follow-up status")
    follow_up = db.get(FollowUp, follow_up_id)
    if follow_up is None:
        raise HTTPException(status_code=404, detail="Follow-up not found")
    follow_up.status = status
    if notes is not None:
        follow_up.notes = notes
    db.commit()
    db.refresh(follow_up)
    return follow_up


@app.post("/patients/{patient_id}/voice", response_model=VoiceResponse)
def voice_answer(
    patient_id: str,
    request: VoiceRequest,
    db: Session = Depends(get_db),
    actor: Actor = Depends(get_actor),
) -> VoiceResponse:
    patient = db.get(Patient, patient_id)
    if patient is None:
        raise HTTPException(status_code=404, detail="Patient not found")
    require_user(actor, patient.user_id)
    question = request.question.lower()
    if any(
        word in question
        for word in ("change", "stop", "increase", "decrease", "new medicine")
    ):
        return VoiceResponse(
            answer="Please contact your doctor for changes to medicines or treatment.",
            requires_clinician=True,
        )
    return VoiceResponse(
        answer=(
            "I can explain your approved care plan, but I cannot provide "
            "new medical advice."
        ),
        requires_clinician=False,
    )


@app.post(
    "/patients/{patient_id}/companion/check-ins",
    response_model=CompanionCheckInResponse,
    status_code=201,
)
def create_companion_check_in(
    patient_id: str,
    payload: CompanionCheckInRequest,
    db: Session = Depends(get_db),
    actor: Actor = Depends(get_actor),
) -> CompanionCheckIn:
    patient = db.get(Patient, patient_id)
    if patient is None:
        raise HTTPException(status_code=404, detail="Patient not found")
    require_user(actor, patient.user_id)
    check_in = CompanionCheckIn(patient_id=patient_id, **payload.model_dump())
    db.add(check_in)
    db.commit()
    db.refresh(check_in)
    return check_in


@app.get(
    "/patients/{patient_id}/companion/check-ins",
    response_model=list[CompanionCheckInResponse],
)
def list_companion_check_ins(
    patient_id: str,
    db: Session = Depends(get_db),
    actor: Actor = Depends(get_actor),
) -> list[CompanionCheckIn]:
    patient = db.get(Patient, patient_id)
    if patient is None:
        raise HTTPException(status_code=404, detail="Patient not found")
    require_user(actor, patient.user_id)
    return list(
        db.scalars(
            select(CompanionCheckIn)
            .where(CompanionCheckIn.patient_id == patient_id)
            .order_by(CompanionCheckIn.created_at.desc())
            .limit(50)
        ).all()
    )


@app.post(
    "/patients/{patient_id}/companion/conversations",
    response_model=CompanionConversationResponse,
    status_code=201,
)
async def create_companion_conversation(
    patient_id: str,
    payload: CompanionConversationRequest,
    db: Session = Depends(get_db),
    actor: Actor = Depends(get_actor),
) -> CompanionConversationResponse:
    patient = db.get(Patient, patient_id)
    if patient is None:
        raise HTTPException(status_code=404, detail="Patient not found")
    require_user(actor, patient.user_id)
    question = payload.question.strip()
    emergency_terms = ("chest pain", "trouble breathing", "cannot breathe", "unconscious")
    requires_clinician = any(term in question.lower() for term in emergency_terms)
    if requires_clinician:
        answer = (
            "This may need urgent medical attention. Contact local emergency "
            "services or go to the nearest emergency department now."
        )
    else:
        answer = (
            "I can explain information in your approved care plan, but I cannot "
            "diagnose you or change medicines. Please contact your doctor for "
            "new symptoms or treatment changes."
        )
        if settings.gemini_api_key:
            try:
                generated = await generate_companion_answer(
                    question=question,
                    language=payload.language,
                    patient_id=patient_id,
                    db=db,
                )
                if generated.strip():
                    answer = generated.strip()
            except HTTPException:
                pass
    conversation = CompanionConversation(
        patient_id=patient_id,
        language=payload.language,
        question=question,
        answer=answer,
    )
    db.add(conversation)
    db.commit()
    db.refresh(conversation)
    return CompanionConversationResponse(
        id=conversation.id,
        question=conversation.question,
        answer=conversation.answer,
        language=conversation.language,
        created_at=conversation.created_at,
        requires_clinician=requires_clinician,
    )


@app.post(
    "/patients/{patient_id}/companion/summaries",
    response_model=HealthSummaryResponse,
    status_code=201,
)
def create_health_summary(
    patient_id: str,
    db: Session = Depends(get_db),
    actor: Actor = Depends(get_actor),
) -> HealthSummaryResponse:
    patient = db.get(Patient, patient_id)
    if patient is None:
        raise HTTPException(status_code=404, detail="Patient not found")
    require_user(actor, patient.user_id)
    check_ins = list(
        db.scalars(
            select(CompanionCheckIn)
            .where(CompanionCheckIn.patient_id == patient_id)
            .order_by(CompanionCheckIn.created_at.desc())
            .limit(20)
        ).all()
    )
    if not check_ins:
        raise HTTPException(status_code=422, detail="Record a check-in first")
    lines = ["AI-generated patient-reported summary:", ""]
    for item in reversed(check_ins):
        details = f" ({item.details})" if item.details else ""
        lines.append(f"- {item.category}: {item.response}{details} [{item.created_at.isoformat()}]")
    summary = HealthSummary(patient_id=patient_id, summary="\n".join(lines))
    db.add(summary)
    db.commit()
    db.refresh(summary)
    return HealthSummaryResponse.model_validate(summary)


@app.post(
    "/patients/{patient_id}/companion/summaries/{summary_id}/submit",
    response_model=HealthSummarySubmitResponse,
)
def submit_health_summary(
    patient_id: str,
    summary_id: str,
    db: Session = Depends(get_db),
    actor: Actor = Depends(get_actor),
) -> HealthSummary:
    patient = db.get(Patient, patient_id)
    summary = db.get(HealthSummary, summary_id)
    if patient is None or summary is None or summary.patient_id != patient_id:
        raise HTTPException(status_code=404, detail="Health summary not found")
    require_user(actor, patient.user_id)
    summary.status = "SUBMITTED"
    summary.submitted_at = datetime.utcnow()
    db.commit()
    db.refresh(summary)
    return summary


@app.get(
    "/doctor/companion/requests",
    response_model=list[DoctorRequestResponse],
)
def doctor_companion_requests(
    db: Session = Depends(get_db),
    _: Actor = Depends(require_roles(Role.DOCTOR, Role.HOSPITAL_ADMIN)),
) -> list[DoctorRequest]:
    return list(
        db.scalars(
            select(DoctorRequest).order_by(DoctorRequest.created_at.desc())
        ).all()
    )


@app.get(
    "/doctor/companion/summaries",
    response_model=list[HealthSummaryResponse],
)
def doctor_companion_summaries(
    db: Session = Depends(get_db),
    _: Actor = Depends(require_roles(Role.DOCTOR, Role.HOSPITAL_ADMIN)),
) -> list[HealthSummary]:
    return list(
        db.scalars(
            select(HealthSummary)
            .where(HealthSummary.status == "SUBMITTED")
            .order_by(HealthSummary.submitted_at.desc())
        ).all()
    )


@app.post(
    "/patients/{patient_id}/companion/doctor-requests",
    response_model=DoctorRequestResponse,
    status_code=201,
)
def create_doctor_request(
    patient_id: str,
    payload: DoctorRequestCreate,
    db: Session = Depends(get_db),
    actor: Actor = Depends(get_actor),
) -> DoctorRequest:
    patient = db.get(Patient, patient_id)
    if patient is None:
        raise HTTPException(status_code=404, detail="Patient not found")
    require_user(actor, patient.user_id)
    request = DoctorRequest(patient_id=patient_id, **payload.model_dump())
    db.add(request)
    db.commit()
    db.refresh(request)
    return request


@app.post(
    "/patients/{patient_id}/refills",
    response_model=RefillResponse,
    status_code=201,
)
def request_refill(
    patient_id: str,
    payload: RefillRequest,
    db: Session = Depends(get_db),
    actor: Actor = Depends(get_actor),
) -> RefillResponse:
    patient = db.get(Patient, patient_id)
    if patient is None:
        raise HTTPException(status_code=404, detail="Patient not found")
    require_user(actor, patient.user_id)
    if db.get(Medicine, payload.medicine_id) is None:
        raise HTTPException(status_code=404, detail="Medicine not found")
    return RefillResponse(
        id=f"refill-{datetime.utcnow().timestamp()}",
        patient_id=patient_id,
        medicine_id=payload.medicine_id,
        quantity=payload.quantity,
        created_at=datetime.utcnow(),
    )


def care_plan_detail(db: Session, plan: CarePlan) -> CarePlanDetail:
    medicines = db.scalars(
        select(Medicine).where(Medicine.care_plan_id == plan.id)
    ).all()
    result = []
    for medicine in medicines:
        schedules = db.scalars(
            select(MedicationSchedule).where(
                MedicationSchedule.medicine_id == medicine.id
            )
        ).all()
        result.append(
            {
                "id": medicine.id,
                "name": medicine.name,
                "dose": medicine.dose,
                "frequency": medicine.frequency,
                "food_instruction": medicine.food_instruction,
                "start_date": medicine.start_date,
                "end_date": medicine.end_date,
                "quantity": medicine.quantity,
                "scheduled_times": [
                    schedule.scheduled_time for schedule in schedules
                ],
            }
        )
    return CarePlanDetail.model_validate(
        {
            **CarePlanResponse.model_validate(plan).model_dump(),
            "medicines": result,
        }
    )


def medication_events(
    db: Session,
    patient_id: str,
    on_date: date,
) -> list[MedicationEventResponse]:
    events = db.scalars(
        select(MedicationEvent)
        .where(
            MedicationEvent.patient_id == patient_id,
            MedicationEvent.scheduled_for >= datetime.combine(on_date, time.min),
            MedicationEvent.scheduled_for <= datetime.combine(on_date, time.max),
        )
        .order_by(MedicationEvent.scheduled_for)
    ).all()
    return [medication_event_response(db, event) for event in events]


def medication_event_response(
    db: Session,
    event: MedicationEvent,
) -> MedicationEventResponse:
    schedule = db.get(MedicationSchedule, event.schedule_id)
    medicine = db.get(Medicine, schedule.medicine_id)
    return MedicationEventResponse(
        id=event.id,
        medicine_id=medicine.id,
        medicine_name=medicine.name,
        scheduled_for=event.scheduled_for,
        status=event.status,
        confirmed_at=event.confirmed_at,
    )
