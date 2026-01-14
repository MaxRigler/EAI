-- Migration: add_imessage_chunks
-- iMessage Chunks (daily conversation batches)
-- Groups all messages with a contact for a single day into one record

CREATE TABLE imessage_chunks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    contact_id UUID NOT NULL REFERENCES crm_contacts(id) ON DELETE CASCADE,
    date DATE NOT NULL,
    content TEXT NOT NULL,              -- Formatted day's conversation for RAG
    message_count INTEGER DEFAULT 0,
    message_guids TEXT[] DEFAULT '{}',  -- Tracks synced message GUIDs for deduplication
    raw_messages JSONB DEFAULT '[]',    -- Individual messages with timestamps
    embedding VECTOR(1536),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(contact_id, date)
);

-- Indexes for efficient queries
CREATE INDEX idx_imessage_chunks_contact ON imessage_chunks(contact_id);
CREATE INDEX idx_imessage_chunks_date ON imessage_chunks(date DESC);
CREATE INDEX idx_imessage_chunks_embedding ON imessage_chunks 
    USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);

-- Updated_at trigger (uses existing function from main schema)
CREATE TRIGGER update_imessage_chunks_updated_at
    BEFORE UPDATE ON imessage_chunks
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- Function to update iMessage chunk embedding
CREATE OR REPLACE FUNCTION update_imessage_chunk_embedding(
    p_chunk_id UUID,
    p_embedding TEXT
)
RETURNS VOID AS $$
BEGIN
    UPDATE imessage_chunks
    SET embedding = p_embedding::vector(1536)
    WHERE id = p_chunk_id;
END;
$$ LANGUAGE plpgsql;

-- Update unified search function to include iMessage chunks
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
    
    UNION ALL
    
    -- Search iMessage chunks
    SELECT
        'imessage'::TEXT AS content_type,
        im.id AS content_id,
        im.content AS content_text,
        im.contact_id,
        c.name AS contact_name,
        1 - (im.embedding <=> query_embedding) AS similarity
    FROM imessage_chunks im
    JOIN crm_contacts c ON im.contact_id = c.id
    WHERE im.embedding IS NOT NULL
      AND 1 - (im.embedding <=> query_embedding) > match_threshold
    
    ORDER BY similarity DESC
    LIMIT match_count;
END;
$$ LANGUAGE plpgsql;

-- Update contact_timeline view to include iMessages
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

UNION ALL

SELECT
    c.id AS contact_id,
    c.name AS contact_name,
    'imessage' AS interaction_type,
    im.id AS interaction_id,
    im.content,
    im.date::TIMESTAMPTZ AS timestamp
FROM crm_contacts c
JOIN imessage_chunks im ON c.id = im.contact_id

ORDER BY timestamp DESC;
