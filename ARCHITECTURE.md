# Architecture — CareSync Doctor Website

## 1. High-level architecture

```text
React + TypeScript Doctor Portal
              |
        Supabase Auth
              |
       PostgreSQL + RLS
              |
      Private document storage

Flutter Patient App -> same Supabase Auth, PostgreSQL, RLS, and private Storage
```

The doctor portal connects directly to Supabase. The Flutter patient application's API and authorization setup are separate and must not be assumed to share the portal's security boundary.

## 2. Frontend

- React, TypeScript, Vite, React Router
- Supabase JavaScript client
- Supabase Auth email/password sessions; no public sign-up
- Supabase PostgreSQL and private Storage bucket

## 3. Data operations

```text
Supabase Auth signInWithPassword / signOut
SELECT  patients, care_plans, alerts (filtered by RLS)
INSERT  patients (doctor_id must match auth.uid())
RPC     create_care_plan_draft
RPC     act_on_care_plan
RPC     acknowledge_alert
STORAGE care-plan-documents (private, assigned-patient paths)
```

Doctors need an active `doctor` row in `public.profiles`; hospital administrators invite accounts and provision profiles outside this portal. The browser uses only the Supabase anon/publishable key. Never expose a service-role key or other privileged secret in frontend code.

## 4. Database and authorization

The original schema and policies are defined in [`database/migrations/20260716000000_initial.sql`](./database/migrations/20260716000000_initial.sql). Additive appointment, queue, consultation, prescription, lab-report, vital, allergy, history, follow-up, and notification tables are defined in [`database/migrations/20261008000000_clinical_workflows.sql`](./database/migrations/20261008000000_clinical_workflows.sql). See [`database/README.md`](./database/README.md) for the full relationship map.

- RLS scopes patient, care-plan, alert, profile, and audit access to the authenticated doctor.
- Care plans can only be created and transitioned through database functions that verify patient ownership and write audit events.
- Approving a plan atomically supersedes the prior active version and preserves its history.
- Care-plan source files are stored in a private bucket, with access restricted to the assigned doctor and short-lived signed read URLs.
- Patient details and clinical workflow transitions are audited.

## 5. Care-plan versioning

```text
Patient
  |
  +-- Care Plan V1 -> SUPERSEDED
  |
  +-- Care Plan V2 -> ACTIVE
  |
  +-- Care Plan V3 -> future
```

Drafts remain pending until a doctor verifies the entered information against the uploaded source and approves the plan. The portal does not implement AI/OCR extraction or make clinical decisions.

## 6. Operational boundary

Direct browser-to-Supabase access is limited to operations protected by the supplied RLS policies. Transactional workflows not covered by the existing RPCs, AI/OCR integrations, and notification delivery need authenticated server-side orchestration and explicit authorization design. Patient updates use the additive patient integration migration and remain RLS-scoped. Production use requires security, privacy, compliance, region, backup, logging, retention, and organizational review. See [`docs/architecture.md`](./docs/architecture.md).
