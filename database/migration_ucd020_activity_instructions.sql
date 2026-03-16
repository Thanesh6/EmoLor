-- ============================================================================
-- UCD020 – Define Activity Instructions
-- ============================================================================
-- Adds instruction_text and instruction_image_url columns to the
-- existing `activities` table so admins can define guidance text
-- and a visual demonstration for each learning activity.
-- ============================================================================

-- 1. Add columns ─────────────────────────────────────────────────────────────

ALTER TABLE activities
  ADD COLUMN IF NOT EXISTS instruction_text TEXT,
  ADD COLUMN IF NOT EXISTS instruction_image_url TEXT;

-- 2. Comment for clarity ─────────────────────────────────────────────────────

COMMENT ON COLUMN activities.instruction_text IS
  'Admin-defined guidance text shown to children before starting the activity';

COMMENT ON COLUMN activities.instruction_image_url IS
  'Public URL of a visual demonstration image uploaded by the admin';

-- ============================================================================
-- Storage bucket for instruction images.
-- The `activity_content` bucket was already planned in the base schema
-- (see supabase_schema.sql, commented). Uncomment and run if not yet created:
--
-- INSERT INTO storage.buckets (id, name, public)
-- VALUES ('activity_content', 'activity_content', true)
-- ON CONFLICT (id) DO NOTHING;
--
-- CREATE POLICY "Public read access on activity_content bucket"
--   ON storage.objects FOR SELECT
--   USING (bucket_id = 'activity_content');
--
-- CREATE POLICY "Admins can upload to activity_content bucket"
--   ON storage.objects FOR INSERT
--   WITH CHECK (
--     bucket_id = 'activity_content'
--     AND EXISTS (
--       SELECT 1 FROM profiles
--       WHERE profiles.user_id = auth.uid()
--         AND profiles.role = 'admin'
--     )
--   );
--
-- CREATE POLICY "Admins can delete from activity_content bucket"
--   ON storage.objects FOR DELETE
--   USING (
--     bucket_id = 'activity_content'
--     AND EXISTS (
--       SELECT 1 FROM profiles
--       WHERE profiles.user_id = auth.uid()
--         AND profiles.role = 'admin'
--     )
--   );
-- ============================================================================

-- DONE! 🎉
