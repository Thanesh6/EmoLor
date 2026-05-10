-- ============================================
-- Migration: Child Sessions + Emotion Updates
-- ============================================

-- 1. child_sessions table — tracks app-usage sessions with pre/post emotions
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS child_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  child_profile_id UUID,
  pre_emotion_name TEXT,
  pre_emotion_valence TEXT CHECK (pre_emotion_valence IN ('positive', 'negative', 'neutral')),
  pre_emotion_colour TEXT,
  post_emotion_name TEXT,
  post_emotion_valence TEXT CHECK (post_emotion_valence IN ('positive', 'negative', 'neutral')),
  post_emotion_colour TEXT,
  session_date TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_child_sessions_profile ON child_sessions(child_profile_id);
CREATE INDEX IF NOT EXISTS idx_child_sessions_date ON child_sessions(session_date DESC);

-- Enable RLS
ALTER TABLE child_sessions ENABLE ROW LEVEL SECURITY;

-- RLS: caregivers can manage sessions for their children
-- (child_profile_id stores the profile_id from profiles table)
CREATE POLICY "Caregivers can manage child sessions"
  ON child_sessions FOR ALL
  USING (
    child_profile_id IN (
      SELECT p.profile_id FROM profiles p
      INNER JOIN family_links fl ON fl.child_id = p.user_id
      WHERE fl.caregiver_id = auth.uid()
    )
  )
  WITH CHECK (
    child_profile_id IN (
      SELECT p.profile_id FROM profiles p
      INNER JOIN family_links fl ON fl.child_id = p.user_id
      WHERE fl.caregiver_id = auth.uid()
    )
  );

-- Therapists can view their clients' sessions
CREATE POLICY "Therapists can view child sessions"
  ON child_sessions FOR SELECT
  USING (
    child_profile_id IN (
      SELECT p.profile_id FROM profiles p
      INNER JOIN family_links fl ON fl.child_id = p.user_id
      WHERE fl.therapist_id = auth.uid()
    )
  );

-- Updated_at trigger
CREATE TRIGGER update_child_sessions_updated_at
  BEFORE UPDATE ON child_sessions
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- 2. Add valence and plutchik_order to emotion_colors
-- ─────────────────────────────────────────────────────
ALTER TABLE emotion_colors
  ADD COLUMN IF NOT EXISTS emotion_valence TEXT,
  ADD COLUMN IF NOT EXISTS plutchik_order INTEGER;

-- 3. Update upsert function to include new columns
-- ─────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION upsert_emotion_color(
  p_child_profile_id UUID,
  p_emotion_name TEXT,
  p_color_hex TEXT,
  p_icon TEXT DEFAULT NULL,
  p_valence TEXT DEFAULT NULL,
  p_plutchik_order INTEGER DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  INSERT INTO emotion_colors (
    child_profile_id, emotion_name, color_hex, icon,
    emotion_valence, plutchik_order, updated_at
  )
  VALUES (
    p_child_profile_id, p_emotion_name, p_color_hex, p_icon,
    p_valence, p_plutchik_order, NOW()
  )
  ON CONFLICT (child_profile_id, emotion_name)
  DO UPDATE SET
    color_hex       = EXCLUDED.color_hex,
    icon            = EXCLUDED.icon,
    emotion_valence = EXCLUDED.emotion_valence,
    plutchik_order  = EXCLUDED.plutchik_order,
    updated_at      = NOW();
END;
$$;

-- 4. Helper RPC: get all sessions for a child (for analytics)
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION get_child_sessions(p_child_profile_id UUID, p_limit INT DEFAULT 30)
RETURNS TABLE (
  id UUID,
  child_profile_id UUID,
  pre_emotion_name TEXT,
  pre_emotion_valence TEXT,
  pre_emotion_colour TEXT,
  post_emotion_name TEXT,
  post_emotion_valence TEXT,
  post_emotion_colour TEXT,
  session_date TIMESTAMP WITH TIME ZONE
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT
    cs.id, cs.child_profile_id,
    cs.pre_emotion_name, cs.pre_emotion_valence, cs.pre_emotion_colour,
    cs.post_emotion_name, cs.post_emotion_valence, cs.post_emotion_colour,
    cs.session_date
  FROM child_sessions cs
  WHERE cs.child_profile_id = p_child_profile_id
  ORDER BY cs.session_date DESC
  LIMIT p_limit;
END;
$$;
