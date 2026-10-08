# TASKS.md

# Development Tasks --- AI-Assisted Post-Discharge Care Platform

## 0. Team Structure

### Member 1 --- Patient App

**Technology:** Flutter

Responsibilities:

-   Patient authentication
-   Tab 1
-   Tab 2
-   Tab 3
-   Notifications UI
-   Voice UI
-   Patient API integration

### Member 2 --- Backend

**Technology:** FastAPI + PostgreSQL

Responsibilities:

-   Authentication integration
-   Database models
-   REST APIs
-   Care-plan APIs
-   Medication APIs
-   Adherence APIs
-   Follow-up APIs

### Member 3 --- AI/OCR

**Technology:** Python + OCR + LLM

Responsibilities:

-   PDF extraction
-   OCR
-   Prompt engineering
-   Structured JSON extraction
-   Validation
-   Translation
-   Voice pipeline support

### Member 4 --- Doctor Portal + Integration

**Technology:** React + Tailwind

Responsibilities:

-   Doctor dashboard
-   Patient detail screen
-   Alerts
-   Doctor approval
-   Reassessment
-   Care-plan versioning UI
-   Deployment/integration support

### Team Leader

Responsibilities:

-   Architecture
-   Git/GitHub strategy
-   API contracts
-   Integration
-   Code review
-   End-to-end testing
-   Demo flow
-   Deployment

------------------------------------------------------------------------

# 1. Phase 1 --- Project Setup

-   [ ] Create GitHub repository.
-   [ ] Create `main` and `develop` branches.
-   [ ] Add project README.
-   [ ] Add PRD.
-   [ ] Add architecture document.
-   [ ] Add design document.
-   [ ] Add rules document.
-   [ ] Add task document.
-   [ ] Create `.gitignore`.
-   [ ] Create `.env.example`.
-   [ ] Define API contract.
-   [ ] Define database schema.
-   [ ] Agree on JSON structure for care plans.

------------------------------------------------------------------------

# 2. Phase 2 --- Backend Foundation

-   [ ] Create FastAPI project.
-   [ ] Configure PostgreSQL.
-   [ ] Configure SQLAlchemy.
-   [ ] Add Pydantic schemas.
-   [ ] Create user model.
-   [ ] Create patient model.
-   [ ] Create nominee relationship.
-   [ ] Create doctor/hospital model.
-   [ ] Create care-plan model.
-   [ ] Create medicine model.
-   [ ] Create medication schedule model.
-   [ ] Create adherence model.
-   [ ] Create alert model.
-   [ ] Create follow-up model.
-   [ ] Add database migrations.
-   [ ] Add API error handling.
-   [ ] Add authentication/authorization.

------------------------------------------------------------------------

# 3. Phase 3 --- Prescription Upload

-   [ ] Create upload API.
-   [ ] Validate PDF/JPG/PNG.
-   [ ] Validate file size.
-   [ ] Store uploaded file securely.
-   [ ] Create prescription document record.
-   [ ] Extract text from text-based PDFs.
-   [ ] Route scanned documents to OCR.
-   [ ] Store extraction status.
-   [ ] Handle unreadable documents.

### Target flow

``` text
Upload
  ↓
Validate
  ↓
Store
  ↓
Extract/OCR
  ↓
Raw text
```

------------------------------------------------------------------------

# 4. Phase 4 --- AI Extraction

-   [ ] Design care-plan JSON schema.
-   [ ] Create LLM extraction prompt.
-   [ ] Send extracted text to LLM.
-   [ ] Validate returned JSON.
-   [ ] Detect missing fields.
-   [ ] Flag ambiguous medication instructions.
-   [ ] Normalize frequency/timing.
-   [ ] Extract follow-up information.
-   [ ] Extract explicit warning signs.
-   [ ] Generate patient-friendly wording.
-   [ ] Add AI-generated draft status.

### Target flow

``` text
Raw prescription text
        ↓
       LLM
        ↓
Structured JSON
        ↓
Pydantic validation
        ↓
Draft Care Plan
```

