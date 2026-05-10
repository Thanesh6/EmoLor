-- ╔═══════════════════════════════════════════════════════════════════════╗
-- ║  UCD042 – Edit Client Notes                                        ║
-- ║  Private clinical observations & therapy summaries per child.       ║
-- ╚═══════════════════════════════════════════════════════════════════════╝

-- ── Table ────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS client_notes (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    therapist_id  UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    child_id      UUID NOT NULL REFERENCES child_profiles(id) ON DELETE CASCADE,
    content       TEXT NOT NULL CHECK (char_length(trim(content)) > 0),
    category      TEXT DEFAULT 'General',
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Index for fast lookups by child + therapist
CREATE INDEX IF NOT EXISTS idx_client_notes_child_therapist
    ON client_notes (child_id, therapist_id, created_at DESC);

-- ── Row-Level Security ──────────────────────────────────────────────────
ALTER TABLE client_notes ENABLE ROW LEVEL SECURITY;

-- Therapists can CRUD their own notes only
CREATE POLICY client_notes_therapist_select
    ON client_notes FOR SELECT
    USING (auth.uid() = therapist_id);

CREATE POLICY client_notes_therapist_insert
    ON client_notes FOR INSERT
    WITH CHECK (auth.uid() = therapist_id);

CREATE POLICY client_notes_therapist_update
    ON client_notes FOR UPDATE
    USING (auth.uid() = therapist_id);

CREATE POLICY client_notes_therapist_delete
    ON client_notes FOR DELETE
    USING (auth.uid() = therapist_id);

-- Admin full access
CREATE POLICY client_notes_admin_all
    ON client_notes FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM profiles
            WHERE profiles.user_id = auth.uid()
              AND profiles.role = 'admin'
        )
    );

-- ── Auto-update updated_at trigger ──────────────────────────────────────
CREATE OR REPLACE FUNCTION update_client_notes_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_client_notes_updated_at ON client_notes;
CREATE TRIGGER trg_client_notes_updated_at
    BEFORE UPDATE ON client_notes
    FOR EACH ROW
    EXECUTE FUNCTION update_client_notes_updated_at();
