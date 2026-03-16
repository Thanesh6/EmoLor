-- ============================================================================
-- UCD021 – Define Completion Feedback
-- ============================================================================
-- Adds per-activity feedback configuration columns to the `activities`
-- table so admins can customise the positive reinforcement shown when
-- a child completes an activity.
-- ============================================================================

-- 1. Add columns ─────────────────────────────────────────────────────────────

ALTER TABLE activities
  ADD COLUMN IF NOT EXISTS feedback_text        TEXT,
  ADD COLUMN IF NOT EXISTS feedback_animation   TEXT
        CHECK (feedback_animation IN ('confetti', 'star_burst', 'balloons')),
  ADD COLUMN IF NOT EXISTS feedback_sound       TEXT
        CHECK (feedback_sound IN ('applause', 'chime', 'fanfare'));

-- 2. Comments ────────────────────────────────────────────────────────────────

COMMENT ON COLUMN activities.feedback_text IS
  'Admin-defined congratulatory text shown on activity completion';

COMMENT ON COLUMN activities.feedback_animation IS
  'Visual animation style: confetti | star_burst | balloons';

COMMENT ON COLUMN activities.feedback_sound IS
  'Sound effect played on completion: applause | chime | fanfare';

-- ============================================================================
-- DONE! 🎉
