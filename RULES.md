# RULES — CareSync Doctor Website

## 1. Clinical Safety
1. The doctor is the final clinical authority.
2. AI output is advisory/administrative and must be reviewed.
3. Never let AI independently prescribe.
4. Never automatically change dosage.
5. Never automatically add or remove medicines.
6. Never claim a diagnosis unless it is explicitly present in an authorized clinical record.
7. Never claim that a doctor called a patient unless the event is actually recorded.
8. Do not mark a patient recovered automatically.

## 2. Access Control
- Doctor sees only authorized patients.
- Hospital admin permissions must be separate.
- Patients cannot access the doctor portal.
- Never place privileged API keys in React code.

## 3. Care Plans
- Every care plan has a version.
- Approved plans become ACTIVE.
- Replaced plans become SUPERSEDED.
- Historical plans are read-only.
- Approval must record doctor, timestamp, and action.

## 4. Alerts
- Alerts must be generated from backend rules.
- Alert state: OPEN, ACKNOWLEDGED, RESOLVED.
- Escalation must be traceable.
- Do not spam doctors with duplicate alerts.
- Use severity levels.

## 5. Data
- Validate all API input.
- Validate uploaded file type and size.
- Do not expose unnecessary patient information.
- Do not put patient medical information in frontend logs.
- Do not commit secrets to Git.

## 6. UI
- Use consistent terminology.
- Avoid unnecessary animations.
- Make urgent information obvious.
- Never use red for normal information.
- Always show loading, empty, error, and success states.

## 7. Code
- TypeScript strict mode.
- Reusable components.
- API logic separated from UI.
- No hardcoded patient data in production.
- Environment variables for API URLs and configuration.
- Use linting and formatting.

## 8. Hackathon Rule
Build the complete happy path first:

Login -> Dashboard -> Patient -> Care Plan Review -> Approve -> Adherence -> Alert -> Reassessment -> New Version.

Only add extra features after this path works.
