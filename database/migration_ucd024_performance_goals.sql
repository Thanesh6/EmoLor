-- UCD024: Performance Goals
-- Adds a goals table for caregiver-set trackable child goals.

CREATE TABLE IF NOT EXISTS performance_goals (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  child_profile_id UUID REFERENCES child_profiles(id) ON DELETE CASCADE,
  caregiver_id  UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  category      TEXT NOT NULL CHECK (category IN ('time_spent', 'activity_completion', 'mood_logging', 'star_collection')),
  target        INTEGER NOT NULL CHECK (target > 0),
  duration      TEXT NOT NULL CHECK (duration IN ('today', 'this_week', 'this_month')),
  linked_reward TEXT,
  status        TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'completed', 'expired')),
  current_progress INTEGER DEFAULT 0,
  created_at    TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at    TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_goals_caregiver ON performance_goals(caregiver_id);
CREATE INDEX IF NOT EXISTS idx_goals_child     ON performance_goals(child_profile_id);
CREATE INDEX IF NOT EXISTS idx_goals_status    ON performance_goals(status);

-- Auto-update updated_at
CREATE TRIGGER set_performance_goals_updated_at
  BEFORE UPDATE ON performance_goals
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- RLS
ALTER TABLE performance_goals ENABLE ROW LEVEL SECURITY;

-- Caregivers can manage their own goals
CREATE POLICY "Caregivers manage own goals"
  ON performance_goals
  FOR ALL
  USING (auth.uid() = caregiver_id);

-- Therapists can view goals for their assigned children
CREATE POLICY "Therapists view assigned goals"
  ON performance_goals
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM child_profiles cp
      WHERE cp.id = performance_goals.child_profile_id
        AND cp.therapist_id = auth.uid()
    )
  );

-- Admins can view all goals
CREATE POLICY "Admins view all goals"
  ON performance_goals
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM profiles p
      WHERE p.id = auth.uid() AND p.role = 'admin'
    )
  );
