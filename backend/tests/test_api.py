from datetime import date, time
from io import BytesIO

import pytest
from fastapi.testclient import TestClient

from app.main import app


@pytest.fixture
def client():
    with TestClient(app) as test_client:
        yield test_client


def headers(user_id: str, role: str = "PATIENT") -> dict[str, str]:
    return {"X-User-Id": user_id, "X-User-Role": role}


def test_core_care_plan_and_adherence_flow(client: TestClient) -> None:
    patient_user = client.post(
        "/auth/users",
        json={"name": "Test Patient", "role": "PATIENT"},
    ).json()
    doctor_user = client.post(
        "/auth/users",
        json={"name": "Test Doctor", "role": "DOCTOR"},
    ).json()
    patient = client.post(
        "/patients",
        headers=headers(doctor_user["id"], "DOCTOR"),
        json={"user_id": patient_user["id"]},
    )
    assert patient.status_code == 201
    patient_id = patient.json()["id"]

    upload = client.post(
        f"/prescriptions/upload?patient_id={patient_id}",
        headers=headers(patient_user["id"]),
        files={"document": ("prescription.png", BytesIO(b"image"), "image/png")},
    )
    assert upload.status_code == 201
    plan_id = upload.json()["id"]

    draft = client.post(
        f"/care-plans/{plan_id}/draft",
        headers=headers(patient_user["id"]),
        json={
            "medicines": [
                {
                    "name": "Approved medicine",
                    "dose": "500 mg",
                    "frequency": "once daily",
                    "scheduled_times": [time(8, 0).isoformat()],
                    "start_date": date.today().isoformat(),
                }
            ]
        },
    )
    assert draft.status_code == 200
    assert len(draft.json()["medicines"]) == 1

    approved = client.patch(
        f"/care-plans/{plan_id}/approve",
        headers=headers(doctor_user["id"], "DOCTOR"),
    )
    assert approved.status_code == 200
    assert approved.json()["status"] == "ACTIVE"

    today = client.get(
        f"/patients/{patient_id}/today",
        headers=headers(patient_user["id"]),
    )
    assert today.status_code == 200
    event_id = today.json()[0]["id"]

    taken = client.post(
        f"/medications/{event_id}/status",
        headers=headers(patient_user["id"]),
        json={"status": "TAKEN"},
    )
    assert taken.status_code == 200
    assert taken.json()["confirmed_at"] is not None

    weekly = client.get(
        f"/patients/{patient_id}/adherence",
        headers=headers(patient_user["id"]),
    )
    assert weekly.status_code == 200
    assert weekly.json()["taken_doses"] == 1
    assert weekly.json()["percentage"] == 100


def test_role_protection_and_voice_safety(client: TestClient) -> None:
    response = client.get("/doctor/alerts", headers=headers("patient", "PATIENT"))
    assert response.status_code == 403
