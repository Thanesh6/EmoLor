# EMOLOR

EMOLOR is a Flutter-based Android tablet application designed to support emotional learning for children through emotion selection, colour association, gamified activities, caregiver analytics, AI-generated weekly insights, and PDF reporting.

## Final Project Scope

The final EMOLOR application focuses on:

- Organisation or centre account registration and login
- Child profile creation and selection
- Session goal setup before each child session
- Pre-session emotion and colour selection
- Child-friendly games and activities
- Post-session emotion and colour selection
- Weekly analytics dashboard
- AI-generated caregiver insight summary
- Weekly PDF report generation

The final version does not include admin, therapist, chat, messaging, or web portal modules.

## Main Application Flow

Login/Register
→ Child Profile Selection
→ Set Goals
→ Pre-Session Emotion + Colour
→ Child Dashboard
→ Games / Activities
→ Post-Session Emotion + Colour
→ Analytics Dashboard
→ AI Summary / PDF Report

## Technology Stack

- Flutter / Dart
- Supabase
- GoRouter
- SharedPreferences
- Anthropic Claude API for AI summary generation
- PDF generation and sharing packages

## Getting Started

**Target platform:** Android tablet only (the app is not built for web, iOS, or desktop).

**Prerequisites:**

- Flutter SDK with Dart `>=3.0.0 <4.0.0` (Flutter 3.x channel)
- An Android tablet or emulator (Android 14 / API 34 used for testing)

**Install dependencies:**

```bash
cd mobile_app
flutter pub get
```

**Run on a connected Android device:**

Secrets are never committed — they are supplied at run time via `--dart-define`:

```bash
flutter run -d <android-device-id> \
  --dart-define=SUPABASE_URL=https://<project>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<supabase-anon-key> \
  --dart-define=ANTHROPIC_API_KEY=<anthropic-api-key>
```

- `SUPABASE_URL` / `SUPABASE_ANON_KEY` — required for backend, auth, and data.
- `ANTHROPIC_API_KEY` — required only for the AI weekly insight summary.

**Build a release APK** (pass the same `--dart-define` values):

```bash
flutter build apk --release \
  --dart-define=SUPABASE_URL=... \
  --dart-define=SUPABASE_ANON_KEY=... \
  --dart-define=ANTHROPIC_API_KEY=...
```

## Architecture Overview

- **Frontend:** Flutter / Dart, Riverpod (state management), GoRouter (navigation).
- **Backend:** Supabase — PostgreSQL, Auth, and RPC functions with Row-Level Security.
- **AI:** Anthropic Claude API, called for the weekly caregiver insight summary.
- **Reports:** On-device PDF generation and sharing.
- **Storage:** Local-first via SharedPreferences, synced to Supabase.