# AI-Assisted Post-Discharge Care Platform

> **From prescription to daily care, adherence, escalation,
> reassessment, and recovery.**

## 1. Overview

This project is an AI-assisted post-discharge healthcare platform
designed to help patients follow doctor-approved medication and
follow-up plans after leaving the hospital.

The platform converts a prescription/discharge summary into a structured
care plan, presents medicines in a simple daily dashboard, reminds
patients when medicines are due, escalates repeated missed medication to
a nominee and hospital, and supports a new care-plan cycle after
clinical reassessment.

### Core Loop

``` text
Prescription PDF
      +
Current Patient Condition
      ↓
OCR / Text Extraction
      ↓
GenAI
      ↓
Structured Care Plan
      ↓
Doctor Approval
      ↓
Daily Patient Dashboard
      ↓
Medication Adherence
      ↓
Missed Dose Escalation
      ↓
Hospital Follow-up
      ↓
Reassessment
      ↓
New Prescription + Condition
      ↓
New Care Plan
```

------------------------------------------------------------------------

## 2. Problem

After discharge, patients may struggle to understand medical
terminology, remember medication timings, follow treatment instructions,
or attend follow-up appointments.

Hospitals may also have little visibility into whether patients are
following their care plans.

The project connects the patient's home-care process with the hospital's
follow-up workflow.

------------------------------------------------------------------------

## 3. Solution

The system provides:

-   Prescription/discharge PDF upload.
-   Patient current-condition input.
-   OCR and AI extraction.
-   Doctor-verified care plans.
-   Morning/afternoon/night medication dashboard.
-   Medication reminders.
-   Patient confirmation of taken medication.
-   Nominee/caregiver escalation.
-   Weekly adherence tracking.
-   Repeated non-adherence hospital alerts.
-   Doctor follow-up workflow.
-   Voice-based care-plan assistance.
-   New care-plan versions after reassessment.
-   Medicine low-stock/refill workflow.

------------------------------------------------------------------------

## 4. Product Modules

### Patient App

Built with Flutter.

Features:

-   Authentication
-   Prescription upload
-   Current condition
-   Daily dashboard
-   Medication reminders
-   Mark as taken
-   Weekly progress
-   Voice assistant
-   Follow-up reminders
-   Re-upload after reassessment
-   Refill request

### Doctor Portal

Built with React + Tailwind.

Features:

-   Hospital login
-   Patient list
-   Care-plan review
-   AI draft approval
-   Patient adherence
-   Missed-dose alerts
-   Hospital escalation
-   Patient detail
-   Reassessment
-   New care-plan creation
-   Treatment history

### Backend

Built with FastAPI.

Responsibilities:

-   REST APIs
-   Authentication/authorization
-   Care-plan management
-   Medication scheduling
-   Adherence tracking
-   Notification orchestration
-   AI/OCR integration
-   Doctor workflow
-   Care-plan versioning

------------------------------------------------------------------------

## 5. Technology Stack

  Layer            Technology
  ---------------- -----------------------------------------
  Patient App      Flutter / Dart
  Doctor Portal    React / Tailwind CSS
  Backend          Python / FastAPI
  Database         PostgreSQL
  ORM              SQLAlchemy
  Validation       Pydantic
  PDF Extraction   PyMuPDF
  OCR              PaddleOCR
  GenAI            Gemini API / OpenAI API
  Voice STT        Whisper or suitable speech API
  Voice TTS        Suitable TTS API
  Authentication   Firebase Auth
  Notifications    Firebase Cloud Messaging
  Storage          Firebase Storage / Cloud Object Storage
  Scheduling       APScheduler for MVP
  Deployment       Vercel + Render/Railway

------------------------------------------------------------------------

## 6. Architecture

``` text
             Flutter Patient App
                     │
                     │ HTTPS REST
                     ▼
               FastAPI Backend
                     │
       ┌─────────────┼──────────────┐
       ▼             ▼              ▼
  PostgreSQL       OCR             GenAI
       │             │              │
       │             └──────┬───────┘
       │                    ▼
       │              Care Plan JSON
       │                    │
       └────────────┬───────┘
                    ▼
             Reminder Engine
                    │
          ┌─────────┼─────────┐
          ▼         ▼         ▼
       Patient    Nominee   Hospital
          │                   │
          │             React Doctor
          │                Portal
          └─────────┬─────────┘
                    ▼
               Reassessment
                    │
                    ▼
              New Care Plan
```

------------------------------------------------------------------------

## 7. Reminder & Escalation

Example configurable flow:

``` text
11:00 AM
Medicine due
     ↓
Patient reminder
     ↓
11:15
Second reminder
     ↓
11:30
Voice reminder
     ↓
12:00
Still not confirmed
     ↓
Patient + nominee warning
     ↓
Repeated non-adherence
     ↓
Hospital alert
     ↓
Doctor contacts patient
```

The backend determines reminder timing. The LLM does not.

------------------------------------------------------------------------

## 8. Weekly Adherence

Example:

