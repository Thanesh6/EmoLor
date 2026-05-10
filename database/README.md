# EMOLOR Database

This folder contains SQL documentation and migration history for the EMOLOR Supabase backend.

## Folder Structure

```text
database/
├── final_schema/   # Final reference schema for the current EMOLOR app
├── archive/        # Historical migrations and removed-scope features
└── README.md       # Database documentation guide

## Final Schema vs Historical Migrations

The `final_schema/` folder documents the database objects required by the final EMOLOR application.

The `archive/` folder contains historical SQL migrations and removed-scope features from earlier development phases, including admin, therapist, chat, messaging, and older analytics modules. These files are retained for project history and traceability but are not required for the final Android tablet application.

The live Supabase project may still contain some legacy tables from earlier iterations. These tables are not accessed by the final Flutter app and are kept to avoid unnecessary risk before final demonstration. The final app depends only on the tables and RPC functions listed in `final_schema/` and this README.

## Current Active Database Scope

The final EMOLOR app directly accesses the following Supabase tables:

- `profiles`
- `family_links`
- `activities`

The app also uses RPC functions that internally operate on additional tables such as:

- `emotion_colors`
- `child_sessions`

The app depends on the following RPC functions:

- `get_user_role`
- `create_profile`
- `get_child_profiles`
- `create_child_profile`
- `delete_child_profile`
- `upsert_emotion_color`
- `upsert_child_session`
- `get_child_sessions`
- `get_child_profile_by_name`

No active Flutter code currently uses Supabase Storage directly.