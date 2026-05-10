-- ============================================================================
-- UCD033 – Respond To Session Invitation
-- ============================================================================
-- Extends the session_requests table so therapists can accept / decline
-- session requests, and adds a double-booking guard.
-- ============================================================================

-- 1. Add decline_reason column ───────────────────────────────────────────────
-- Stores the optional reason a therapist gives when declining a request.

ALTER TABLE session_requests
    ADD COLUMN IF NOT EXISTS decline_reason TEXT;

COMMENT ON COLUMN session_requests.decline_reason IS
    'Optional reason supplied by the therapist when declining a session request (UCD033).';


-- 2. Double-booking guard function ──────────────────────────────────────────
-- Returns TRUE if the therapist already has an approved session on the same
-- date + time-slot.  Used by the Flutter service before approving.

CREATE OR REPLACE FUNCTION check_session_conflict(
    p_therapist_id UUID,
    p_date         DATE,
    p_time_slot    TEXT,
    p_exclude_id   UUID DEFAULT NULL   -- ignore the request being approved
)
RETURNS BOOLEAN
LANGUAGE plpgsql STABLE SECURITY DEFINER
AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1
        FROM   session_requests
        WHERE  therapist_id  = p_therapist_id
          AND  preferred_date = p_date
          AND  time_slot      = p_time_slot
          AND  status         = 'approved'
          AND  (p_exclude_id IS NULL OR id <> p_exclude_id)
    );
END;
$$;

COMMENT ON FUNCTION check_session_conflict IS
    'Returns true when the therapist already has an approved session for the given date & time-slot (UCD033).';


-- 3. Indexes for faster conflict checks ─────────────────────────────────────

CREATE INDEX IF NOT EXISTS idx_session_requests_conflict
    ON session_requests (therapist_id, preferred_date, time_slot)
    WHERE status = 'approved';


-- ============================================================================
-- END UCD033 migration
-- ============================================================================