``` text
Monday      ✓ 100%
Tuesday     ✓ 100%
Wednesday   ⚠ 67%
Thursday    ✓ 100%
Friday      ✓ 100%
Saturday    ✕ 50%
Sunday      ● Today
```

Adherence:

``` text
Adherence % =
Confirmed doses / Scheduled doses × 100
```

------------------------------------------------------------------------

## 9. Reassessment Loop

After a doctor requests reassessment:

``` text
Patient visits hospital
        ↓
Doctor reassesses
        ↓
New prescription
        +
New current condition
        ↓
Patient uploads to Tab 1
        ↓
GenAI creates new draft
        ↓
Doctor approves
        ↓
Care Plan V2 becomes active
        ↓
Daily monitoring restarts
```

Previous care plans are preserved as history.

------------------------------------------------------------------------

## 10. AI Safety

This project does **not** use AI as an autonomous doctor.

### AI is used for

-   Document understanding
-   OCR post-processing
-   Information extraction
-   Simplification
-   Translation
-   Controlled care-plan explanations

### AI is not allowed to

-   Prescribe medication
-   Change dosage
-   Stop medication
-   Add medication
-   Decide recovery
-   Override a doctor

The doctor-approved plan is the source of truth.

------------------------------------------------------------------------

## 11. Repository Structure

``` text
healthcare-care-platform/
│
├── patient_app/
├── doctor_portal/
├── backend/
│   ├── app/
│   │   ├── api/
│   │   ├── models/
│   │   ├── schemas/
│   │   ├── services/
│   │   ├── ai/
│   │   ├── ocr/
│   │   ├── scheduler/
│   │   └── notifications/
│   └── tests/
│
├── docs/
│   ├── PRD.md
│   ├── ARCHITECTURE.md
│   ├── DESIGN.md
│   ├── RULES.md
│   └── TASKS.md
│
├── .env.example
├── .gitignore
└── README.md
```

------------------------------------------------------------------------

## 12. Getting Started

### Clone

``` bash
git clone <repository-url>
cd healthcare-care-platform
```

### Backend

``` bash
cd backend

python -m venv venv

# Windows
venv\Scripts\activate

# Linux/macOS
source venv/bin/activate

pip install -r requirements.txt

uvicorn app.main:app --reload
```

API documentation:

``` text
http://localhost:8000/docs
```

### Doctor Portal

``` bash
cd doctor_portal
npm install
npm run dev
```

### Patient App

``` bash
cd patient_app
flutter pub get
flutter run
```

------------------------------------------------------------------------

## 13. Environment Variables

Create a `.env` file based on `.env.example`.

Example:

``` text
DATABASE_URL=
LLM_API_KEY=
FIREBASE_PROJECT_ID=
FIREBASE_PRIVATE_KEY=
STORAGE_BUCKET=
```

Never commit `.env`.

------------------------------------------------------------------------

## 14. Development Workflow

Use:

``` text
main
develop
feature/*
fix/*
```

Recommended workflow:

``` text
Create feature branch
       ↓
Develop
       ↓
Test locally
       ↓
Commit
       ↓
Push
       ↓
Pull Request
       ↓
Code Review
       ↓
Merge into develop
       ↓
Integration testing
       ↓
main
```

------------------------------------------------------------------------

## 15. Hackathon MVP

The minimum end-to-end demo should prove:

``` text
1. Upload prescription
2. Enter current condition
3. AI extracts medication plan
4. Doctor approves
5. Patient sees morning/noon/night
6. Reminder is generated
7. Patient marks medicine taken/missed
8. Weekly adherence updates
9. Repeated missed medication creates hospital alert
10. Doctor initiates reassessment
11. Patient uploads new prescription
12. New care-plan version is generated
```

If these work reliably, the core product is complete.

------------------------------------------------------------------------

## 16. Future Enhancements

-   Real pharmacy integration.
-   Hospital EMR integration.
-   Appointment booking.
-   More Indian languages.
-   Offline-first patient app.
-   Wearable/device integration.
-   Advanced hospital analytics.
-   Patient education content.
-   Secure caregiver sharing.
-   Clinical validation and production compliance.

------------------------------------------------------------------------

## 17. Project Principle

> **AI understands. Backend controls. Doctor approves. Patient confirms.
> Hospital follows up.**

This principle should guide every technical and product decision.

------------------------------------------------------------------------

## 18. License

Add the project's selected open-source/proprietary license before public
release.

------------------------------------------------------------------------

## 19. Repository Documentation

- [Product requirements](docs/PRD.md)
- [Architecture](docs/ARCHITECTURE.md)
- [Patient and doctor UX design](docs/DESIGN.md)
- [Project rules and healthcare safety constraints](docs/RULES.md)
- [Development task plan](docs/TASKS.md)

## 20. Flutter Patient App

The initial Flutter patient-app scaffold is in `lib/main.dart`. The
project includes Android, iOS, web, Windows, macOS, and Linux targets.

Install dependencies and run the app with:

```bash
flutter pub get
flutter run
```

Run the current widget tests with:

```bash
flutter test
```
