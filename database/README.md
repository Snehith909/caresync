# CareSync database

## Identity and doctor ownership

- `auth.users`: Supabase-managed identity, password handling, and sessions.
- `public.profiles`: doctor role, display name, and active status for an authenticated user.
- `public.patients`: existing doctor-assigned patient records.

Every doctor-owned workflow table uses a `doctor_id` foreign key and patient tables also reference `(patient_id, doctor_id)`. These composite foreign keys prevent accidentally linking a record to a patient assigned to another doctor. RLS checks `auth.uid()` and the active-doctor profile for reads and writes.

## Clinical and operational records

| Table | Relationships and purpose |
| --- | --- |
| `appointments` | Belongs to a doctor and patient; has a schedule interval and status |
| `queue_entries` | Belongs to a doctor and patient, optionally links its appointment, and has a daily token |
| `consultations` | Belongs to a doctor and patient; can link an appointment and queue entry |
| `prescriptions` | Belongs to a consultation |
| `medications` | Belongs to a prescription; records dosage, frequency, duration, and instructions |
| `lab_reports` | Belongs to a patient; stores report metadata, structured extracted values, flags, and a private storage path |
| `vitals` | Timestamped measurements for a patient |
| `allergies` | Patient allergy, reaction, and severity records |
| `medical_history` | Categorized patient history entries |
| `follow_ups` | Belongs to a patient and optionally a consultation |
| `notifications` | Doctor-owned reminder metadata, optionally related to a patient |

Existing tables remain in place:

- `care_plans`: immutable version history and review status for care plans.
- `alerts`: patient alerts and acknowledgment state.
- `audit_events`: doctor, action, entity type, entity ID, and timestamp. It does not store patient notes, diagnoses, credentials, or other clinical values.

## Keys, indexes, and timestamps

New entities use UUID primary keys, foreign keys, `created_at`, and `updated_at`. Schedule, queue position, patient timeline, and foreign-key lookups have supporting indexes. `updated_at` is maintained by a database trigger. The queue's token uniqueness scope is doctor plus queue date.

## Migrations

The original schema is preserved in `migrations/20260716000000_initial.sql`. The additive clinical tables are in `migrations/20261008000000_clinical_workflows.sql`. Apply migrations in timestamp order to a Supabase project. Review the schema, RLS policies, and retention requirements with the deploying organization before production use.
