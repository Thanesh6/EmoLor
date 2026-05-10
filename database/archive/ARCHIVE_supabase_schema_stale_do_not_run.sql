-- EmoLor Database Schema for Supabase
-- Run these SQL commands in your Supabase SQL Editor
-- UPDATED: Unified child-caregiver interface with separate therapist access

-- ============================================
-- 1. PROFILES TABLE (extends auth.users)
-- ============================================
-- NOTE: Only caregivers, therapists, and admins have auth accounts
-- Children do NOT have separate auth accounts - they use profiles under caregiver accounts
CREATE TABLE IF NOT EXISTS profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT UNIQUE NOT NULL,
  name TEXT NOT NULL,
  role TEXT NOT NULL CHECK (role IN ('caregiver', 'therapist', 'admin')),
  avatar_url TEXT,
  phone TEXT,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create index for faster role lookups
CREATE INDEX IF NOT EXISTS idx_profiles_role ON profiles(role);
CREATE INDEX IF NOT EXISTS idx_profiles_email ON profiles(email);

-- ============================================
-- 2. CHILD PROFILES TABLE
-- ============================================
-- Children are profiles under a caregiver account, not separate users
-- Multiple child profiles can belong to one caregiver
CREATE TABLE IF NOT EXISTS child_profiles (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  caregiver_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  therapist_id UUID REFERENCES users(id),
  name TEXT NOT NULL,
  age INTEGER CHECK (age >= 0 AND age <= 18),
  date_of_birth DATE,
  avatar_url TEXT,
  preferences JSONB DEFAULT '{}', -- Store color preferences, themes, etc.
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_child_profiles_caregiver_id ON child_profiles(caregiver_id);
CREATE INDEX IF NOT EXISTS idx_child_profiles_therapist_id ON child_profiles(therapist_id);
CREATE INDEX IF NOT EXISTS idx_child_profiles_active ON child_profiles(is_active);

-- ============================================
-- 3. EMOTION COLORS TABLE (Personalization)
-- ============================================
CREATE TABLE IF NOT EXISTS emotion_colors (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  child_profile_id UUID REFERENCES child_profiles(id) ON DELETE CASCADE,
  emotion_name TEXT NOT NULL,
  color_hex TEXT NOT NULL,
  icon TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(child_profile_id, emotion_name)
);

CREATE INDEX IF NOT EXISTS idx_emotion_colors_child_profile_id ON emotion_colors(child_profile_id);

-- ============================================
-- 4. EMOTION ENTRIES TABLE (Daily Tracking)
-- ============================================
CREATE TABLE IF NOT EXISTS emotion_entries (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  child_profile_id UUID REFERENCES child_profiles(id) ON DELETE CASCADE,
  emotion_name TEXT NOT NULL,
  intensity INTEGER CHECK (intensity >= 1 AND intensity <= 5),
  notes TEXT,
  trigger TEXT,
  location TEXT,
  timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_emotion_entries_child_profile_id ON emotion_entries(child_profile_id);
CREATE INDEX IF NOT EXISTS idx_emotion_entries_timestamp ON emotion_entries(timestamp DESC);

-- ============================================
-- 5. SESSIONS TABLE (Therapy Sessions)
-- ============================================
CREATE TABLE IF NOT EXISTS sessions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  therapist_id UUID REFERENCES users(id) ON DELETE CASCADE,
  child_profile_id UUID REFERENCES child_profiles(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  notes TEXT,
  goals TEXT[],
  status TEXT CHECK (status IN ('scheduled', 'completed', 'cancelled')) DEFAULT 'scheduled',
  session_date TIMESTAMP WITH TIME ZONE NOT NULL,
  duration_minutes INTEGER DEFAULT 60,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_sessions_therapist_id ON sessions(therapist_id);
CREATE INDEX IF NOT EXISTS idx_sessions_child_profile_id ON sessions(child_profile_id);
CREATE INDEX IF NOT EXISTS idx_sessions_date ON sessions(session_date DESC);

-- ============================================
-- 6. ACTIVITIES TABLE (Games & Exercises)
-- ============================================
CREATE TABLE IF NOT EXISTS activities (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  title TEXT NOT NULL,
  description TEXT,
  activity_type TEXT CHECK (activity_type IN ('game', 'exercise', 'story', 'art')),
  age_range_min INTEGER,
  age_range_max INTEGER,
  duration_minutes INTEGER,
  difficulty TEXT CHECK (difficulty IN ('easy', 'medium', 'hard')),
  thumbnail_url TEXT,
  content_data JSONB,
  is_active BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_activities_type ON activities(activity_type);
CREATE INDEX IF NOT EXISTS idx_activities_active ON activities(is_active);

-- ============================================
-- 7. ACTIVITY PROGRESS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS activity_progress (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  child_profile_id UUID REFERENCES child_profiles(id) ON DELETE CASCADE,
  activity_id UUID REFERENCES activities(id) ON DELETE CASCADE,
  status TEXT CHECK (status IN ('started', 'in_progress', 'completed')) DEFAULT 'started',
  score INTEGER,
  completion_percentage INTEGER DEFAULT 0,
  time_spent_seconds INTEGER DEFAULT 0, -- Track in seconds for accuracy
  stars_earned INTEGER DEFAULT 0, -- 1-3 stars based on performance
  completed_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(child_profile_id, activity_id) -- One progress record per child per activity
);

CREATE INDEX IF NOT EXISTS idx_activity_progress_child_profile_id ON activity_progress(child_profile_id);
CREATE INDEX IF NOT EXISTS idx_activity_progress_activity_id ON activity_progress(activity_id);
CREATE INDEX IF NOT EXISTS idx_activity_progress_activity_id ON activity_progress(activity_id);
CREATE INDEX IF NOT EXISTS idx_activity_progress_status ON activity_progress(status);

-- ============================================
-- 8. REWARDS TABLE
-- ============================================
-- Track rewards earned by children (both completion and time-based)
CREATE TABLE IF NOT EXISTS rewards (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  child_profile_id UUID REFERENCES child_profiles(id) ON DELETE CASCADE,
  reward_type TEXT CHECK (reward_type IN ('completion', 'time_milestone', 'streak', 'achievement', 'special')) NOT NULL,
  title TEXT NOT NULL,
  description TEXT,
  icon TEXT,
  points INTEGER DEFAULT 0,
  badge_url TEXT,
  metadata JSONB DEFAULT '{}', -- Store activity_id, streak_count, etc.
  earned_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_rewards_child_profile_id ON rewards(child_profile_id);
CREATE INDEX IF NOT EXISTS idx_rewards_type ON rewards(reward_type);
CREATE INDEX IF NOT EXISTS idx_rewards_earned_at ON rewards(earned_at DESC);

-- ============================================
-- 9. INSIGHTS TABLE (AI-Generated Insights)
-- ============================================
CREATE TABLE IF NOT EXISTS insights (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  child_profile_id UUID REFERENCES child_profiles(id) ON DELETE CASCADE,
  insight_type TEXT CHECK (insight_type IN ('pattern', 'suggestion', 'achievement', 'concern')),
  title TEXT NOT NULL,
  description TEXT NOT NULL,
  confidence_score DECIMAL(3,2),
  is_read BOOLEAN DEFAULT FALSE,
  is_dismissed BOOLEAN DEFAULT FALSE,
  metadata JSONB,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_insights_child_profile_id ON insights(child_profile_id);
CREATE INDEX IF NOT EXISTS idx_insights_read ON insights(is_read, is_dismissed);

-- ============================================
-- 10. NOTIFICATIONS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS notifications (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  child_profile_id UUID REFERENCES child_profiles(id) ON DELETE SET NULL, -- Optional: specific child context
  title TEXT NOT NULL,
  message TEXT NOT NULL,
  type TEXT CHECK (type IN ('info', 'success', 'warning', 'alert')),
  is_read BOOLEAN DEFAULT FALSE,
  action_url TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_child_profile_id ON notifications(child_profile_id);
CREATE INDEX IF NOT EXISTS idx_notifications_read ON notifications(is_read);

-- ============================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- ============================================

-- Enable RLS on all tables
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE child_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE emotion_colors ENABLE ROW LEVEL SECURITY;
ALTER TABLE emotion_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE activities ENABLE ROW LEVEL SECURITY;
ALTER TABLE activity_progress ENABLE ROW LEVEL SECURITY;
ALTER TABLE rewards ENABLE ROW LEVEL SECURITY;
ALTER TABLE insights ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- USERS TABLE POLICIES
CREATE POLICY "Users can view own profile" ON users
  FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can update own profile" ON users
  FOR UPDATE USING (auth.uid() = id);

-- CHILD PROFILES TABLE POLICIES
-- Caregivers can manage their own children's profiles
CREATE POLICY "Caregivers can view their child profiles" ON child_profiles
  FOR SELECT USING (auth.uid() = caregiver_id);

CREATE POLICY "Caregivers can insert their child profiles" ON child_profiles
  FOR INSERT WITH CHECK (auth.uid() = caregiver_id);

CREATE POLICY "Caregivers can update their child profiles" ON child_profiles
  FOR UPDATE USING (auth.uid() = caregiver_id);

CREATE POLICY "Caregivers can delete their child profiles" ON child_profiles
  FOR DELETE USING (auth.uid() = caregiver_id);

-- Therapists can view assigned children
CREATE POLICY "Therapists can view assigned child profiles" ON child_profiles
  FOR SELECT USING (auth.uid() = therapist_id);

-- Admins can view all children
CREATE POLICY "Admins can view all child profiles" ON child_profiles
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM users WHERE users.id = auth.uid() AND users.role = 'admin')
  );

-- EMOTION ENTRIES POLICIES
CREATE POLICY "Caregivers can insert emotions for their children" ON emotion_entries
  FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM child_profiles WHERE child_profiles.id = child_profile_id AND child_profiles.caregiver_id = auth.uid())
  );

CREATE POLICY "Caregivers can view their children's emotions" ON emotion_entries
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM child_profiles WHERE child_profiles.id = child_profile_id AND child_profiles.caregiver_id = auth.uid())
  );

CREATE POLICY "Therapists can view assigned children's emotions" ON emotion_entries
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM child_profiles WHERE child_profiles.id = child_profile_id AND child_profiles.therapist_id = auth.uid())
  );