------------------------------------------------------------------------

# 5. Phase 5 --- Patient Current Condition

-   [ ] Create current-condition API.
-   [ ] Add text input.
-   [ ] Add optional voice input.
-   [ ] Store timestamp.
-   [ ] Associate condition with care-plan version.
-   [ ] Clearly label it as patient-reported information.

------------------------------------------------------------------------

# 6. Phase 6 --- Doctor Approval

-   [ ] Create doctor login.
-   [ ] Create pending-care-plan list.
-   [ ] Create care-plan detail page.
-   [ ] Show extracted prescription information.
-   [ ] Allow doctor editing.
-   [ ] Allow approve action.
-   [ ] Record doctor ID.
-   [ ] Record approval timestamp.
-   [ ] Prevent unapproved plans from becoming active.
-   [ ] Add audit log.

------------------------------------------------------------------------

# 7. Phase 7 --- Daily Medication Dashboard

## Morning

-   [ ] Show medicines.
-   [ ] Show dosage.
-   [ ] Show food instruction.
-   [ ] Show scheduled time.
-   [ ] Add mark-as-taken action.
-   [ ] Add voice button.

## Afternoon

-   [ ] Same functionality.

## Night

-   [ ] Same functionality.

### Patient status

-   [ ] Upcoming
-   [ ] Due
-   [ ] Taken
-   [ ] Missed
-   [ ] Escalated

------------------------------------------------------------------------

# 8. Phase 8 --- Reminder Engine

-   [ ] Create medication event scheduler.
-   [ ] Trigger reminder at scheduled time.
-   [ ] Add configurable grace period.
-   [ ] Send second reminder.
-   [ ] Check taken status.
-   [ ] Trigger patient warning.
-   [ ] Trigger nominee notification.
-   [ ] Log notification delivery.
-   [ ] Retry failed notifications.
-   [ ] Avoid duplicate notifications.

### Example

``` text
11:00 → Patient reminder
11:15 → Second reminder
11:30 → Voice reminder
12:00 → Patient + nominee alert
```

------------------------------------------------------------------------

# 9. Phase 9 --- Weekly Adherence

-   [ ] Calculate daily scheduled doses.
-   [ ] Calculate taken doses.
-   [ ] Calculate missed doses.
-   [ ] Calculate daily adherence.
-   [ ] Calculate weekly adherence.
-   [ ] Show Monday--Sunday.
-   [ ] Show day details.
-   [ ] Show missed-dose history.
-   [ ] Show escalation history.

Formula:

``` text
Adherence % =
confirmed doses / scheduled doses × 100
```

------------------------------------------------------------------------

# 10. Phase 10 --- Three-Day Escalation

-   [ ] Define configurable repeated non-adherence threshold.
-   [ ] Detect consecutive/repeated missed days according to policy.
-   [ ] Create hospital alert.
-   [ ] Show alert in doctor dashboard.
-   [ ] Show patient adherence history.
-   [ ] Allow doctor to acknowledge alert.
-   [ ] Add contact-patient action.
-   [ ] Add follow-up/reassessment status.

Example:

``` text
Day 1 → missed
Day 2 → missed
Day 3 → missed
          ↓
Hospital alert
          ↓
Doctor contacts patient
```

------------------------------------------------------------------------

# 11. Phase 11 --- Doctor Dashboard

-   [ ] Dashboard summary cards.
-   [ ] Patient list.
-   [ ] Search/filter.
-   [ ] Adherence percentage.
-   [ ] Missed medication count.
-   [ ] Escalation alerts.
-   [ ] Patient detail.
-   [ ] Current care plan.
-   [ ] Historical care plans.
-   [ ] Follow-up dates.
-   [ ] Contact/reassessment workflow.

------------------------------------------------------------------------

# 12. Phase 12 --- Reassessment Loop

