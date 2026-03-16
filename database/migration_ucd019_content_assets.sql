-- ============================================================================
-- UCD019 – Content Library: content_assets table & storage bucket
-- ============================================================================
-- Run this migration AFTER the base schema (supabase_schema.sql).
-- ============================================================================

-- 1. Content assets table ────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS content_assets (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  title         TEXT NOT NULL,
  description   TEXT,
  category      TEXT NOT NULL CHECK (category IN (
                  'reward_icon', 'activity_image', 'story_template', 'other'
                )),
  file_url      TEXT NOT NULL,
  file_name     TEXT NOT NULL,
  file_path     TEXT NOT NULL,           -- storage path inside bucket
  mime_type     TEXT NOT NULL DEFAULT 'application/octet-stream',
  file_size_bytes INTEGER NOT NULL DEFAULT 0,
  tag           TEXT,
  is_active     BOOLEAN NOT NULL DEFAULT TRUE,
  created_at    TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_content_assets_category
  ON content_assets(category);
CREATE INDEX IF NOT EXISTS idx_content_assets_is_active
  ON content_assets(is_active);
CREATE INDEX IF NOT EXISTS idx_content_assets_tag
  ON content_assets(tag);

-- 2. Row Level Security ─────────────────────────────────────────────────────

ALTER TABLE content_assets ENABLE ROW LEVEL SECURITY;

-- Anyone authenticated can view active assets (children, caregivers, etc.)
CREATE POLICY "Anyone can view active content assets"
  ON content_assets FOR SELECT
  USING (is_active = TRUE);

-- Only admins can insert / update / delete
CREATE POLICY "Admins can manage content assets"
  ON content_assets FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.user_id = auth.uid()
        AND profiles.role = 'admin'
    )
  );

-- 3. Updated_at trigger ─────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION update_content_assets_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_content_assets_updated_at
  BEFORE UPDATE ON content_assets
  FOR EACH ROW
  EXECUTE FUNCTION update_content_assets_updated_at();

-- 4. Storage bucket ─────────────────────────────────────────────────────────
-- Uncomment and run in Supabase Dashboard or via SQL editor:

-- INSERT INTO storage.buckets (id, name, public)
-- VALUES ('content_assets', 'content_assets', true)
-- ON CONFLICT (id) DO NOTHING;

-- Storage policies (allow admin uploads, public reads):

-- CREATE POLICY "Public read access on content_assets bucket"
--   ON storage.objects FOR SELECT
--   USING (bucket_id = 'content_assets');

-- CREATE POLICY "Admins can upload to content_assets bucket"
--   ON storage.objects FOR INSERT
--   WITH CHECK (
--     bucket_id = 'content_assets'
--     AND EXISTS (
--       SELECT 1 FROM profiles
--       WHERE profiles.user_id = auth.uid()
--         AND profiles.role = 'admin'
--     )
--   );

-- CREATE POLICY "Admins can delete from content_assets bucket"
--   ON storage.objects FOR DELETE
--   USING (
--     bucket_id = 'content_assets'
--     AND EXISTS (
--       SELECT 1 FROM profiles
--       WHERE profiles.user_id = auth.uid()
--         AND profiles.role = 'admin'
--     )
--   );

-- ============================================================================
-- DONE! 🎉
-- The content_assets table and storage bucket are ready for UCD019.
-- ============================================================================
