-- Gmail Integration Migration
-- Run this in Supabase SQL Editor to add email-related enhancements

-- Add additional columns to emails table for sender/recipient info
DO $$ 
BEGIN
    -- Add sender_email column if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'emails' AND column_name = 'sender_email') THEN
        ALTER TABLE emails ADD COLUMN sender_email TEXT;
    END IF;
    
    -- Add sender_name column if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'emails' AND column_name = 'sender_name') THEN
        ALTER TABLE emails ADD COLUMN sender_name TEXT;
    END IF;
    
    -- Add recipient_email column if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'emails' AND column_name = 'recipient_email') THEN
        ALTER TABLE emails ADD COLUMN recipient_email TEXT;
    END IF;
END $$;

-- Create RPC function to update email embedding
CREATE OR REPLACE FUNCTION update_email_embedding(
    p_email_id UUID,
    p_embedding TEXT
)
RETURNS VOID AS $$
BEGIN
    UPDATE emails
    SET embedding = p_embedding::vector(1536)
    WHERE id = p_email_id;
END;
$$ LANGUAGE plpgsql;

-- Create index on gmail_id for faster lookups
CREATE INDEX IF NOT EXISTS idx_emails_gmail_id ON emails(gmail_id);

-- Create index on thread_id for conversation grouping
CREATE INDEX IF NOT EXISTS idx_emails_thread_id ON emails(thread_id);

-- Grant execute permission on the function
GRANT EXECUTE ON FUNCTION update_email_embedding(UUID, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION update_email_embedding(UUID, TEXT) TO anon;
