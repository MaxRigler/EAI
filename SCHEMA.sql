-- E-AI CRM Database Schema
-- Supabase (PostgreSQL + pgvector)
-- Run this in Supabase SQL Editor to set up your database

-- Enable pgvector extension for embeddings
CREATE EXTENSION IF NOT EXISTS vector;

-- ============================================
-- CORE TABLES
-- ============================================

-- Recording Types (configurable categories with prompt templates)
CREATE TABLE recording_types (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL UNIQUE,
    prompt_template TEXT NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Seed default recording types
INSERT INTO recording_types (name, prompt_template) VALUES
('Cold Call', 'You are analyzing a cold call transcript. Extract:
1. Prospect''s stated needs or pain points
2. Objections raised
3. Interest level (1-10 scale with reasoning)
4. Next steps agreed upon
5. Any action items or tasks mentioned (e.g., "send me info", "call back Tuesday")

Format as structured sections. Be concise but thorough.'),

('Client Support', 'You are analyzing a client support call transcript. Extract:
1. Issue or question reported
2. Resolution provided (if any)
3. Customer satisfaction indicators (tone, explicit feedback)
4. Follow-up required (yes/no, with details)
5. Any action items or tasks mentioned

Format as structured sections. Be concise but thorough.'),

('Zoom Meeting', 'You are analyzing a meeting transcript. Extract:
1. Attendees who spoke (by speaker number/name)
2. Key topics discussed
3. Decisions made
4. Action items with owners (who committed to what)
5. Open questions or unresolved items

Format as structured sections. Be concise but thorough.'),

('General Call', 'You are analyzing a call transcript. Extract:
1. Main topics discussed
2. Key points made by each participant
3. Any agreements or conclusions reached
4. Action items or follow-ups mentioned
5. Overall tone and outcome

Format as structured sections. Be concise but thorough.');


-- CRM Contacts (business contacts linked to Apple Contacts)
CREATE TABLE crm_contacts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    apple_contact_id TEXT, -- Link to Apple Contacts identifier
    name TEXT NOT NULL, -- Cached from Apple Contacts
    email TEXT,
    phone TEXT,
    business_type TEXT,
    company TEXT,
    domain TEXT,
    deal_stage TEXT,
    tags TEXT[] DEFAULT '{}',
    custom_fields JSONB DEFAULT '{}',
    is_company BOOLEAN DEFAULT FALSE, -- True if this contact represents a company
    company_id UUID REFERENCES crm_contacts(id), -- Reference to parent company contact
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index for Apple Contact lookup
CREATE INDEX idx_crm_contacts_apple_id ON crm_contacts(apple_contact_id);
CREATE INDEX idx_crm_contacts_deal_stage ON crm_contacts(deal_stage);
CREATE INDEX idx_crm_contacts_company ON crm_contacts(company);
CREATE INDEX idx_crm_contacts_company_id ON crm_contacts(company_id);
CREATE INDEX idx_crm_contacts_is_company ON crm_contacts(is_company) WHERE is_company = TRUE;


-- Recordings (audio recording metadata)
CREATE TABLE recordings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    file_path TEXT NOT NULL, -- Local filesystem path
    duration_seconds INTEGER,
    recording_type_id UUID REFERENCES recording_types(id),
    status TEXT DEFAULT 'processing' CHECK (status IN ('processing', 'transcribing', 'summarizing', 'complete', 'failed')),
    error_message TEXT, -- Populated if status = 'failed'
    retry_count INTEGER DEFAULT 0,
    context TEXT, -- Additional context for AI prompts (key topics, objectives, etc.)
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index for status queries
CREATE INDEX idx_recordings_status ON recordings(status);
CREATE INDEX idx_recordings_created_at ON recordings(created_at DESC);


-- Recording Speakers (links speakers in a recording to contacts)
CREATE TABLE recording_speakers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    recording_id UUID NOT NULL REFERENCES recordings(id) ON DELETE CASCADE,
    speaker_number INTEGER NOT NULL CHECK (speaker_number BETWEEN 1 AND 10),
    contact_id UUID REFERENCES crm_contacts(id),
    is_user BOOLEAN DEFAULT FALSE, -- True if this speaker is the app owner
    UNIQUE(recording_id, speaker_number)
);

-- Index for contact lookup
CREATE INDEX idx_recording_speakers_contact ON recording_speakers(contact_id);


-- Transcripts (full transcription with speaker segments)
CREATE TABLE transcripts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    recording_id UUID NOT NULL UNIQUE REFERENCES recordings(id) ON DELETE CASCADE,
    full_text TEXT NOT NULL,
    speaker_segments JSONB DEFAULT '[]', -- Array of {speaker, start, end, text}
    embedding VECTOR(1536), -- OpenAI embedding dimension
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Vector index for semantic search
CREATE INDEX idx_transcripts_embedding ON transcripts USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);


-- Summaries (AI-generated summaries of recordings)
CREATE TABLE summaries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    recording_id UUID NOT NULL UNIQUE REFERENCES recordings(id) ON DELETE CASCADE,
    summary_text TEXT NOT NULL,
    prompt_template_used TEXT, -- Snapshot of prompt used
    embedding VECTOR(1536),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Vector index for semantic search
CREATE INDEX idx_summaries_embedding ON summaries USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);


-- Tasks (auto-extracted and manual tasks)
CREATE TABLE tasks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    contact_id UUID REFERENCES crm_contacts(id),
    recording_id UUID REFERENCES recordings(id), -- Source recording (if auto-extracted)
    description TEXT NOT NULL,
    status TEXT DEFAULT 'open' CHECK (status IN ('open', 'completed')),
    due_date DATE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    completed_at TIMESTAMPTZ
);

-- Indexes for task queries
CREATE INDEX idx_tasks_contact ON tasks(contact_id);
CREATE INDEX idx_tasks_status ON tasks(status);
CREATE INDEX idx_tasks_due_date ON tasks(due_date);


-- Comments (manual notes on contacts)
CREATE TABLE comments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    contact_id UUID NOT NULL REFERENCES crm_contacts(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index for contact timeline
CREATE INDEX idx_comments_contact ON comments(contact_id);
CREATE INDEX idx_comments_created_at ON comments(created_at DESC);


-- Chat Threads (conversation threads with AI)
CREATE TABLE chat_threads (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT DEFAULT 'New Chat',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_chat_threads_updated ON chat_threads(updated_at DESC);


-- Chat Messages (individual messages in threads)
CREATE TABLE chat_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    thread_id UUID NOT NULL REFERENCES chat_threads(id) ON DELETE CASCADE,
    role TEXT NOT NULL CHECK (role IN ('user', 'assistant')),
    content TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_chat_messages_thread ON chat_messages(thread_id);
CREATE INDEX idx_chat_messages_created ON chat_messages(created_at);


-- Daily Summaries (auto-generated nightly summaries)
CREATE TABLE daily_summaries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    date DATE NOT NULL UNIQUE,
    summary_text TEXT NOT NULL,
    recording_count INTEGER DEFAULT 0,
    embedding VECTOR(1536),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_daily_summaries_date ON daily_summaries(date DESC);
CREATE INDEX idx_daily_summaries_embedding ON daily_summaries USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);


-- ============================================
-- FUTURE TABLES (Schema-ready, not used in V1)
-- ============================================

-- Emails (for future Gmail integration)
CREATE TABLE emails (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    contact_id UUID REFERENCES crm_contacts(id),
    gmail_id TEXT UNIQUE, -- Gmail message ID
    thread_id TEXT, -- Gmail thread ID
    subject TEXT,
    body TEXT,
    direction TEXT CHECK (direction IN ('inbound', 'outbound')),
    timestamp TIMESTAMPTZ,
    embedding VECTOR(1536),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_emails_contact ON emails(contact_id);
CREATE INDEX idx_emails_timestamp ON emails(timestamp DESC);
CREATE INDEX idx_emails_embedding ON emails USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);


-- iMessages (for future iMessage integration)
CREATE TABLE imessages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    contact_id UUID REFERENCES crm_contacts(id),
    imessage_guid TEXT UNIQUE, -- iMessage GUID from chat.db
    content TEXT,
    direction TEXT CHECK (direction IN ('inbound', 'outbound')),
    timestamp TIMESTAMPTZ,
    embedding VECTOR(1536),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_imessages_contact ON imessages(contact_id);
CREATE INDEX idx_imessages_timestamp ON imessages(timestamp DESC);
CREATE INDEX idx_imessages_embedding ON imessages USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);


-- Actions (for future action execution capabilities)
CREATE TABLE actions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    chat_message_id UUID REFERENCES chat_messages(id),
    action_type TEXT NOT NULL CHECK (action_type IN ('send_email', 'send_sms', 'create_event', 'create_task', 'other')),
    payload JSONB NOT NULL DEFAULT '{}',
    status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'executed', 'failed', 'cancelled')),
    error_message TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    executed_at TIMESTAMPTZ
);