-   [ ] Doctor records reassessment.
-   [ ] Patient returns to hospital.
-   [ ] Patient uploads new prescription.
-   [ ] Patient enters new current condition.
-   [ ] Create new care-plan version.
-   [ ] Preserve old version.
-   [ ] Run extraction again.
-   [ ] Require doctor approval again.
-   [ ] Activate new care plan.
-   [ ] Reset medication schedule.
-   [ ] Continue adherence tracking.

### Target flow

``` text
Doctor reassessment
       ↓
New PDF + condition
       ↓
Tab 1
       ↓
GenAI
       ↓
Doctor approval
       ↓
New care plan
       ↓
Daily dashboard
```

------------------------------------------------------------------------

# 13. Phase 13 --- Voice

-   [ ] Speech-to-text.
-   [ ] Medication-specific question flow.
-   [ ] Approved care-plan context.
-   [ ] Text response.
-   [ ] Text-to-speech.
-   [ ] Kannada support.
-   [ ] English support.
-   [ ] Fallback to text if voice fails.
-   [ ] Safety response for unsupported clinical questions.

------------------------------------------------------------------------

# 14. Phase 14 --- Medicine Refill

-   [ ] Store prescribed quantity when available.
-   [ ] Track consumed doses.
-   [ ] Estimate remaining quantity.
-   [ ] Configure low-stock threshold.
-   [ ] Show low-stock warning.
-   [ ] Add refill request.
-   [ ] Create mock pharmacy order for hackathon demo.

------------------------------------------------------------------------

# 15. Phase 15 --- Testing

## Backend

-   [ ] Authentication tests.
-   [ ] Upload tests.
-   [ ] Care-plan generation tests.
-   [ ] Medication scheduling tests.
-   [ ] Adherence tests.
-   [ ] Escalation tests.
-   [ ] Versioning tests.

## AI

-   [ ] Correct medicine extraction.
-   [ ] Correct dosage extraction.
-   [ ] Ambiguous prescription handling.
-   [ ] Missing-field handling.
-   [ ] No hallucinated medicine test.
-   [ ] JSON validation test.

## Frontend

-   [ ] Patient login.
-   [ ] Upload.
-   [ ] Dashboard.
-   [ ] Taken button.
-   [ ] Weekly tracking.
-   [ ] Alerts.
-   [ ] Doctor approval.
-   [ ] Reassessment.

------------------------------------------------------------------------

# 16. Phase 16 --- Deployment

-   [ ] Deploy FastAPI.
-   [ ] Deploy PostgreSQL.
-   [ ] Deploy React doctor portal.
-   [ ] Configure Firebase.
-   [ ] Configure FCM.
-   [ ] Configure storage.
-   [ ] Configure environment variables.
-   [ ] Test production API.
-   [ ] Build Android APK.
-   [ ] Test complete production flow.

------------------------------------------------------------------------

# 17. Final Hackathon Demo Checklist

-   [ ] Patient logs in.
-   [ ] Uploads prescription.
-   [ ] Enters current condition.
-   [ ] AI extracts medicines.
-   [ ] Doctor reviews/approves.
-   [ ] Patient sees morning/afternoon/night.
-   [ ] Reminder appears.
-   [ ] Patient marks medicine taken.
-   [ ] Demonstrate missed medicine.
-   [ ] Demonstrate nominee alert.
-   [ ] Demonstrate 3-day escalation.
-   [ ] Doctor sees alert.
-   [ ] Doctor records follow-up.
-   [ ] Patient uploads new prescription.
-   [ ] New care-plan version appears.
-   [ ] Show treatment history.
-   [ ] Demonstrate voice assistant if stable.

------------------------------------------------------------------------

# 18. Priority Labels

### P0 --- Must work

-   Upload
-   OCR/extraction
-   AI structured output
-   Doctor approval
-   Daily dashboard
-   Medication status
-   Reminder
-   Adherence
-   Hospital escalation
-   Reassessment loop

### P1 --- Strong demo features

-   Voice
-   Indian-language support
-   Nominee alerts
-   Care-plan history

### P2 --- Extension

-   Medicine delivery
-   Pharmacy integration
-   Advanced analytics
-   EMR integration
