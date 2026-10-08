# CareSync Backend

FastAPI REST API for the CareSync patient app.

## Run locally

Create a virtual environment, install dependencies, and start the API:

```bash
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
uvicorn app.main:app --reload
```

The API is available at `http://localhost:8000`, with interactive
documentation at `http://localhost:8000/docs`.

The current implementation provides the first API contract for health
checks, prescription uploads, patient conditions, today's medications,
explicit taken/missed medication events, adherence, escalation alerts,
follow-ups, voice-safe responses, and refill requests.

## API behavior

The local default uses SQLite. Set `DATABASE_URL` to a PostgreSQL
connection string for deployment. Authentication is represented locally
by `X-User-Id` and `X-User-Role` headers so the API contract can be
tested before Firebase Admin verification is configured. Replace that
adapter with Firebase token verification before production use.

Uploaded PDFs and images are validated and stored under `UPLOAD_DIR`.
The extraction status is explicit: text extraction is pending for PDF
and image documents until the OCR adapter is connected. The API never
turns an unverified extraction into an active care plan.

Run backend tests from the repository root:

```bash
cd backend
pytest
```

The backend currently provides:

- User and patient profiles with role checks.
- Prescription upload and document records.
- Patient-reported conditions.
- Immutable care-plan versions with doctor approval and audit entries.
- Deterministic medication schedules and explicit adherence events.
- Weekly adherence calculations and hospital escalation alerts.
- Follow-up scheduling.
- Restricted voice responses that defer treatment changes to clinicians.
- Mock-ready refill requests.
- Gemini-generated care-plan drafts that remain pending until a doctor approves them.

## Route groups

```text
/auth              user bootstrap contract
/patients          patient profiles, conditions, history, dashboard, voice, refills
/prescriptions     validated document upload
/care-plans        draft, detail, approval, and versioning
/medications       explicit taken/missed events
/adherence         weekly adherence percentages
/reminders         deterministic reminder queries and processing
/doctor            patient list, pending care plans, and alert queue
/alerts            acknowledgement and resolution
/follow-ups        scheduling and status updates
```

Two production adapters remain intentionally isolated from the core
clinical state machine:

1. Firebase Admin token verification should replace the development
   `X-User-Id`/`X-User-Role` identity adapter.
2. Gemini is called only from the backend. Set `GEMINI_API_KEY` and
   optionally `GEMINI_MODEL` in the local `backend/.env`; never put the key
   in Flutter or commit it. `POST /patients/{patient_id}/care-plans/submit`
   accepts the condition and prescription image, creates a
   `PENDING_REVIEW` draft, and `GET /doctor/care-plans` exposes it to doctor
   clients. The existing approval route is the only way to activate it.