CREATE POLICY "Admins can view all emotions" ON emotion_entries
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM users WHERE users.id = auth.uid() AND users.role = 'admin')
  );

-- SESSIONS POLICIES
CREATE POLICY "Therapists can manage own sessions" ON sessions
  FOR ALL USING (auth.uid() = therapist_id);

CREATE POLICY "Caregivers can view their children's sessions" ON sessions
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM child_profiles WHERE child_profiles.id = child_profile_id AND child_profiles.caregiver_id = auth.uid())
  );

CREATE POLICY "Admins can view all sessions" ON sessions
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM users WHERE users.id = auth.uid() AND users.role = 'admin')
  );

-- ACTIVITY PROGRESS POLICIES
CREATE POLICY "Caregivers can manage their children's progress" ON activity_progress
  FOR ALL USING (
    EXISTS (SELECT 1 FROM child_profiles WHERE child_profiles.id = child_profile_id AND child_profiles.caregiver_id = auth.uid())
  );

CREATE POLICY "Therapists can view assigned children's progress" ON activity_progress
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM child_profiles WHERE child_profiles.id = child_profile_id AND child_profiles.therapist_id = auth.uid())
  );

CREATE POLICY "Admins can view all progress" ON activity_progress
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM users WHERE users.id = auth.uid() AND users.role = 'admin')
  );

