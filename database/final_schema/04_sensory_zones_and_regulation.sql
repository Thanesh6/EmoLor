-- Migration UCD046: Add sensory zone tracking for regulation measurement
-- Adds pre/post zone values, regulation delta, and mismatch flag to child sessions.
-- Existing rows will have NULL values (clean break approach).

-- Step 1: Add zone columns to child_sessions
ALTER TABLE child_sessions
  ADD COLUMN IF NOT EXISTS pre_zone_value   INTEGER DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS post_zone_value  INTEGER DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS regulation_delta INTEGER DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS sensory_mismatch BOOLEAN DEFAULT FALSE;

-- Step 2: Add zone columns to the emotion entries too
-- (so per-entry zone is stored alongside the hex, not just at session level)
ALTER TABLE child_session_emotions
  ADD COLUMN IF NOT EXISTS zone_value INTEGER DEFAULT NULL;

-- Step 3: Add a comment for documentation
COMMENT ON COLUMN child_sessions.pre_zone_value IS
  'Sensory zone of pre-session color pick. Scale: +3 overload, +2 elevated, 0 balanced, -1 low, -2 withdrawal. NULL = pre-migration session.';

COMMENT ON COLUMN child_sessions.post_zone_value IS
  'Sensory zone of post-session color pick. NULL = pre-migration or incomplete session.';

COMMENT ON COLUMN child_sessions.regulation_delta IS
  'pre_zone_value - post_zone_value. Positive = calming effect. NULL = incomplete session.';

COMMENT ON COLUMN child_sessions.sensory_mismatch IS
  'True when emotion word zone and color zone differ by 2 or more. Indicates unique sensory preference.';