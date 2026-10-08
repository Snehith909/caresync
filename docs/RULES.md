# RULES.md

# Project Rules --- AI-Assisted Post-Discharge Care Platform

## 1. Core Safety Rules

1.  The system is an **AI-assisted care-plan and medication-adherence
    platform**, not an autonomous medical decision-maker.
2.  AI must never invent a medicine, dosage, frequency, duration,
    diagnosis, or treatment instruction.
3.  AI-generated care plans must remain **DRAFT** until an authorized
    doctor approves them.
4.  The approved doctor care plan is the source of truth for patient
    reminders.
5.  If prescription information is unclear, the system must flag it for
    human/doctor verification instead of guessing.
6.  Patient-reported symptoms must remain clearly separated from
    doctor-provided instructions.
7.  The system must not silently modify an approved care plan.
8.  Emergency or clinically serious concerns must be escalated to
    healthcare professionals rather than handled by unsupported AI
    advice.

## 2. AI Rules

### AI may

-   Extract information from prescriptions.
-   Normalize medical abbreviations.
-   Convert approved instructions into simpler language.
-   Translate approved care-plan information.
-   Answer questions using the approved care-plan context.
-   Generate structured JSON from source information.

### AI may not

-   Prescribe medication.
-   Change dosage.
-   Decide that a patient is medically recovered.
-   Stop medication.
-   Add medication.
-   Infer an unspecified treatment.
-   Override doctor instructions.

## 3. Backend Rules

1.  Medication schedules must be controlled by deterministic backend
    logic.
2.  Do not ask the LLM to decide whether a reminder should be sent.
3.  Reminder timing must come from stored schedule/configuration.
4.  Every medication event must have a timestamp.
5.  Patient confirmation must be explicit.
6.  Do not mark a medicine as taken automatically just because the
    reminder was delivered.
7.  Escalation thresholds must be configurable.
8.  Hospital escalation should create an actionable alert/task; it must
    not falsely claim that a doctor contacted the patient.

## 4. Care Plan Versioning Rules

Never overwrite historical care plans.

Use versions:

``` text
V1 → Superseded
V2 → Active
V3 → Future
```

Every new prescription/reassessment should create a new care-plan
version.

The previous plan must remain available for authorized historical
review.

## 5. Notification Rules

Recommended default flow:

``` text
Scheduled time
      ↓
Patient reminder
      ↓
Grace period
      ↓
Second reminder
      ↓
Still unconfirmed
      ↓
Patient + nominee alert
      ↓
Repeated non-adherence
      ↓
Hospital alert
```

Exact timings must be configurable.

Notifications should be:

-   Short
-   Clear
-   Non-judgmental
-   Action-oriented

## 6. Voice Rules

Voice messages must use controlled content.

For a medication reminder:

> "Your scheduled medicine is due. Please confirm after taking it."

For a missed medicine:

> "Your scheduled medicine has not been confirmed. Please check your
> approved care plan."

Voice AI must not invent clinical advice.

## 7. Authentication and Authorization

Roles:

-   PATIENT
-   NOMINEE
-   DOCTOR
-   HOSPITAL_ADMIN

Rules:

-   Patients can access their own records.
-   Nominees can access only information they are authorized to receive.
-   Doctors can access patients assigned to their hospital/care team.
-   Hospital administrators can manage authorized hospital-level
    records.
-   Every protected API must validate authorization.

## 8. Privacy Rules

-   Do not expose medical data unnecessarily.
-   Do not place sensitive medical information in logs.
-   Use HTTPS for API communication.
-   Secure uploaded documents.
-   Store only required patient data.
-   Maintain audit logs for doctor approvals and changes.

## 9. Git Rules

### Branches

``` text
main
develop
feature/*
fix/*
```

### Rules

-   Never push unfinished work directly to `main`.
-   Use meaningful branch names.
-   Make small, focused commits.
-   Pull/rebase from the current development branch before major work.
-   Resolve conflicts locally before opening a pull request.
-   Never commit API keys, passwords, tokens, `.env` files, private
    certificates, or patient data.

### Commit examples

``` text
feat: add prescription upload API
feat: add medication reminder scheduler
fix: correct adherence calculation
docs: update architecture
```

## 10. Environment Variables

Secrets must be stored in environment variables.

Example:

``` text
DATABASE_URL=
LLM_API_KEY=
FIREBASE_PROJECT_ID=
FIREBASE_PRIVATE_KEY=
STORAGE_BUCKET=
```

Never hard-code production credentials.

## 11. API Rules

-   Validate all input with Pydantic schemas.
-   Return consistent error responses.
-   Use appropriate HTTP status codes.
-   Document APIs.
-   Never return sensitive fields unnecessarily.
-   Validate uploaded file type and size.
-   Sanitize user-provided text before processing.

## 12. Frontend Rules

### Patient

-   Mobile-first.
-   Large touch targets.
-   Clear medication timing.
-   Simple language.
-   Voice support where available.
-   Do not overwhelm the patient with medical terminology.

### Doctor

-   Desktop/tablet-friendly.
-   Alerts must be easy to scan.
-   Show adherence evidence before escalation actions.
-   Make care-plan approval/editing explicit.

## 13. Definition of Done

A feature is not complete until:

-   Code works locally.
-   API/input validation exists where relevant.
-   Error handling exists.
-   Basic testing is completed.
-   No secrets are committed.
-   UI works on the target screen size.
-   Documentation is updated when architecture/API behavior changes.
-   Another team member can run the feature from the repository
    instructions.

## 14. Hackathon Priority Rule

When time is limited, prioritize:

1.  Prescription upload.
2.  AI extraction.
3.  Doctor approval.
4.  Daily medication dashboard.
5.  Reminder + taken/missed tracking.
6.  Weekly adherence.
7.  Three-day hospital escalation.
8.  Reassessment/new care-plan loop.

Medicine delivery and advanced voice features should not delay the core
working flow.
