-- ╔═══════════════════════════════════════════════════════════════════════╗
-- ║  UCD044 – View Performance Statistics                              ║
-- ║  Extends activity tables with skill-category & performance columns.║
-- ╚═══════════════════════════════════════════════════════════════════════╝

-- ── 1. Add skill_category to activities ─────────────────────────────────
--   Maps every activity to a high-level skill domain so we can group
--   performance across comparable tasks.
ALTER TABLE activities
    ADD COLUMN IF NOT EXISTS skill_category TEXT
        DEFAULT 'General'
        CHECK (skill_category IN (
            'Emotion Recognition',
            'Social Cues',
            'Self-Regulation',
            'Creative Expression',
            'Cognitive Skills',
            'General'
        ));

-- Back-fill existing rows using activity_type as heuristic
UPDATE activities SET skill_category = CASE
    WHEN activity_type = 'game'     THEN 'Emotion Recognition'
    WHEN activity_type = 'exercise' THEN 'Self-Regulation'
    WHEN activity_type = 'story'    THEN 'Social Cues'
    WHEN activity_type = 'art'      THEN 'Creative Expression'
    ELSE 'General'
END
WHERE skill_category IS NULL OR skill_category = 'General';

-- ── 2. Extend activity_progress with per-attempt metrics ────────────────
ALTER TABLE activity_progress
    ADD COLUMN IF NOT EXISTS accuracy_pct    INTEGER DEFAULT 0,  -- 0–100
    ADD COLUMN IF NOT EXISTS response_time_ms INTEGER DEFAULT 0, -- avg ms
    ADD COLUMN IF NOT EXISTS difficulty_level INTEGER DEFAULT 1;  -- 1–5

-- Index for efficient per-category queries
CREATE INDEX IF NOT EXISTS idx_activity_progress_child_completed
    ON activity_progress (child_profile_id, completed_at DESC);
