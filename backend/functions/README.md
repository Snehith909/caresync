# Supabase Edge Functions

Place authenticated server-side orchestration here when a workflow cannot safely or atomically use PostgREST and database functions. Verify the caller's Supabase access token, validate request data, and avoid logging patient content.

No AI provider or notification-delivery function is configured in this project. Do not add provider credentials to frontend environment variables; configure server-side secrets only after the provider and clinical-data processing terms have been approved.
