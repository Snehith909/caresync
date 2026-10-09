# CareSync architecture

## Frontend

The React 18, TypeScript, Vite, and React Router application lives under `frontend/`, including its `src/`, `public/`, and package configuration. `frontend/src/services/api` is the shared Supabase client boundary; `frontend/src/services/auth` contains authentication operations. Feature-specific components, pages, hooks, layouts, types, and utilities have dedicated locations under `frontend/src/` as the UI is incrementally extracted from the existing application.

The current user experience remains in `frontend/src/App.tsx` and `frontend/src/styles.css`: sign-in and password recovery, doctor overview, patients, care plans, alerts, follow-ups, patient details, reassessment, and settings.

## Backend

Supabase is the existing backend. Supabase Auth authenticates invited doctor accounts, PostgreSQL stores data, RLS enforces doctor-scoped access, Storage holds private source documents, and PostgREST exposes the authorized data API. SQL migrations are additive and live under `database/migrations/`. Database functions are used for workflows requiring transaction-level guarantees.

There is no separate Express process or Prisma layer. Adding one would duplicate the existing identity and authorization boundary. Server-side integrations that cannot safely run in the browser belong in authenticated Supabase Edge Functions and must use environment secrets rather than committed credentials.

## API flow

1. The browser authenticates with Supabase Auth.
2. The browser uses the public anon/publishable key and its user session to call Supabase's REST, Auth, and Storage APIs.
3. PostgreSQL RLS verifies the active doctor and record ownership for every query or mutation.
4. Workflow functions validate state transitions and write audit metadata atomically.
5. Private documents are stored in a non-public bucket and accessed through short-lived signed URLs.

## Authentication flow

Only administrator-invited accounts are supported. The app restores the Supabase session, checks that the associated profile is an active doctor, then renders the workspace. Password recovery uses Supabase Auth. Signing out invalidates the client session. RLS remains the data-access boundary; hiding a route is not authorization.

## Database relationships

Supabase Auth's `auth.users` is the user identity source; `public.profiles` represents the doctor profile. Patients are assigned to doctors. Appointments, queue entries, consultations, vitals, allergies, medical history, lab reports, follow-ups, and notifications reference the assigned patient and doctor. Prescriptions belong to consultations and medications belong to prescriptions. Care-plan versions and alerts use the existing tables. Audit rows contain action/entity metadata only, not clinical field values.

See [database.md](./database.md) for the table map and migration notes.

## AI service flow

AI is not currently wired into the doctor portal. When an approved provider is configured through an authenticated Edge Function, requests should include only the minimum data required, avoid logging prompt or patient content, and return clearly labeled decision support for clinician review. AI output must not be represented as a diagnosis or autonomous treatment decision. No provider credentials or clinical data are sent by the current frontend.

## Local development

Run `npm run dev` or `npm run build` from the `frontend/` directory. Configure the public Supabase URL and anon/publishable key using `frontend/.env.example`. The current backend is the hosted Supabase project, so the Vite command does not start another backend process. Apply SQL migrations in timestamp order in the Supabase SQL Editor; using the CLI locally requires a project `config.toml` and local Supabase services.
