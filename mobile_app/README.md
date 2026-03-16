# EmoLor Flutter App

Flutter application for EmoLor - Emotional Learning Platform

## Setup Instructions

### 1. Prerequisites
- Flutter SDK (3.35.6+)
- Dart SDK (3.9.2+)
- Supabase account with database configured

### 2. Environment Setup

Copy the `.env.example` file to `.env` and add your Supabase credentials:

```bash
cp .env.example .env
```

Then update the values in `.env`:
```
SUPABASE_URL=your_supabase_url
SUPABASE_ANON_KEY=your_supabase_anon_key
```

### 3. Install Dependencies

```bash
flutter pub get
```

### 4. Run the App

For web:
```bash
flutter run -d chrome
```

For Android:
```bash
flutter run -d android
```

For iOS:
```bash
flutter run -d ios
```

## Project Structure

```
lib/
├── main.dart                 # App entry point
├── core/
│   ├── constants/           # App constants
│   ├── theme/              # Theme configuration
│   └── services/           # Core services (Supabase, Auth)
├── features/
│   ├── auth/               # Authentication screens
│   ├── child/              # Child dashboard
│   ├── caregiver/          # Caregiver dashboard
│   ├── therapist/          # Therapist dashboard
│   └── admin/              # Admin dashboard
├── shared/
│   ├── widgets/            # Reusable widgets
│   └── models/             # Data models
└── l10n/                   # Localization files
```

## Features

- ✅ Multi-language support (EN, MS, TA, ZH)
- ✅ Role-based authentication (Child, Caregiver, Therapist, Admin)
- ✅ Responsive design for tablet and web
- ✅ Real-time data sync with Supabase
- ✅ Offline support
