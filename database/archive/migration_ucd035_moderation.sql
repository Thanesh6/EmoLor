-- ============================================================
-- UCD035 – Moderate Communication
-- Migration: message_flags table + admin moderation columns
-- ============================================================

-- ─── Message Flags table ────────────────────────────────────
-- Stores every flag/report against a chat message. A single message
-- may be flagged multiple times (system profanity-filter + user report).
CREATE TABLE IF NOT EXISTS message_flags (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    message_id      UUID NOT NULL REFERENCES chat_messages(id) ON DELETE CASCADE,
    conversation_id UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
    sender_id       UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    reporter_id     UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    reason          TEXT NOT NULL DEFAULT 'other'
                    CHECK (reason IN (
                        'profanity', 'harassment', 'prohibited_keywords',
                        'spam', 'inappropriate_content', 'user_report', 'other'
                    )),
    details         TEXT,               -- optional free-text from reporter / system
    status          TEXT NOT NULL DEFAULT 'pending'
                    CHECK (status IN ('pending', 'resolved')),
    resolution      TEXT                -- 'dismissed', 'deleted', 'suspended'
                    CHECK (resolution IS NULL OR resolution IN (
                        'dismissed', 'deleted', 'suspended'
                    )),
    resolved_by     UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    resolved_at     TIMESTAMPTZ,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Fast lookups
CREATE INDEX IF NOT EXISTS idx_message_flags_status
    ON message_flags (status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_message_flags_message
    ON message_flags (message_id);

-- ─── Extend chat_messages with moderation visibility ────────
-- When an admin deletes a message the content is cleared and this
-- flag hides it from the normal chat view.
ALTER TABLE chat_messages
    ADD COLUMN IF NOT EXISTS is_deleted BOOLEAN NOT NULL DEFAULT FALSE;

-- ─── Row Level Security ─────────────────────────────────────
ALTER TABLE message_flags ENABLE ROW LEVEL SECURITY;

-- Admin can do everything on message_flags
CREATE POLICY message_flags_admin_all ON message_flags
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM profiles p
            WHERE p.user_id = auth.uid() AND p.role = 'admin'
        )
    );

-- Users can insert a flag (report a message)
CREATE POLICY message_flags_user_insert ON message_flags
    FOR INSERT WITH CHECK (
        auth.uid() = reporter_id
    );

-- Users can see their own reports
CREATE POLICY message_flags_user_select ON message_flags
    FOR SELECT USING (
        auth.uid() = reporter_id
    );

-- Admin can read all chat_messages (for moderation review)
-- Note: the existing RLS only lets conversation participants read.
CREATE POLICY chat_messages_admin_select ON chat_messages
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM profiles p
            WHERE p.user_id = auth.uid() AND p.role = 'admin'
        )
    );

-- Admin can update chat_messages (to set is_deleted)
CREATE POLICY chat_messages_admin_update ON chat_messages
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM profiles p
            WHERE p.user_id = auth.uid() AND p.role = 'admin'
        )
    );

-- Admin can read all conversations (for context review)
CREATE POLICY conversations_admin_select ON conversations
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM profiles p
            WHERE p.user_id = auth.uid() AND p.role = 'admin'
        )
    );
