-- ============================================================
-- UCD029 – Add Message / Feedback
-- Migration: conversations & chat_messages tables
-- ============================================================

-- ─── Conversations ──────────────────────────────────────────
CREATE TABLE IF NOT EXISTS conversations (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    participant_one_id   UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    participant_two_id   UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    participant_one_name TEXT NOT NULL DEFAULT '',
    participant_two_name TEXT NOT NULL DEFAULT '',
    last_message_preview TEXT,
    last_message_at      TIMESTAMPTZ,
    created_at           TIMESTAMPTZ NOT NULL DEFAULT now(),

    -- Prevent duplicate conversations between same pair
    CONSTRAINT unique_conversation_pair
        UNIQUE (participant_one_id, participant_two_id)
);

-- Index for fast lookup by either participant
CREATE INDEX IF NOT EXISTS idx_conversations_p1
    ON conversations (participant_one_id);
CREATE INDEX IF NOT EXISTS idx_conversations_p2
    ON conversations (participant_two_id);

-- ─── Chat Messages ──────────────────────────────────────────
CREATE TABLE IF NOT EXISTS chat_messages (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
    sender_id       UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    sender_name     TEXT NOT NULL DEFAULT '',
    sender_role     TEXT NOT NULL DEFAULT 'caregiver',
    content         TEXT NOT NULL,
    message_type    TEXT NOT NULL DEFAULT 'text'
                    CHECK (message_type IN ('text', 'clinicalNote', 'feedback')),
    is_read         BOOLEAN NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_chat_messages_conversation
    ON chat_messages (conversation_id, created_at);
CREATE INDEX IF NOT EXISTS idx_chat_messages_sender
    ON chat_messages (sender_id);

-- ─── Row Level Security ─────────────────────────────────────
ALTER TABLE conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_messages ENABLE ROW LEVEL SECURITY;

-- Conversations: participants can view their own
CREATE POLICY conversations_select ON conversations
    FOR SELECT USING (
        auth.uid() = participant_one_id OR
        auth.uid() = participant_two_id
    );

-- Conversations: participants can insert (create a conversation)
CREATE POLICY conversations_insert ON conversations
    FOR INSERT WITH CHECK (
        auth.uid() = participant_one_id OR
        auth.uid() = participant_two_id
    );

-- Conversations: participants can update (last_message_preview, etc.)
CREATE POLICY conversations_update ON conversations
    FOR UPDATE USING (
        auth.uid() = participant_one_id OR
        auth.uid() = participant_two_id
    );

-- Chat messages: participants of the conversation can view
CREATE POLICY chat_messages_select ON chat_messages
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM conversations c
            WHERE c.id = chat_messages.conversation_id
              AND (auth.uid() = c.participant_one_id OR auth.uid() = c.participant_two_id)
        )
    );

-- Chat messages: only sender can insert
CREATE POLICY chat_messages_insert ON chat_messages
    FOR INSERT WITH CHECK (
        auth.uid() = sender_id AND
        EXISTS (
            SELECT 1 FROM conversations c
            WHERE c.id = chat_messages.conversation_id
              AND (auth.uid() = c.participant_one_id OR auth.uid() = c.participant_two_id)
        )
    );

-- Chat messages: recipient can mark as read (update is_read only)
CREATE POLICY chat_messages_update ON chat_messages
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM conversations c
            WHERE c.id = chat_messages.conversation_id
              AND (auth.uid() = c.participant_one_id OR auth.uid() = c.participant_two_id)
        )
    );

-- ─── Enable Realtime ────────────────────────────────────────
ALTER PUBLICATION supabase_realtime ADD TABLE chat_messages;
