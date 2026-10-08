# PRD --- AI-Assisted Post-Discharge Care & Medication Adherence System

## 1. Product Overview

A healthcare support platform that converts a doctor-approved
prescription/discharge summary into a simple, structured care plan for
patients.

The system monitors daily medication adherence, sends reminders,
escalates repeated missed medication to the nominee/caregiver and
hospital, supports voice interaction in the patient's preferred
language, and starts a new care-plan cycle after hospital reassessment.

**Core principle:** AI assists with extraction, simplification,
translation, and patient communication. It must not independently
prescribe, change dosage, or make clinical decisions.

------------------------------------------------------------------------

## 2. Problem Statement

Patients often leave hospitals with prescriptions and discharge
summaries containing medical terminology, abbreviations, dosage
instructions, and follow-up requirements. Patients may misunderstand or
forget medication schedules and follow-up visits.

Hospitals also have limited visibility into whether patients are
following the prescribed care plan after discharge.

The system should bridge the gap between:

**Hospital → Patient Home → Medication Adherence → Hospital Follow-up →
Updated Care Plan**

------------------------------------------------------------------------

## 3. Goals

### Primary Goals

-   Convert prescription/discharge PDFs into a structured care plan.
-   Allow the patient to provide their current condition.
-   Generate a simple morning/afternoon/night medication dashboard.
-   Provide medication reminders.
-   Allow patients to confirm whether a medicine was taken.
-   Escalate missed medication to the nominee/caregiver.
-   Detect repeated non-adherence and notify the hospital.
-   Allow doctors to review and contact patients.
-   Support reassessment and creation of a new care-plan version.
-   Provide voice assistance for medication-related questions based on
    the approved care plan.
-   Track weekly adherence and treatment progress.

### Secondary Goals

-   Support multiple Indian languages.
-   Estimate when prescribed medicine supply is running low.
-   Provide a refill/order request workflow.
-   Maintain historical care-plan versions.

------------------------------------------------------------------------

## 4. Users

### Patient

-   Upload prescription/discharge summary.
-   Enter current condition.
-   View today's medication schedule.
-   Receive reminders.
-   Confirm medicines as taken.
-   Use voice assistance.
-   View weekly progress.
-   Receive follow-up reminders.
-   Upload a new prescription after reassessment.

### Nominee/Caregiver

-   Receive escalation notifications for missed medication.
-   Receive voice-enabled alert notifications where supported.
-   View limited patient adherence information according to
    consent/permissions.

### Doctor/Hospital Staff

-   Review AI-generated care plans.
-   Approve or edit the care plan.
-   View medication adherence.
-   Receive hospital escalation alerts.
-   Contact the patient.
-   Record reassessment.
-   Create/update the patient's care plan.

------------------------------------------------------------------------

## 5. Core User Journey

1.  Patient signs in.
2.  Patient uploads prescription/discharge PDF or prescription image.
3.  Patient enters current condition.
4.  System extracts relevant information using PDF parsing/OCR.
5.  GenAI converts extracted information into structured care-plan data.
6.  Doctor reviews and approves the generated plan.
7.  Patient receives the approved dashboard.
8.  Patient sees morning, afternoon, and night medicines.
9.  Reminder is sent when a medicine is due.
10. Patient marks the medicine as taken.
11. If the medicine remains unconfirmed after the configured grace
    period, reminders/escalation are sent.
12. Repeated missed medication is tracked.
13. After the hospital-defined repeated non-adherence threshold, the
    hospital receives an alert.
14. Doctor contacts the patient and requests reassessment when
    appropriate.
15. Patient returns to the hospital.
16. Patient uploads the new prescription and current condition.
17. System creates a new care-plan version.
18. Doctor verifies the new plan.
19. Monitoring starts again.
20. Doctor can close the care plan when treatment is completed.

------------------------------------------------------------------------

## 6. Functional Requirements

### FR-01: Prescription Upload

The system shall support:

-   PDF
-   JPG
-   PNG

The uploaded document shall be associated with the patient's care-plan
version.

### FR-02: Patient Current Condition

The patient shall be able to enter their current condition using text
and, where supported, voice input.

The system must clearly distinguish patient-reported symptoms from
doctor-provided clinical instructions.

### FR-03: Information Extraction

The system should extract:

-   Medicine name
-   Dose
-   Frequency
-   Scheduled time
-   Before/after food instruction
-   Duration
-   Quantity, if available
-   Follow-up date/interval
-   Warning signs explicitly present in the source document

If information is unclear, the system should flag it for doctor
verification rather than guessing.

### FR-04: Care Plan Generation

The system shall create structured care-plan data.

Example:

``` json
{
  "medicine": "Medicine A",
  "dose": "500 mg",
  "frequency": "2 times/day",
  "timings": ["11:00", "21:00"],
  "food_instruction": "after food",
  "duration_days": 7
}
```

