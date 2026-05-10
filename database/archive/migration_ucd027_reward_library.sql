-- ============================================================================
-- UCD027 – Manage Rewards : Global Reward Library
-- ============================================================================
-- This migration creates the `reward_library` table used by the Admin
-- "Reward Library" feature. Each row defines a single global reward
-- (badge, theme or sticker) that children can earn or purchase.
-- ============================================================================

-- 1. reward_library table ────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS reward_library (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name        TEXT NOT NULL,
    description TEXT,
    category    TEXT NOT NULL CHECK (category IN ('badge', 'theme', 'sticker')),
    point_cost  INTEGER NOT NULL DEFAULT 0 CHECK (point_cost >= 0),
    icon_url       TEXT,          -- Public URL returned after upload
    icon_file_name TEXT,          -- Original filename for display
    icon_file_path TEXT,          -- Storage-bucket path for deletion
    is_active   BOOLEAN NOT NULL DEFAULT TRUE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE reward_library IS
    'Global catalogue of digital rewards (badges, themes, stickers) managed by admins.';

-- Auto-update updated_at
CREATE OR REPLACE FUNCTION update_reward_library_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_reward_library_updated_at
    BEFORE UPDATE ON reward_library
    FOR EACH ROW
    EXECUTE FUNCTION update_reward_library_updated_at();


-- 2. Row-Level Security ─────────────────────────────────────────────────────

ALTER TABLE reward_library ENABLE ROW LEVEL SECURITY;

-- Admin: full CRUD
CREATE POLICY reward_library_admin_all ON reward_library
    FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM profiles
            WHERE profiles.id = auth.uid()
              AND profiles.role = 'admin'
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM profiles
            WHERE profiles.id = auth.uid()
              AND profiles.role = 'admin'
        )
    );

-- Authenticated users (therapists, caregivers, children): read active rewards
CREATE POLICY reward_library_read_active ON reward_library
    FOR SELECT
    USING (is_active = TRUE);


-- 3. Storage bucket for reward icons ────────────────────────────────────────
-- Run this via the Supabase Dashboard → Storage → New bucket, or use the
-- management API. The bucket name must match the service constant.
--
-- Bucket: reward_icons
--   • Public: true  (icons are served to all authenticated users)
--   • Allowed MIME types: image/png, image/jpeg, image/svg+xml
--   • Max file size: 5 MB
--
-- Bucket policies (via Dashboard or SQL):

-- Allow admins to upload / replace / delete icons
-- INSERT (upload)
CREATE POLICY reward_icons_admin_insert ON storage.objects
    FOR INSERT
    WITH CHECK (
        bucket_id = 'reward_icons'
        AND EXISTS (
            SELECT 1 FROM profiles
            WHERE profiles.id = auth.uid()
              AND profiles.role = 'admin'
        )
    );

-- UPDATE (replace)
CREATE POLICY reward_icons_admin_update ON storage.objects
    FOR UPDATE
    USING (
        bucket_id = 'reward_icons'
        AND EXISTS (
            SELECT 1 FROM profiles
            WHERE profiles.id = auth.uid()
              AND profiles.role = 'admin'
        )
    )
    WITH CHECK (
        bucket_id = 'reward_icons'
        AND EXISTS (
            SELECT 1 FROM profiles
            WHERE profiles.id = auth.uid()
              AND profiles.role = 'admin'
        )
    );

-- DELETE (cleanup)
CREATE POLICY reward_icons_admin_delete ON storage.objects
    FOR DELETE
    USING (
        bucket_id = 'reward_icons'
        AND EXISTS (
            SELECT 1 FROM profiles
            WHERE profiles.id = auth.uid()
              AND profiles.role = 'admin'
        )
    );

-- Allow any authenticated user to read icons
CREATE POLICY reward_icons_public_read ON storage.objects
    FOR SELECT
    USING (bucket_id = 'reward_icons');


-- 4. Indexes ────────────────────────────────────────────────────────────────

CREATE INDEX idx_reward_library_category  ON reward_library (category);
CREATE INDEX idx_reward_library_is_active ON reward_library (is_active);


-- ============================================================================
-- END UCD027 migration
-- ============================================================================
