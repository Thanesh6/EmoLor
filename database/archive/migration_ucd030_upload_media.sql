-- ============================================================
-- UCD030 – Upload Media
-- Migration: Add media columns to chat_messages + storage bucket
-- ============================================================

-- ─── Add media columns to chat_messages ─────────────────────
ALTER TABLE chat_messages
    ADD COLUMN IF NOT EXISTS media_url        TEXT,
    ADD COLUMN IF NOT EXISTS media_type       TEXT CHECK (media_type IN ('image', 'document')),
    ADD COLUMN IF NOT EXISTS file_name        TEXT,
    ADD COLUMN IF NOT EXISTS file_size_bytes   INTEGER;

-- Update the message_type CHECK to include 'media'
-- (Drop and re-add the constraint)
ALTER TABLE chat_messages
    DROP CONSTRAINT IF EXISTS chat_messages_message_type_check;

ALTER TABLE chat_messages
    ADD CONSTRAINT chat_messages_message_type_check
    CHECK (message_type IN ('text', 'clinicalNote', 'feedback', 'media'));

-- ─── Create Supabase Storage bucket ─────────────────────────
-- This must be run via the Supabase Dashboard or CLI:
--   supabase storage create chat-media --public
--
-- Alternatively, insert directly into storage.buckets:
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'chat-media',
    'chat-media',
    TRUE,
    10485760,  -- 10 MB
    ARRAY[
        'image/jpeg',
        'image/png',
        'image/gif',
        'image/webp',
        'application/pdf',
        'application/msword',
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
    ]
)
ON CONFLICT (id) DO NOTHING;

-- ─── Storage RLS Policies ───────────────────────────────────

-- Allow authenticated users to upload files
CREATE POLICY storage_chat_media_insert ON storage.objects
    FOR INSERT
    TO authenticated
    WITH CHECK (bucket_id = 'chat-media');

-- Allow authenticated users to read files (public bucket, but policy required)
CREATE POLICY storage_chat_media_select ON storage.objects
    FOR SELECT
    TO authenticated
    USING (bucket_id = 'chat-media');

-- Allow users to delete only their own uploads (path starts with conversation/userId)
CREATE POLICY storage_chat_media_delete ON storage.objects
    FOR DELETE
    TO authenticated
    USING (
        bucket_id = 'chat-media'
        AND auth.uid()::text = (string_to_array(name, '_'))[1]
    );
