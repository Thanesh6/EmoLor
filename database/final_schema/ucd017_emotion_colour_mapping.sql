-- ============================================
-- UCD017: Customize Emotion-Colour Mapping
-- Migration: Adds upsert function and RLS policy
--            for the existing emotion_colors table.
-- ============================================

-- The emotion_colors table already exists in the base schema.
-- This migration adds a convenience upsert function so the
-- Flutter client can save a full set of mappings in one call,
-- and ensures appropriate RLS policies are in place.

-- 1. Upsert function: insert-or-update a single mapping
-- ─────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION upsert_emotion_color(
  p_child_profile_id UUID,
  p_emotion_name TEXT,
  p_color_hex TEXT,
  p_icon TEXT DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  INSERT INTO emotion_colors (child_profile_id, emotion_name, color_hex, icon, updated_at)
  VALUES (p_child_profile_id, p_emotion_name, p_color_hex, p_icon, NOW())
  ON CONFLICT (child_profile_id, emotion_name)
  DO UPDATE SET
    color_hex  = EXCLUDED.color_hex,
    icon       = EXCLUDED.icon,
    updated_at = NOW();
END;
$$;

-- 2. Batch reset: delete custom mappings so defaults apply
-- ─────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION reset_emotion_colors(p_child_profile_id UUID)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  DELETE FROM emotion_colors
  WHERE child_profile_id = p_child_profile_id;
END;
$$;

-- 3. RLS policies (idempotent — re-create if missing)
-- ─────────────────────────────────────────────────────
DO $$
BEGIN
  -- Allow authenticated users to read their own mappings
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'emotion_colors'
      AND policyname = 'Users can view own emotion colors'
  ) THEN
    EXECUTE $pol$
      CREATE POLICY "Users can view own emotion colors"
        ON emotion_colors FOR SELECT
        USING (
          child_profile_id IN (
            SELECT id FROM child_profiles WHERE user_id = auth.uid()
          )
        );
    $pol$;
  END IF;

  -- Allow authenticated users to insert/update their own mappings
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'emotion_colors'
      AND policyname = 'Users can upsert own emotion colors'
  ) THEN
    EXECUTE $pol$
      CREATE POLICY "Users can upsert own emotion colors"
        ON emotion_colors FOR ALL
        USING (
          child_profile_id IN (
            SELECT id FROM child_profiles WHERE user_id = auth.uid()
          )
        )
        WITH CHECK (
          child_profile_id IN (
            SELECT id FROM child_profiles WHERE user_id = auth.uid()
          )
        );
    $pol$;
  END IF;
END
$$;
