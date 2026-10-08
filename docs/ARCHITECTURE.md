# ARCHITECTURE --- AI-Assisted Post-Discharge Care System

## 1. Architecture Overview

The system uses two frontends and one shared backend:

``` text
                    ┌──────────────────────┐
                    │   Flutter Patient    │
                    │        App           │
                    └──────────┬───────────┘
                               │
                               │ REST / HTTPS
                               │
                    ┌──────────▼───────────┐
                    │      FastAPI         │
                    │      Backend         │
                    └──────────┬───────────┘
                               │
          ┌────────────────────┼─────────────────────┐
          │                    │                     │
          ▼                    ▼                     ▼
   PostgreSQL DB        AI/OCR Services       Notification
          │                    │                 Engine
          │                    │                     │
          │                    │                     ▼
          │                    │             Patient/Nominee
          │                    │
          │                    ▼
          │              Care Plan JSON
          │
          ▼
   Care Plans / Doses /
   Adherence / Alerts
          ▲
          │
   ┌──────┴──────────────┐
   │ React Doctor Portal │
   └─────────────────────┘
```

------------------------------------------------------------------------

## 2. Frontend Architecture

### Patient Application

Technology:

-   Flutter
-   Dart
-   Firebase Authentication
-   Firebase Cloud Messaging

Responsibilities:

-   Authentication
-   Prescription upload
-   Current-condition input
-   Daily dashboard
-   Medication confirmation
-   Voice interaction
-   Notifications
-   Weekly progress
-   Follow-up
-   Re-upload after reassessment

### Doctor Portal

Technology:

-   React
-   Tailwind CSS

Responsibilities:

-   Hospital authentication
-   Patient list
-   Care-plan review
-   AI draft approval
-   Medication/adherence monitoring
-   Escalation alerts
-   Patient follow-up
-   Care-plan version management
-   Doctor notes

------------------------------------------------------------------------

## 3. Backend Architecture

Technology:

-   Python
-   FastAPI
-   Pydantic
-   SQLAlchemy
-   PostgreSQL

Suggested API groups:

``` text
/auth
/patients
/prescriptions
/conditions
/care-plans
/medications
/reminders
/adherence
/alerts
/doctor
/follow-ups
/voice
/refills
```

------------------------------------------------------------------------

## 4. Document Processing Pipeline

``` text
PDF / Image
     ↓
File Validation
     ↓
PDF Text Extraction
     │
     └── If scanned/image → OCR
                 ↓
           Extracted Text
                 ↓
          Text Normalization
                 ↓
             GenAI
                 ↓
       Structured JSON Output
                 ↓
        Pydantic Validation
                 ↓
       Doctor Review Required
```

Recommended tools:

-   PyMuPDF for text-based PDFs
-   PaddleOCR for scanned prescriptions
-   Pydantic for schema validation

------------------------------------------------------------------------

## 5. GenAI Architecture

GenAI should not control medication scheduling.

### GenAI Responsibilities

-   Understand medical terminology.
-   Extract medication instructions.
-   Normalize abbreviations.
-   Convert instructions into patient-friendly language.
-   Translate approved information.
-   Generate controlled explanations.

### Backend Responsibilities

-   Store medication schedules.
-   Calculate due times.
-   Track taken/missed status.
-   Trigger reminders.
-   Calculate adherence.
-   Trigger escalation.
-   Maintain care-plan versions.

``` text
             Prescription
                  ↓
                 AI
                  ↓
        Structured Care Plan
                  ↓
              Backend
                  ↓
       Deterministic Scheduler
                  ↓
              Notifications
```

------------------------------------------------------------------------

## 6. Database Model

### users

``` text
id
name
phone
email
role
language
created_at
```

Roles:

-   PATIENT
-   NOMINEE
-   DOCTOR
-   HOSPITAL_ADMIN

### patients

``` text
id
user_id
nominee_id
hospital_id
```

### care_plans

``` text
id
patient_id
version
status
source_document_id
doctor_id
created_at
approved_at
closed_at
```

Statuses:

-   DRAFT
-   PENDING_REVIEW
-   ACTIVE
-   COMPLETED
-   SUPERSEDED

### medicines

``` text
id
care_plan_id
name
dose
unit
frequency
food_instruction
start_date
end_date
quantity
```

### medication_schedules

``` text
id
medicine_id
scheduled_time
day
status
taken_at
```

### adherence

``` text
id
patient_id
care_plan_id
date
scheduled_doses
taken_doses
missed_doses
percentage
```

### alerts

``` text
id
patient_id
type
severity
status
created_at
resolved_at
```

Types:

-   MISSED_DOSE
-   NOMINEE_ESCALATION
-   HOSPITAL_ESCALATION
-   FOLLOW_UP
-   LOW_MEDICINE

### follow_ups

