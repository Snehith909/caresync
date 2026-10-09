# CareSync Patient App

Flutter patient application for the CareSync post-discharge care
platform. The app uses Flutter and Dart with Material 3 UI. Patient
authentication and clinical data use the shared Supabase project that also
powers the doctor portal.

Run from this directory:

```bash
flutter pub get
flutter run
flutter test
```

## Patient app surfaces

The current MVP includes:

- Daily medication dashboard with morning, afternoon, and night cards.
- Explicit taken/missed medication state presentation.
- Medication adherence progress and weekly history.
- Care-plan creation/update surface with condition entry and processing state.
- Doctor-approval messaging; patients cannot activate a generated plan.
- Follow-up and notification surfaces.
- Voice-safe care-plan question surface.
- CareSync AI Companion with voice transcription, spoken responses,
  multilingual selection, one-tap check-ins, symptom selection, doctor
  requests, and patient-reviewed health summaries.
- Profile, nominee, privacy, and language settings surfaces.
- Provider state in `lib/state/care_sync_state.dart`.
- Dio API boundary in `lib/services/api_client.dart`.

The UI starts with empty patient-owned state. Users can add their own
medication schedule and care-plan condition after signing in. The Dio client
is ready for the FastAPI endpoints. Firebase Authentication,
Firebase Storage, FCM, speech-to-text, and text-to-speech should be wired
through their platform configuration and service adapters before production
use; they should not be simulated as clinical decisions in the UI.

## Supabase configuration

The app reads the public Supabase key from either a local `.env` file or
Dart defines. Never put a service-role/secret key in the app:

```bash
cp .env.example .env
# edit .env with your project URL and anon key
flutter run
```

Or pass values explicitly:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-publishable-key
```

See [`.env.example`](./.env.example) for the variable names. Apply the
doctor repository migrations in order, including
`20261008010000_patient_app_integration.sql`, before signing in. A patient
account receives a patient profile automatically; a doctor must assign that
account to a patient row by setting `patients.patient_user_id`.

## Private Supabase Storage

Patient documents are uploaded to the existing private
`care-plan-documents` bucket under `patients/{patient_id}/...`. The database
registers the path only after RLS verifies that the authenticated patient owns
the assigned record. Doctors can read assigned patient documents; patients
cannot read another patient's files.

The app starts on the Supabase authentication screen. After authentication,
the patient record, active care plan, adherence, condition updates, and
document upload are loaded through `lib/services/` and protected by database
RLS.