-- REWARDS POLICIES
CREATE POLICY "Caregivers can view their children's rewards" ON rewards
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM child_profiles WHERE child_profiles.id = child_profile_id AND child_profiles.caregiver_id = auth.uid())
  );

CREATE POLICY "System can insert rewards" ON rewards
  FOR INSERT WITH CHECK (true); -- Inserted by system/app logic

CREATE POLICY "Therapists can view assigned children's rewards" ON rewards
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM child_profiles WHERE child_profiles.id = child_profile_id AND child_profiles.therapist_id = auth.uid())
  );

-- ACTIVITIES POLICIES (Public Read)
CREATE POLICY "Anyone can view active activities" ON activities
  FOR SELECT USING (is_active = TRUE);

CREATE POLICY "Admins can manage activities" ON activities
  FOR ALL USING (
    EXISTS (SELECT 1 FROM users WHERE users.id = auth.uid() AND users.role = 'admin')
  );

-- NOTIFICATIONS POLICIES
CREATE POLICY "Users can view own notifications" ON notifications
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can update own notifications" ON notifications
  FOR UPDATE USING (auth.uid() = user_id);

-- ============================================
-- TRIGGERS FOR UPDATED_AT
-- ============================================

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_child_profiles_updated_at BEFORE UPDATE ON child_profiles
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_emotion_colors_updated_at BEFORE UPDATE ON emotion_colors
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_sessions_updated_at BEFORE UPDATE ON sessions
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_activities_updated_at BEFORE UPDATE ON activities
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_activity_progress_updated_at BEFORE UPDATE ON activity_progress
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- SAMPLE DATA (FOR TESTING)
-- ============================================

