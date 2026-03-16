# EmoLor - Gamified Learning for Autistic Children

EmoLor is a cross-platform application designed to help autistic children understand and express emotions through colors and gamification.

## Project Structure

This repository is organized into the following modules:

- **`/mobile_app`**: The main tablet-first application for children, built with **Flutter**.
- **`/web_portal`**: The web dashboard for caregivers, therapists, and admins, built with **React**.
- **`/database`**: Database schemas and migration scripts for **Supabase**.
- **`/docs`**: Project documentation, architecture diagrams, and guides.

## Getting Started

### Mobile App (Flutter)
Navigate to the `mobile_app` directory to work on the Android/Tablet application.
```bash
cd mobile_app
flutter pub get
flutter run
```

### Web Portal (React)
Navigate to the `web_portal` directory to work on the web dashboard.
```bash
cd web_portal
npm install
npm run dev
```

## Documentation
Please refer to the `docs/` folder for detailed guides:
- [Architecture](docs/ARCHITECTURE_REFINEMENT.md)
- [Development Guide](docs/DEVELOPMENT_GUIDE.md)
- [Database Guide](docs/DATABASE_MIGRATION_GUIDE.md)
