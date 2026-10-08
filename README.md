# CareSync Doctor Portal

A React + TypeScript portal for authorized doctors to manage assigned patient records, review versioned care plans, and monitor alerts and follow-ups.

## Run locally

```bash
cd frontend
npm install
npm run dev
```

In Windows PowerShell, run `Set-Location frontend` first, then use `npm.cmd install` and `npm.cmd run dev` if script execution policy blocks `npm`.

## Supabase setup

The portal connects directly to Supabase using the public anon/publishable key. It requires Supabase Auth, PostgreSQL Row Level Security (RLS), and a private document bucket.

1. Create a Supabase project and apply the SQL migrations under [`database/migrations`](./database/migrations) in timestamp order using the Supabase SQL Editor. Using the Supabase CLI requires a project `config.toml`, which is not part of this existing hosted-project setup.
2. In Supabase **Authentication → Users**, invite each doctor. This portal does not provide public registration.
3. Provision each invited user with an active doctor profile. Replace the example email and display name before running:

   ```sql
   insert into public.profiles (user_id, display_name, role, active)
   select id, 'Doctor Name', 'doctor', true
   from auth.users
   where email = 'doctor@hospital.com'
   on conflict (user_id) do update
   set display_name = excluded.display_name, role = 'doctor', active = true;
   ```

4. Copy [`frontend/.env.example`](./frontend/.env.example) to `frontend/.env.local` and set `VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY` from the Supabase project settings. Use only the anon/publishable key in this browser application.
5. In Supabase **Authentication → URL Configuration**, add the local portal origin (for example, `http://127.0.0.1:5174`) to the redirect URL allow list for password-reset emails. Add the deployed portal origin before production use.
6. Restart the Vite development server.

The browser must never contain a Supabase service-role key or another privileged secret. Patient and care-plan access is scoped to the authenticated doctor by RLS. Source documents use private storage and short-lived signed URLs. The migration records audit events for patient creation/updates, care-plan draft/review actions, and alert acknowledgment.

The sign-in screen includes password recovery. Reset links are sent only for existing accounts; if a doctor has not been invited yet, a project administrator must provision the account in Supabase Auth. Public doctor sign-up remains disabled.

## Data workflow

The initial workspace has no patient, alert, or care-plan records. **Add patient** stores a record in Supabase. Reassessment stores clinician-entered notes, medication details, and an uploaded source document as a versioned draft. The doctor must verify the information against the document before approval; the portal does not infer medication details or make clinical decisions. Approval preserves previous versions and marks the prior active version as superseded.

The Flutter patient app uses the same Supabase project. Patient access is
scoped by `patients.patient_user_id` and database RLS; doctor access remains
scoped by the assigned `doctor_id`. Apply the patient integration migration
before enabling the mobile app.

## Technology

- React, TypeScript, Vite, React Router
- Supabase Auth, PostgreSQL with RLS, private Supabase Storage
- See [architecture](./docs/architecture.md), [API](./docs/api.md), and [database](./database/README.md) documentation.

## Project layout

- [`frontend/`](./frontend/) contains the React application and its Vite/TypeScript configuration.
- [`backend/`](./backend/) contains the Supabase Edge Function area and backend notes. Authentication, REST, storage, and most workflow logic are provided by the hosted Supabase project.
- [`database/`](./database/) contains the ordered SQL migrations and schema documentation.

## Clinical safety

This portal is a clinical-support workflow, not an autonomous doctor. It does not diagnose, prescribe, change dosage, or declare recovery. Uploaded information and all care-plan details require doctor verification. Production use requires organization-specific security, privacy, compliance, retention, and operational review.