-- Note: First create users through Supabase Auth, then insert into users table
-- Example flow:
-- 1. Caregiver signs up through Supabase Auth
-- 2. Create user record with role 'caregiver'
-- 3. Caregiver creates child profiles (no auth accounts needed)
-- 4. Therapist signs up separately and gets assigned to children

-- INSERT INTO users (id, email, name, role) VALUES
--   ('admin-uuid', 'admin@emolor.com', 'Admin User', 'admin'),
--   ('therapist-uuid', 'therapist@emolor.com', 'Dr. Sarah Johnson', 'therapist'),
--   ('caregiver-uuid', 'parent@emolor.com', 'Jane Doe', 'caregiver');

-- INSERT INTO child_profiles (caregiver_id, name, age, date_of_birth) VALUES
--   ('caregiver-uuid', 'Emma', 6, '2019-03-15'),
--   ('caregiver-uuid', 'Noah', 8, '2017-07-22');

-- Sample activities
INSERT INTO activities (title, description, activity_type, age_range_min, age_range_max, duration_minutes, difficulty) VALUES
  ('Emotion Color Wheel', 'Choose colors for different emotions and learn to identify feelings', 'art', 4, 8, 15, 'easy'),
  ('Feeling Faces', 'Match emotions to facial expressions in this interactive game', 'game', 5, 10, 20, 'easy'),
  ('Breathing Buddy', 'Learn calming breathing techniques with your animated buddy', 'exercise', 4, 12, 10, 'easy'),
  ('Emotion Story Time', 'Interactive story about feelings and how to express them', 'story', 5, 10, 25, 'medium'),
  ('Mood Monster Match', 'Help the mood monsters find their matching emotions', 'game', 4, 8, 15, 'easy'),
  ('Calm Corner', 'Practice mindfulness and relaxation techniques', 'exercise', 5, 12, 12, 'easy'),
  ('Feelings Journal', 'Draw and write about your feelings', 'art', 6, 12, 20, 'medium'),
  ('Emotion Detective', 'Solve puzzles by identifying emotions in different scenarios', 'game', 7, 12, 25, 'medium');

-- ============================================
-- HELPER FUNCTIONS
-- ============================================

-- Function to calculate total rewards points for a child
CREATE OR REPLACE FUNCTION get_child_total_points(profile_id UUID)
RETURNS INTEGER AS $$
  SELECT COALESCE(SUM(points), 0)::INTEGER
  FROM rewards
  WHERE child_profile_id = profile_id;
$$ LANGUAGE SQL STABLE;

-- Function to get activity completion stats for a child
CREATE OR REPLACE FUNCTION get_child_activity_stats(profile_id UUID)
RETURNS TABLE(
  total_activities BIGINT,
  completed_activities BIGINT,
  in_progress_activities BIGINT,
  total_time_spent_minutes INTEGER,
  total_stars_earned BIGINT
) AS $$
  SELECT
    COUNT(*) as total_activities,
    COUNT(*) FILTER (WHERE status = 'completed') as completed_activities,
    COUNT(*) FILTER (WHERE status = 'in_progress') as in_progress_activities,
    COALESCE(SUM(time_spent_seconds), 0)::INTEGER / 60 as total_time_spent_minutes,
    COALESCE(SUM(stars_earned), 0) as total_stars_earned
  FROM activity_progress
  WHERE child_profile_id = profile_id;
$$ LANGUAGE SQL STABLE;

-- ============================================
-- STORAGE BUCKETS (Run in Supabase Dashboard)
-- ============================================

-- Create storage buckets for:
-- 1. avatars (public)
-- 2. activity_content (public)
-- 3. session_attachments (private)

-- You can create these in Supabase Dashboard > Storage
-- Or via SQL:

-- INSERT INTO storage.buckets (id, name, public) VALUES
--   ('avatars', 'avatars', true),
--   ('activity_content', 'activity_content', true),
--   ('session_attachments', 'session_attachments', false);

-- ============================================
-- DONE! 🎉
-- ============================================

-- Your database is now ready for the EmoLor Flutter app!