``` text
id
patient_id
care_plan_id
scheduled_date
status
doctor_id
notes
```

------------------------------------------------------------------------

## 7. Reminder Engine

The reminder engine should be deterministic.

Example:

``` text
Medication due: 11:00

11:00 → patient reminder
11:15 → patient reminder
11:30 → voice reminder
12:00 → patient + nominee escalation
```

Actual timings should be configurable by care-plan/hospital policy.

Pseudo-flow:

``` text
Every scheduled dose:
    create medication event

At scheduled time:
    notify patient

If not confirmed:
    wait grace period

If still not confirmed:
    notify patient again

If escalation threshold reached:
    notify nominee

If repeated non-adherence threshold reached:
    create hospital alert
```

------------------------------------------------------------------------

## 8. Three-Day Escalation

``` text
Day 1 → missed medication
Day 2 → missed medication
Day 3 → missed medication
              ↓
     Hospital escalation
              ↓
       Doctor dashboard
              ↓
       Doctor contacts patient
              ↓
         Reassessment
```

The threshold must be configurable and should not be assumed to be
clinically appropriate for every medication.

------------------------------------------------------------------------

## 9. Care-Plan Versioning

Never overwrite previous clinical plans.

``` text
Patient
  │
  ├── Care Plan V1
  │      └── Completed/Superseded
  │
  ├── Care Plan V2
  │      └── Active
  │
  └── Care Plan V3
```

New cycle:

``` text
Hospital reassessment
       ↓
New prescription
       +
Current condition
       ↓
TAB 1
       ↓
AI extraction
       ↓
Doctor approval
       ↓
New Care Plan Version
       ↓
TAB 2
```

------------------------------------------------------------------------

## 10. Voice Architecture

``` text
Patient Speech
      ↓
Speech-to-Text
      ↓
Intent Detection
      ↓
Approved Care Plan Context
      ↓
LLM / Rule Response
      ↓
Text-to-Speech
      ↓
Patient Audio
```

The voice assistant must not use unapproved medication changes.

------------------------------------------------------------------------

## 11. Notification Architecture

Firebase Cloud Messaging can deliver:

-   Patient reminders
-   Nominee alerts
-   Follow-up reminders
-   Hospital alerts

For scheduled events:

``` text
FastAPI
  ↓
Scheduler
  ↓
Notification Service
  ↓
FCM
  ↓
Android/iOS
```

------------------------------------------------------------------------

## 12. Medicine Refill Architecture

``` text
Prescription quantity
        ↓
Dose consumption
        ↓
Estimated remaining quantity
        ↓
Low-stock threshold
        ↓
Refill notification
        ↓
Request refill
        ↓
Pharmacy integration
```

For the hackathon, pharmacy integration can be mocked.

------------------------------------------------------------------------

## 13. Security

Minimum requirements:

-   HTTPS
-   JWT/session-based authentication
-   Role-based access control
-   Secure file storage
-   Input validation
-   API authorization
-   Audit logging
-   No sensitive medical data in client logs
-   Encryption at rest where supported
-   Doctor approval audit trail

------------------------------------------------------------------------

## 14. Deployment

### Frontend

-   Flutter app → Android APK / Play Store-ready build
-   React doctor portal → Vercel

### Backend

-   FastAPI → Render/Railway/cloud VM

### Database

-   PostgreSQL → managed PostgreSQL

### Storage

-   Firebase Storage or cloud object storage

### Notifications

-   Firebase Cloud Messaging

------------------------------------------------------------------------

## 15. Recommended Repository Structure

``` text
healthcare-care-platform/
│
├── patient_app/
│   └── Flutter project
│
├── doctor_portal/
│   └── React project
│
├── backend/
│   ├── app/
│   │   ├── api/
│   │   ├── models/
│   │   ├── schemas/
│   │   ├── services/
│   │   ├── ai/
│   │   ├── ocr/
│   │   ├── notifications/
│   │   └── scheduler/
│   ├── tests/
│   └── requirements.txt
│
├── docs/
│   ├── PRD.md
│   ├── ARCHITECTURE.md
│   └── DESIGN.md
│
└── README.md
```

------------------------------------------------------------------------

## 16. Core API Flow

### Create care plan

``` text
POST /prescriptions/upload
POST /patients/{id}/condition
POST /care-plans/generate
GET  /care-plans/{id}
PATCH /care-plans/{id}/approve
```

### Medication

``` text
GET  /patients/{id}/today
POST /medications/{id}/taken
GET  /patients/{id}/adherence
```

### Escalation

``` text
GET /doctor/alerts
POST /alerts/{id}/resolve
```

### Reassessment

``` text
POST /patients/{id}/care-plans/new-version
```

------------------------------------------------------------------------

## 17. Architecture Principle

**AI understands; backend controls; doctor approves; patient confirms.**

This separation should remain central to the implementation.