### FR-05: Doctor Approval

The AI-generated care plan shall remain a draft until approved by an
authorized doctor/hospital user.

The doctor can edit:

-   Medicine
-   Dose
-   Frequency
-   Timing
-   Duration
-   Follow-up
-   Instructions

### FR-06: Daily Dashboard

The patient shall see:

-   Morning medicines
-   Afternoon medicines
-   Night medicines
-   Scheduled times
-   Food instructions
-   Taken/missed status
-   Voice assistance

### FR-07: Medication Reminder

For each scheduled medicine:

1.  Send reminder at scheduled time.
2.  Wait for patient confirmation.
3.  Send follow-up reminder after configured grace period.
4.  If still unconfirmed, send escalation according to hospital policy.

### FR-08: Patient and Nominee Alerts

Example:

``` text
11:00 — Medicine due
11:15 — Patient reminder
11:30 — Second patient reminder
12:00 — Patient + nominee alert
```

The exact timing should be configurable.

Voice notifications should use approved notification text and should not
generate new medical advice.

### FR-09: Three-Day Non-Adherence Escalation

The hospital may configure a threshold such as repeated missed
medication across three days.

When the threshold is reached:

-   Create hospital alert.
-   Show patient adherence history.
-   Notify authorized hospital staff.
-   Provide a workflow for doctor follow-up/contact.

The system should not automatically claim that a doctor has called; it
should create the actionable hospital task.

### FR-10: Weekly Progress

Show:

-   Daily adherence
-   Missed doses
-   Completed doses
-   Weekly adherence percentage
-   Escalation history

Example:

``` text
Monday     ✓ 100%
Tuesday    ✓ 100%
Wednesday  ⚠ 67%
Thursday   ✓ 100%
Friday     ✓ 100%
```

### FR-11: Follow-up

The system shall use the doctor-approved follow-up date/interval.

It shall send:

-   Upcoming appointment reminder
-   Follow-up due notification

### FR-12: Reassessment and New Care Plan

After hospital reassessment:

``` text
New prescription
+
New patient condition
        ↓
New Care Plan Version
```

Old care plans must remain available as historical records.

### FR-13: Voice Assistant

Patient can ask questions about the approved care plan.

Example:

> "Should I take my morning medicine after food?"

The assistant should answer using the approved care-plan data.

For questions requiring clinical judgment, the assistant must direct the
patient to the healthcare provider rather than invent an answer.

### FR-14: Medicine Refill

If quantity is available:

``` text
Prescribed quantity
        ↓
Taken doses
        ↓
Estimated remaining quantity
        ↓
Low-stock warning
        ↓
Request refill
```

For the hackathon, pharmacy delivery can be demonstrated as a
mock/integration-ready workflow.

------------------------------------------------------------------------

## 7. Non-Functional Requirements

-   Secure authentication.
-   Role-based access control.
-   Encryption in transit.
-   Minimal collection of personal data.
-   Audit trail for doctor edits and approvals.
-   Reliable reminder scheduling.
-   Clear AI-generated content labeling.
-   Mobile-first patient experience.
-   Responsive doctor dashboard.
-   API validation and error handling.
-   No silent modification of doctor-approved medication instructions.

------------------------------------------------------------------------

## 8. MVP Scope

### Must Have

-   Patient authentication
-   Prescription PDF/image upload
-   OCR/text extraction
-   GenAI structured extraction
-   Doctor approval
-   Daily medication dashboard
-   Morning/afternoon/night schedule
-   Reminder system
-   Taken/missed tracking
-   Nominee alert
-   Weekly adherence
-   Three-day escalation
-   Doctor dashboard
-   Reassessment/new care-plan loop

### Nice to Have

-   Voice assistant
-   Multiple Indian languages
-   Medicine stock tracking
-   Refill request
-   Advanced analytics

### Future

-   Pharmacy integration
-   Hospital EMR integration
-   Wearable integration
-   Appointment booking
-   Automated clinical risk scoring, subject to clinical validation

------------------------------------------------------------------------

## 9. Success Metrics

-   Care-plan generation success rate
-   Doctor approval/edit rate
-   Medication adherence percentage
-   Number of missed doses detected
-   Number of successful escalations
-   Follow-up completion rate
-   Time saved in converting discharge instructions into a usable plan
-   Patient understanding/usability feedback

------------------------------------------------------------------------

## 10. Safety Boundary

The platform is a care-plan assistance and adherence system, not an
autonomous medical decision-maker.

The system must:

-   Preserve source instructions.
-   Flag ambiguity.
-   Require doctor approval before activating a new care plan.
-   Avoid inventing medications or dosages.
-   Avoid changing treatment without authorized clinical input.
-   Clearly identify AI-generated drafts.
-   Provide emergency guidance only when explicitly present in the
    approved clinical instructions or through a safe escalation to
    healthcare professionals.
