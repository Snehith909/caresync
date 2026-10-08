# Backend architecture

CareSync's backend is Supabase, not a separate Node/Express server. The hosted Supabase project provides authentication, PostgreSQL, row-level security, private object storage, and the REST API generated from the schema. The database schema and workflow functions live in `../database/migrations`.

This project intentionally does not add a duplicate Express authentication or database layer. Supabase's authenticated PostgREST endpoints are used for table reads and writes; database functions own operations that must be atomic, such as care-plan review. Add authenticated Supabase Edge Functions under `./functions` when a workflow needs server-side orchestration or a configured external provider.

Do not place service-role credentials in the browser. Clinical data access must remain constrained by RLS and doctor ownership. Configure any third-party clinical-data processor only after the organization has approved its privacy, security, and contractual terms.
