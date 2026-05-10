-- ============================================================================
-- UCD028 – Request Session : session_requests table
-- ============================================================================
-- Stores formal session requests from caregivers to their linked therapists.
-- ============================================================================

-- 1. session_requests table ──────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS session_requests (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    caregiver_id     UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    therapist_id     UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    child_name       TEXT,                         -- Informational, for notification text
    child_profile_id UUID REFERENCES child_profiles(id) ON DELETE SET NULL,
    preferred_date   DATE NOT NULL,
    time_slot        TEXT NOT NULL CHECK (time_slot IN ('morning', 'midday', 'afternoon', 'evening')),
    reason           TEXT NOT NULL,
    status           TEXT NOT NULL DEFAULT 'pending'
                     CHECK (status IN ('pending', 'approved', 'declined', 'cancelled')),
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE session_requests IS
    'Caregiver-originated session requests sent to their linked therapist (UCD028).';

-- Auto-update updated_at
CREATE OR REPLACE FUNCTION update_session_requests_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_session_requests_updated_at
    BEFORE UPDATE ON session_requests
    FOR EACH ROW
    EXECUTE FUNCTION update_session_requests_updated_at();


-- 2. Row-Level Security ─────────────────────────────────────────────────────

ALTER TABLE session_requests ENABLE ROW LEVEL SECURITY;

-- Caregivers can INSERT their own requests
CREATE POLICY session_requests_caregiver_insert ON session_requests
    FOR INSERT
    WITH CHECK (auth.uid() = caregiver_id);

-- Caregivers can SELECT their own requests
CREATE POLICY session_requests_caregiver_select ON session_requests
    FOR SELECT
    USING (auth.uid() = caregiver_id);

-- Caregivers can UPDATE (cancel) their own pending requests
CREATE POLICY session_requests_caregiver_update ON session_requests
    FOR UPDATE
    USING (auth.uid() = caregiver_id AND status = 'pending')
    WITH CHECK (auth.uid() = caregiver_id);

-- Therapists can SELECT requests addressed to them
CREATE POLICY session_requests_therapist_select ON session_requests
    FOR SELECT
    USING (auth.uid() = therapist_id);

-- Therapists can UPDATE (approve/decline) requests addressed to them
CREATE POLICY session_requests_therapist_update ON session_requests
    FOR UPDATE
    USING (auth.uid() = therapist_id)
    WITH CHECK (auth.uid() = therapist_id);

-- Admins can see all requests
CREATE POLICY session_requests_admin_all ON session_requests
    FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM profiles
            WHERE profiles.id = auth.uid()
              AND profiles.role = 'admin'
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM profiles
            WHERE profiles.id = auth.uid()
              AND profiles.role = 'admin'
        )
    );


-- 3. Indexes ────────────────────────────────────────────────────────────────

CREATE INDEX idx_session_requests_caregiver ON session_requests (caregiver_id);
CREATE INDEX idx_session_requests_therapist ON session_requests (therapist_id);
CREATE INDEX idx_session_requests_status    ON session_requests (status);
CREATE INDEX idx_session_requests_date      ON session_requests (preferred_date);


-- 4. Notifications table (if not already present) ───────────────────────────
-- The service inserts a row here so the therapist sees an in-app notification.
-- If you already have a notifications table, skip this section.

CREATE TABLE IF NOT EXISTS notifications (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id    UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    title      TEXT NOT NULL,
    body       TEXT,
    type       TEXT,            -- e.g. 'session_request', 'message', etc.
    is_read    BOOLEAN NOT NULL DEFAULT FALSE,
    metadata   JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_notifications_user ON notifications (user_id, is_read);


-- ============================================================================
-- END UCD028 migration
-- ============================================================================