CREATE INDEX idx_actions_status ON actions(status);
CREATE INDEX idx_actions_chat_message ON actions(chat_message_id);


-- ============================================
-- HELPER FUNCTIONS
-- ============================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply updated_at trigger to relevant tables
CREATE TRIGGER update_crm_contacts_updated_at
    BEFORE UPDATE ON crm_contacts
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER update_recordings_updated_at
    BEFORE UPDATE ON recordings
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER update_comments_updated_at
    BEFORE UPDATE ON comments
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER update_chat_threads_updated_at
    BEFORE UPDATE ON chat_threads
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();


-- ============================================
-- VECTOR SEARCH FUNCTIONS
-- ============================================

-- Function to search transcripts by semantic similarity
CREATE OR REPLACE FUNCTION search_transcripts(
    query_embedding VECTOR(1536),
    match_threshold FLOAT DEFAULT 0.7,
    match_count INT DEFAULT 10
)
RETURNS TABLE (
    id UUID,
    recording_id UUID,
    full_text TEXT,
    similarity FLOAT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        t.id,
        t.recording_id,
        t.full_text,
        1 - (t.embedding <=> query_embedding) AS similarity
    FROM transcripts t
    WHERE t.embedding IS NOT NULL
      AND 1 - (t.embedding <=> query_embedding) > match_threshold
    ORDER BY t.embedding <=> query_embedding
    LIMIT match_count;
END;
$$ LANGUAGE plpgsql;


-- Function to search summaries by semantic similarity
CREATE OR REPLACE FUNCTION search_summaries(
    query_embedding VECTOR(1536),
    match_threshold FLOAT DEFAULT 0.7,
    match_count INT DEFAULT 10
)
RETURNS TABLE (
    id UUID,
    recording_id UUID,
    summary_text TEXT,
    similarity FLOAT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        s.id,
        s.recording_id,
        s.summary_text,
        1 - (s.embedding <=> query_embedding) AS similarity
    FROM summaries s
    WHERE s.embedding IS NOT NULL
      AND 1 - (s.embedding <=> query_embedding) > match_threshold
    ORDER BY s.embedding <=> query_embedding
    LIMIT match_count;
END;
$$ LANGUAGE plpgsql;


-- Function to search all content (unified RAG search)
CREATE OR REPLACE FUNCTION search_all_content(
    query_embedding VECTOR(1536),
    match_threshold FLOAT DEFAULT 0.7,
    match_count INT DEFAULT 20
)
RETURNS TABLE (
    content_type TEXT,
    content_id UUID,
    content_text TEXT,
    contact_id UUID,
    contact_name TEXT,
    similarity FLOAT
) AS $$
BEGIN
    RETURN QUERY
    
    -- Search transcripts
    SELECT
        'transcript'::TEXT AS content_type,
        t.id AS content_id,
        t.full_text AS content_text,
        rs.contact_id,
        c.name AS contact_name,
        1 - (t.embedding <=> query_embedding) AS similarity
    FROM transcripts t
    JOIN recordings r ON t.recording_id = r.id
    LEFT JOIN recording_speakers rs ON r.id = rs.recording_id AND rs.speaker_number = 1
    LEFT JOIN crm_contacts c ON rs.contact_id = c.id
    WHERE t.embedding IS NOT NULL
      AND 1 - (t.embedding <=> query_embedding) > match_threshold
    
    UNION ALL
    
    -- Search summaries
    SELECT
        'summary'::TEXT AS content_type,
        s.id AS content_id,
        s.summary_text AS content_text,
        rs.contact_id,
        c.name AS contact_name,
        1 - (s.embedding <=> query_embedding) AS similarity
    FROM summaries s
    JOIN recordings r ON s.recording_id = r.id
    LEFT JOIN recording_speakers rs ON r.id = rs.recording_id AND rs.speaker_number = 1
    LEFT JOIN crm_contacts c ON rs.contact_id = c.id
    WHERE s.embedding IS NOT NULL
      AND 1 - (s.embedding <=> query_embedding) > match_threshold
    
    ORDER BY similarity DESC
    LIMIT match_count;
END;
$$ LANGUAGE plpgsql;


-- ============================================
-- EMBEDDING UPDATE FUNCTIONS (for RPC calls from Swift)
-- ============================================

-- Function to update transcript embedding
CREATE OR REPLACE FUNCTION update_transcript_embedding(
    p_transcript_id UUID,
    p_embedding TEXT
)
RETURNS VOID AS $$
BEGIN
    UPDATE transcripts
    SET embedding = p_embedding::vector(1536)
    WHERE id = p_transcript_id;
END;
$$ LANGUAGE plpgsql;

-- Function to update summary embedding
CREATE OR REPLACE FUNCTION update_summary_embedding(
    p_summary_id UUID,
    p_embedding TEXT
)
RETURNS VOID AS $$
BEGIN
    UPDATE summaries
    SET embedding = p_embedding::vector(1536)
    WHERE id = p_summary_id;
END;
$$ LANGUAGE plpgsql;

-- Function to update daily summary embedding
CREATE OR REPLACE FUNCTION update_daily_summary_embedding(
    p_daily_summary_id UUID,
    p_embedding TEXT
)
RETURNS VOID AS $$
BEGIN
    UPDATE daily_summaries
    SET embedding = p_embedding::vector(1536)
    WHERE id = p_daily_summary_id;
END;
$$ LANGUAGE plpgsql;


-- ============================================
-- ROW LEVEL SECURITY (Optional - enable if needed)
-- ============================================

-- For now, RLS is disabled since this is a single-user app.
-- If you later need multi-user support, enable RLS and add policies.

-- ALTER TABLE crm_contacts ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE recordings ENABLE ROW LEVEL SECURITY;
-- etc.


-- ============================================
-- USEFUL VIEWS
-- ============================================

-- View: Contact timeline (all interactions for a contact)
CREATE OR REPLACE VIEW contact_timeline AS
SELECT
    c.id AS contact_id,
    c.name AS contact_name,
    'recording' AS interaction_type,
    r.id AS interaction_id,
    COALESCE(s.summary_text, 'Processing...') AS content,
    r.created_at AS timestamp
FROM crm_contacts c
JOIN recording_speakers rs ON c.id = rs.contact_id
JOIN recordings r ON rs.recording_id = r.id
LEFT JOIN summaries s ON r.id = s.recording_id

UNION ALL

SELECT
    c.id AS contact_id,
    c.name AS contact_name,
    'comment' AS interaction_type,
    cm.id AS interaction_id,
    cm.content,
    cm.created_at AS timestamp
FROM crm_contacts c
JOIN comments cm ON c.id = cm.contact_id

ORDER BY timestamp DESC;


-- View: Daily activity summary
CREATE OR REPLACE VIEW daily_activity AS
SELECT
    DATE(r.created_at) AS date,
    COUNT(r.id) AS recording_count,
    COUNT(DISTINCT rs.contact_id) AS unique_contacts,
    COUNT(DISTINCT CASE WHEN t.status = 'open' THEN t.id END) AS open_tasks_created
FROM recordings r
LEFT JOIN recording_speakers rs ON r.id = rs.recording_id
LEFT JOIN tasks t ON r.id = t.recording_id
GROUP BY DATE(r.created_at)
ORDER BY date DESC;


-- ============================================
-- INITIAL SETUP COMPLETE
-- ============================================

-- After running this schema, you'll need to:
-- 1. Note your Supabase project URL and anon key
-- 2. Store these in macOS Keychain via the E-AI app
-- 3. The app will handle all CRUD operations from there
