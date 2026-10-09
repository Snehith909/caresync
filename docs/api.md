# CareSync API

## API convention

The current backend is Supabase. It exposes authenticated REST endpoints under `/rest/v1`, Auth endpoints under `/auth/v1`, Storage endpoints under `/storage/v1`, and the existing workflow functions under `/rest/v1/rpc`. Requests use the Supabase URL and public anon/publishable key; authenticated operations also carry the user's access token. Row-level security and database constraints enforce access and validation. The browser must never use a service-role key.

## Patient mobile integration

The additive patient integration migration exposes the following
RLS-protected operations to an authenticated patient:

| Operation | Supabase resource |
| --- | --- |
| Load assigned patient record | `GET /rest/v1/patients?patient_user_id=eq.{auth.uid()}` |
| Update current condition | `POST /rest/v1/rpc/update_patient_condition` |
| Upload a prescription/report | Private Storage bucket `care-plan-documents`, then `POST /rest/v1/rpc/register_patient_document` |
| Record taken/missed medicine | `POST /rest/v1/rpc/record_medication_adherence` |
| Read active/history care plans | `GET /rest/v1/care_plans?patient_id=eq.{assignedPatientId}` |

The patient ID is resolved from the authenticated user and every RPC
re-checks that relationship. Clients must not supply a doctor ID or
impersonate another patient.

The paths below describe the current Supabase resources and their purpose; they are not a claim that a separate `/api` Express server exists.

## Existing doctor portal workflows

| Operation | Supabase resource | Access / behavior |
| --- | --- | --- |
| Sign in, restore session, sign out | Supabase Auth | Invited doctor accounts only |
| Read doctor profile | `GET /rest/v1/profiles?select=display_name,role,active&user_id=eq.{userId}` | Own active profile |
| List and register patients | `GET` / `POST /rest/v1/patients` | RLS restricts records to assigned doctor |
| Read care plans and alerts | `GET /rest/v1/care_plans`, `GET /rest/v1/alerts` | Doctor-scoped; plans are versioned |
| Create a care-plan draft | `POST /storage/v1/object/care-plan-documents/{path}`, then `POST /rest/v1/rpc/create_care_plan_draft` | Private upload, validated transaction |
| Review a care plan | `POST /rest/v1/rpc/act_on_care_plan` | Approve, request correction, or reject |
| Acknowledge an alert | `POST /rest/v1/rpc/acknowledge_alert` | Doctor-scoped state transition |
| Open a care-plan source | `POST /storage/v1/object/sign/care-plan-documents/{path}` | Short-lived signed URL |

## Clinical workflow resources

The additive clinical-workflow migration exposes the following RLS-protected PostgREST resources:

| Resource | Supported data |
| --- | --- |
| `/rest/v1/appointments` | Doctor schedule, patient, interval, and status |
| `/rest/v1/queue_entries` | Daily token, check-in time, and queue status |
| `/rest/v1/consultations` | Symptoms, clinician notes, diagnosis, treatment plan, follow-up date |
| `/rest/v1/prescriptions` | Prescription linked to a consultation |
| `/rest/v1/medications` | Medicine, dosage, frequency, duration, and instructions |
| `/rest/v1/lab_reports` | Report metadata, private storage path, review status, structured values/flags |
| `/rest/v1/vitals` | Timestamped measurements |
| `/rest/v1/allergies` | Patient allergy and reaction records |
| `/rest/v1/medical_history` | Patient history entries |
| `/rest/v1/follow_ups` | Scheduled follow-ups and status |
| `/rest/v1/notifications` | Doctor-scoped reminder metadata |

The schema makes these resources available; additional transactional workflows (for example, token allocation/call-next and coordinated appointment/queue transitions) should be implemented as database functions before being exposed in the UI.

## AI

No AI endpoint is active in the frontend. A future authenticated Edge Function can provide patient summary, consultation summary, SOAP draft, lab summary, and clinical-priority suggestions after an approved provider and privacy controls are configured. AI-generated content must be visibly marked as decision support and reviewed by a clinician; it must not be presented as autonomous diagnosis.
