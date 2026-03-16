-- ============================================================
-- UCD031 – View Message / Feedback
-- Migration: unread count tracking + conversation thread view
-- ============================================================

-- ─── Unread Count View ──────────────────────────────────────
-- Returns the number of unread messages per conversation for the
-- currently-authenticated user.  Used by the conversation list
-- to display badge counts.

CREATE OR REPLACE FUNCTION get_unread_count(p_conversation_id UUID, p_user_id UUID)
RETURNS INTEGER AS $$
  SELECT COALESCE(COUNT(*)::INTEGER, 0)
  FROM chat_messages
  WHERE conversation_id = p_conversation_id
    AND sender_id != p_user_id
    AND is_read = FALSE;
$$ LANGUAGE SQL STABLE SECURITY DEFINER;

-- ─── Total Unread Messages (all conversations) ─────────────
-- Used for the dashboard badge showing total unread count.

CREATE OR REPLACE FUNCTION get_total_unread_count(p_user_id UUID)
RETURNS INTEGER AS $$
  SELECT COALESCE(COUNT(*)::INTEGER, 0)
  FROM chat_messages m
  JOIN conversations c ON c.id = m.conversation_id
  WHERE m.sender_id != p_user_id
    AND m.is_read = FALSE
    AND (c.participant_one_id = p_user_id OR c.participant_two_id = p_user_id);
$$ LANGUAGE SQL STABLE SECURITY DEFINER;

-- ─── Index for fast unread lookups ──────────────────────────
CREATE INDEX IF NOT EXISTS idx_chat_messages_unread
    ON chat_messages (conversation_id, sender_id, is_read)
    WHERE is_read = FALSE;

-- ─── Mark conversation messages as read ─────────────────────
-- Atomically marks all unread messages in a conversation as read
-- for the given user (i.e., messages NOT sent by that user).

CREATE OR REPLACE FUNCTION mark_conversation_read(p_conversation_id UUID, p_user_id UUID)
RETURNS INTEGER AS $$
DECLARE
  updated_count INTEGER;
BEGIN
  UPDATE chat_messages
  SET is_read = TRUE
  WHERE conversation_id = p_conversation_id
    AND sender_id != p_user_id
    AND is_read = FALSE;

  GET DIAGNOSTICS updated_count = ROW_COUNT;
  RETURN updated_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
