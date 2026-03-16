-- ============================================================
-- UCD040 – Link Client Account
-- Migration: linking_codes table + therapist_client_link table
-- ============================================================

-- 1. Therapist ↔ Caregiver link table
--    (may already exist in live DB; CREATE IF NOT EXISTS is safe)
CREATE TABLE IF NOT EXISTS therapist_client_link (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  therapist_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  client_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(therapist_id, client_id)
);

CREATE INDEX IF NOT EXISTS idx_tcl_therapist ON therapist_client_link(therapist_id);
CREATE INDEX IF NOT EXISTS idx_tcl_client ON therapist_client_link(client_id);

ALTER TABLE therapist_client_link ENABLE ROW LEVEL SECURITY;

-- Therapists can see their own links
CREATE POLICY "therapist_own_links" ON therapist_client_link
  FOR ALL USING (
    therapist_id = auth.uid()
    OR client_id = auth.uid()
  ) WITH CHECK (
    therapist_id = auth.uid()
  );

-- Admins full access
CREATE POLICY "admin_all_links" ON therapist_client_link
  FOR ALL USING (
    EXISTS (SELECT 1 FROM profiles WHERE user_id = auth.uid() AND role = 'admin')
  ) WITH CHECK (
    EXISTS (SELECT 1 FROM profiles WHERE user_id = auth.uid() AND role = 'admin')
  );

-- 2. Linking codes table
--    Caregivers generate codes; therapists consume them.
CREATE TABLE IF NOT EXISTS linking_codes (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  code TEXT NOT NULL UNIQUE,
  caregiver_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  child_profile_id UUID NOT NULL REFERENCES child_profiles(id) ON DELETE CASCADE,
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'used', 'expired')),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  expires_at TIMESTAMP WITH TIME ZONE DEFAULT (NOW() + INTERVAL '48 hours'),
  used_by UUID REFERENCES auth.users(id),
  used_at TIMESTAMP WITH TIME ZONE
);

CREATE INDEX IF NOT EXISTS idx_linking_codes_code ON linking_codes(code);
CREATE INDEX IF NOT EXISTS idx_linking_codes_caregiver ON linking_codes(caregiver_id);
CREATE INDEX IF NOT EXISTS idx_linking_codes_status ON linking_codes(status);

ALTER TABLE linking_codes ENABLE ROW LEVEL SECURITY;

-- Caregivers can manage their own codes
CREATE POLICY "caregiver_own_codes" ON linking_codes
  FOR ALL USING (caregiver_id = auth.uid())
  WITH CHECK (caregiver_id = auth.uid());

-- Therapists can read active codes (for verification)
CREATE POLICY "therapist_read_codes" ON linking_codes
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM profiles WHERE user_id = auth.uid() AND role = 'therapist')
    AND status = 'active'
  );

-- Therapists can update codes to 'used' status
CREATE POLICY "therapist_use_codes" ON linking_codes
  FOR UPDATE USING (
    EXISTS (SELECT 1 FROM profiles WHERE user_id = auth.uid() AND role = 'therapist')
  ) WITH CHECK (
    status = 'used'
  );

-- Admin full access
CREATE POLICY "admin_all_codes" ON linking_codes
  FOR ALL USING (
    EXISTS (SELECT 1 FROM profiles WHERE user_id = auth.uid() AND role = 'admin')
  ) WITH CHECK (
    EXISTS (SELECT 1 FROM profiles WHERE user_id = auth.uid() AND role = 'admin')
  );

-- 3. Helper function: generate a random 7-char alphanumeric code (A7X-92B format)
CREATE OR REPLACE FUNCTION generate_linking_code()
RETURNS TEXT AS $$
DECLARE
  chars TEXT := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; -- No 0/O/1/I ambiguity
  result TEXT := '';
  i INTEGER;
BEGIN
  FOR i IN 1..3 LOOP
    result := result || substr(chars, floor(random() * length(chars) + 1)::int, 1);
  END LOOP;
  result := result || '-';
  FOR i IN 1..3 LOOP
    result := result || substr(chars, floor(random() * length(chars) + 1)::int, 1);
  END LOOP;
  RETURN result;
END;
$$ LANGUAGE plpgsql;

-- 4. Auto-expire old codes (can be called via cron or on-demand)
CREATE OR REPLACE FUNCTION expire_old_linking_codes()
RETURNS void AS $$
BEGIN
  UPDATE linking_codes
  SET status = 'expired'
  WHERE status = 'active'
    AND expires_at < NOW();
END;
$$ LANGUAGE plpgsql;
