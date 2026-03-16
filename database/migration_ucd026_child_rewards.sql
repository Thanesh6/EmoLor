-- =====================================================================
-- UCD026 – View My Rewards (child_reward_inventory)
-- Run AFTER the initial schema & UCD024 migration.
-- =====================================================================

-- Tracks which rewards each child has unlocked and which is equipped.
CREATE TABLE IF NOT EXISTS child_reward_inventory (
    id            UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    child_profile_id UUID NOT NULL REFERENCES child_profiles(id) ON DELETE CASCADE,
    reward_id     TEXT        NOT NULL,          -- maps to catalogue id (e.g. 'first_steps', 'space_theme')
    reward_type   TEXT        NOT NULL DEFAULT 'badge',  -- badge | treasure | theme
    unlocked_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    is_equipped   BOOLEAN     NOT NULL DEFAULT false,
    metadata      JSONB       DEFAULT '{}',     -- future extensibility
    UNIQUE(child_profile_id, reward_id)
);

-- Index for fast lookups
CREATE INDEX IF NOT EXISTS idx_cri_child ON child_reward_inventory(child_profile_id);

-- ── RLS ──────────────────────────────────────────────────────────────
ALTER TABLE child_reward_inventory ENABLE ROW LEVEL SECURITY;

-- Caregivers can view their children's rewards
CREATE POLICY cri_select_caregiver ON child_reward_inventory
    FOR SELECT USING (
        child_profile_id IN (
            SELECT id FROM child_profiles
            WHERE caregiver_id = auth.uid()
        )
    );

-- Therapists can view assigned children's rewards
CREATE POLICY cri_select_therapist ON child_reward_inventory
    FOR SELECT USING (
        child_profile_id IN (
            SELECT id FROM child_profiles
            WHERE therapist_id = auth.uid()
        )
    );

-- Children can view and manage their own rewards (via caregiver session)
CREATE POLICY cri_manage_own ON child_reward_inventory
    FOR ALL USING (
        child_profile_id IN (
            SELECT id FROM child_profiles
            WHERE caregiver_id = auth.uid()
        )
    );

-- Admins full access
CREATE POLICY cri_admin_all ON child_reward_inventory
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM profiles
            WHERE user_id = auth.uid() AND role = 'admin'
        )
    );
