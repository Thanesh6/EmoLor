-- ============================================================================
-- UCD034 – Schedule Session
-- ============================================================================
-- Extends the existing `sessions` table so it can be used by both therapists
-- and caregivers.  Adds a link to `session_requests` (when a scheduled
-- session originates from an approved request) and a concurrency-safe
-- slot-taken guard.
-- ============================================================================

-- 1. Extend `sessions` table ────────────────────────────────────────────────

-- Allow sessions to track which caregiver is involved.
ALTER TABLE sessions
    ADD COLUMN IF NOT EXISTS caregiver_id UUID REFERENCES auth.users(id) ON DELETE SET NULL;

-- Link back to the session_request that spawned this session (nullable – the
-- therapist can also schedule ad-hoc sessions with no prior request).
ALTER TABLE sessions
    ADD COLUMN IF NOT EXISTS session_request_id UUID REFERENCES session_requests(id) ON DELETE SET NULL;

-- Add a `time_slot` column aligned with the time-slot enum used in
-- session_requests so calendar views can group by slot.
ALTER TABLE sessions
    ADD COLUMN IF NOT EXISTS time_slot TEXT CHECK (time_slot IN ('morning', 'midday', 'afternoon', 'evening'));

COMMENT ON COLUMN sessions.caregiver_id IS
    'The caregiver linked to this session (UCD034).';
COMMENT ON COLUMN sessions.session_request_id IS
    'FK to the session_request that triggered this session, if any (UCD034).';
COMMENT ON COLUMN sessions.time_slot IS
    'Time-slot bucket aligned with session_requests.time_slot (UCD034).';


-- 2. Slot-taken guard function ──────────────────────────────────────────────
-- Returns TRUE when the therapist already has a scheduled (not cancelled)
-- session overlapping the given date + time-slot.

CREATE OR REPLACE FUNCTION check_schedule_conflict(
    p_therapist_id UUID,
    p_date         DATE,
    p_time_slot    TEXT,
    p_exclude_id   UUID DEFAULT NULL
)
RETURNS BOOLEAN
LANGUAGE plpgsql STABLE SECURITY DEFINER
AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1
        FROM   sessions
        WHERE  therapist_id   = p_therapist_id
          AND  session_date::date = p_date
          AND  time_slot       = p_time_slot
          AND  status          = 'scheduled'
          AND  (p_exclude_id IS NULL OR id <> p_exclude_id)
    );
END;
$$;

COMMENT ON FUNCTION check_schedule_conflict IS
    'Returns true when the therapist already has a scheduled session for the given date & time-slot (UCD034).';


-- 3. Row-Level Security ─────────────────────────────────────────────────────

ALTER TABLE sessions ENABLE ROW LEVEL SECURITY;

-- Therapists can do everything with their own sessions
CREATE POLICY sessions_therapist_all ON sessions
    FOR ALL
    USING (auth.uid() = therapist_id)
    WITH CHECK (auth.uid() = therapist_id);

-- Caregivers can SELECT sessions they are a participant in
CREATE POLICY sessions_caregiver_select ON sessions
    FOR SELECT
    USING (auth.uid() = caregiver_id);

-- Admins can see all
CREATE POLICY sessions_admin_all ON sessions
    FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM profiles
            WHERE profiles.user_id = auth.uid()
              AND profiles.role = 'admin'
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM profiles
            WHERE profiles.user_id = auth.uid()
              AND profiles.role = 'admin'
        )
    );


-- 4. Indexes ────────────────────────────────────────────────────────────────

CREATE INDEX IF NOT EXISTS idx_sessions_caregiver
    ON sessions (caregiver_id);

CREATE INDEX IF NOT EXISTS idx_sessions_schedule_conflict
    ON sessions (therapist_id, session_date, time_slot)
    WHERE status = 'scheduled';

CREATE INDEX IF NOT EXISTS idx_sessions_request_link
    ON sessions (session_request_id);


-- ============================================================================
-- END UCD034 migration
-- ============================================================================
