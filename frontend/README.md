# CareSync Patient App

Flutter patient application for the CareSync post-discharge care
platform. The app uses Flutter and Dart with Material 3 UI. Its REST
connection belongs in this project and targets the FastAPI service in
`../backend`.

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
- Profile, nominee, privacy, and language settings surfaces.
- Provider state in `lib/state/care_sync_state.dart`.
- Dio API boundary in `lib/services/api_client.dart`.

The UI starts with empty patient-owned state. Users can add their own
medication schedule and care-plan condition after signing in. The Dio client
is ready for the FastAPI endpoints. Firebase Authentication,
Firebase Storage, FCM, speech-to-text, and text-to-speech should be wired
through their platform configuration and service adapters before production
use; they should not be simulated as clinical decisions in the UI.

## Cloudinary image storage

Patient prescription and condition images are uploaded by the backend to
Cloudinary. Keep the Cloudinary API secret on the backend only; never add it
to Flutter code or commit it to Git. Copy `.env.example` to `.env` in the
`backend` directory and set:

```text
CLOUDINARY_URL=cloudinary://<api_key>:<api_secret>@<cloud_name>
```

The backend exposes `POST /patients/{patient_id}/condition-image` for JPG and
PNG condition images and returns the Cloudinary secure URL. The Flutter API
client method is `uploadConditionImage`.

## Firebase Authentication setup

The Android Firebase configuration is supplied locally as
`android/app/google-services.json` and is intentionally ignored by Git.
The configured Firebase Android package is `caresync.com`.

In the Firebase Console:

1. Open the `caresync-5134b` project.
2. Go to **Project settings > Your apps > Android app (`caresync.com`)**.
3. Add these fingerprints for local debug builds:

   ```text
   SHA-1:   B9:82:15:82:95:34:CE:D5:37:9C:3A:74:B1:27:CC:F3:1B:19:A9:D3
   SHA-256: 61:AC:DC:A9:3C:C1:8F:37:84:DB:31:44:FB:69:68:5F:E7:DD:B7:3E:5C:7A:DD:57:7F:A4:19:AA:8E:BC:2A:39
   ```

4. Download the updated `google-services.json` and replace
   `android/app/google-services.json`.
5. Go to **Authentication > Sign-in method** and enable **Email/Password**.
6. Uninstall the old app and run:

   ```bash
   flutter clean
   flutter pub get
   flutter run
   ```

The app starts on the authentication screen. After successful
authentication, it shows the patient dashboard. The authentication
implementation is in `lib/auth/`; `AuthGateway` keeps the UI testable and
separates authentication from patient-care state.
