-- ============================================================
-- UCD036 – Manage Communication Settings
-- Migration: communication_config table for global messaging
-- and media constraints managed by the Admin.
-- ============================================================

-- ─── Communication Config table ─────────────────────────────
-- Singleton-style key/value store.  Each setting is one row so the
-- admin can update individual fields without touching others.
-- A CHECK on `key` locks the allowed setting names.
CREATE TABLE IF NOT EXISTS communication_config (
    key         TEXT PRIMARY KEY
                CHECK (key IN (
                    'max_attachment_size_mb',
                    'allowed_file_types',
                    'chat_history_retention_days',
                    'max_message_length',
                    'media_upload_enabled',
                    'profanity_filter_enabled'
                )),
    value       JSONB NOT NULL,          -- flexible: number, string, array, bool
    updated_by  UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ─── Seed default values ────────────────────────────────────
INSERT INTO communication_config (key, value) VALUES
    ('max_attachment_size_mb',      '10'::jsonb),
    ('allowed_file_types',          '["jpg","jpeg","png","gif","webp","pdf","doc","docx"]'::jsonb),
    ('chat_history_retention_days', '365'::jsonb),
    ('max_message_length',          '2000'::jsonb),
    ('media_upload_enabled',        'true'::jsonb),
    ('profanity_filter_enabled',    'true'::jsonb)
ON CONFLICT (key) DO NOTHING;

-- ─── Row Level Security ─────────────────────────────────────
ALTER TABLE communication_config ENABLE ROW LEVEL SECURITY;

-- Admin can read + write all settings
CREATE POLICY comm_config_admin_all ON communication_config
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM profiles p
            WHERE p.user_id = auth.uid() AND p.role = 'admin'
        )
    );

-- All authenticated users can read settings (client apps need limits)
CREATE POLICY comm_config_authenticated_select ON communication_config
    FOR SELECT USING (auth.uid() IS NOT NULL);
