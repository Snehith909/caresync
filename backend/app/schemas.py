from datetime import date, datetime, time
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field


class HealthResponse(BaseModel):
    status: Literal["ok"]
    service: str


class UserCreate(BaseModel):
    name: str = Field(min_length=1, max_length=200)
    email: str | None = None
    phone: str | None = None
    role: Literal["PATIENT", "NOMINEE", "DOCTOR", "HOSPITAL_ADMIN"] = "PATIENT"
    language: str = "en"


class UserResponse(UserCreate):
    id: str
    model_config = ConfigDict(from_attributes=True)


class PatientCreate(BaseModel):
    user_id: str
    nominee_id: str | None = None
    hospital_id: str | None = None


class PatientResponse(PatientCreate):
    id: str
    model_config = ConfigDict(from_attributes=True)


class ConditionRequest(BaseModel):
    description: str = Field(min_length=1, max_length=2000)


class UploadResponse(BaseModel):
    secure_url: str
    public_id: str
    filename: str


class TranscriptionResponse(BaseModel):
    text: str
    language: str | None = None


class CarePlanResponse(BaseModel):
    id: str
    patient_id: str
    version: int
    status: str
    source_document_id: str | None = None
    doctor_id: str | None = None
    condition: str | None = None
    follow_up_date: date | None = None
    created_at: datetime
    approved_at: datetime | None = None
    model_config = ConfigDict(from_attributes=True)


class MedicineCreate(BaseModel):
    name: str = Field(min_length=1, max_length=200)
    dose: str = Field(min_length=1, max_length=100)
    frequency: str = Field(min_length=1, max_length=100)
    scheduled_times: list[time] = Field(min_length=1)
    food_instruction: str | None = None
    start_date: date
    end_date: date | None = None
    quantity: int | None = Field(default=None, ge=1)


class CarePlanDraftRequest(BaseModel):
    medicines: list[MedicineCreate] = Field(default_factory=list)
    follow_up_date: date | None = None


class MedicineResponse(BaseModel):
    id: str
    name: str
    dose: str
    frequency: str
    food_instruction: str | None
    start_date: date
    end_date: date | None
    quantity: int | None
    scheduled_times: list[time]


class CarePlanDetail(CarePlanResponse):
    medicines: list[MedicineResponse]


class MedicationEventResponse(BaseModel):
    id: str
    medicine_id: str
    medicine_name: str
    scheduled_for: datetime
    status: str
    confirmed_at: datetime | None


class MedicationStatusRequest(BaseModel):
    status: Literal["TAKEN", "MISSED"]


class AdherenceResponse(BaseModel):
    start_date: date
    end_date: date
    scheduled_doses: int
    taken_doses: int
    missed_doses: int
    percentage: float


class AlertResponse(BaseModel):
    id: str
    patient_id: str
    type: str
    severity: str
    status: str
    message: str
    created_at: datetime
    resolved_at: datetime | None
    model_config = ConfigDict(from_attributes=True)


class FollowUpCreate(BaseModel):
    scheduled_date: date
    notes: str | None = None


class FollowUpResponse(FollowUpCreate):
    id: str
    patient_id: str
    care_plan_id: str
    status: str
    doctor_id: str | None
    model_config = ConfigDict(from_attributes=True)


class VoiceRequest(BaseModel):
    question: str = Field(min_length=1, max_length=1000)


class VoiceResponse(BaseModel):
    answer: str
    requires_clinician: bool


class RefillRequest(BaseModel):
    medicine_id: str
    quantity: int = Field(ge=1)


class RefillResponse(RefillRequest):
    id: str
    patient_id: str
    status: Literal["REQUESTED"] = "REQUESTED"
    created_at: datetime
