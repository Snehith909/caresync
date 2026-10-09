# PRD — CareSync Doctor Website

## 1. Product
CareSync Doctor Portal is a web application for doctors and authorized hospital staff to monitor discharged patients, review AI-extracted prescription/care-plan information, track medication adherence, handle escalation alerts, and approve updated care plans after reassessment.

The patient experience is a separate Flutter mobile application. The doctor portal and patient app use the same FastAPI backend and PostgreSQL database.

## 2. Main Goal
Give doctors one place to:
- See assigned patients.
- Review active care plans.
- Review prescription/discharge documents.
- Review AI-generated medication information.
- Approve or reject care plans.
- Monitor medication adherence.
- Receive alerts for repeated missed medication.
- Track follow-up/reassessment.
- Create and approve a new care-plan version after reassessment.

## 3. Users
### Doctor
Can view assigned patients, review care plans, monitor adherence, manage alerts, and perform reassessment.

### Hospital Admin
Can manage doctors/patients and view hospital-level operational information if enabled.

## 4. Core Screens
1. Login
2. Dashboard
3. Patients
4. Patient Details
5. Care Plan Review
6. Alerts
7. Reassessment
8. Care Plan History
9. Doctor Profile/Settings

## 5. Dashboard
Show:
- Total active patients
- Patients needing attention
- Patients with low adherence
- Missed-dose alerts
- Follow-ups due
- Recent reassessment activity

Example:
- Active patients: 248
- Low adherence: 18
- Critical alerts: 4
- Follow-ups due today: 12

## 6. Patient Details
Display:
- Patient profile
- Nominee/caregiver information
- Current condition
- Current active care-plan version
- Medicines and schedules
- Daily/weekly adherence
- Missed-dose history
- Alerts
- Upcoming follow-up
- Previous care-plan versions

## 7. AI Care-Plan Review
When a patient uploads a prescription:
1. Backend extracts PDF/image text.
2. OCR is used when required.
3. AI converts information into structured data.
4. Doctor reviews the extracted information.
5. Doctor approves, requests correction, or rejects it.

The AI must never independently prescribe, diagnose, change dosage, or override a doctor's decision.

## 8. Escalation
Medication due -> patient reminder -> nominee warning when configured -> repeated non-adherence -> hospital alert.

After three days of repeated missed medication, create a doctor/hospital task for follow-up.

The system creates the alert; it must not falsely claim that a doctor has called the patient.

## 9. Reassessment
Doctor can:
- Record reassessment notes.
- Review current condition.
- Request a new prescription/care-plan update.
- Approve a new care-plan version.

Never overwrite historical care plans.

Example:
- V1: SUPERSEDED
- V2: ACTIVE

## 10. Non-Goals
For the MVP, do not build:
- Autonomous diagnosis
- Autonomous prescription generation
- Autonomous dosage modification
- Fully automated clinical decision making
- Complex billing
- Full hospital EMR replacement

## 11. Success Metrics
- Doctor can find a patient in under 10 seconds.
- Doctor can understand adherence status quickly.
- Prescription-to-review workflow works end-to-end.
- Alerts are actionable and traceable.
- Care-plan history is preserved.
