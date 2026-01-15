-- Migration: Extend search_all_content to include emails and iMessages
-- Run this in Supabase SQL Editor

-- Drop existing function to recreate with full content types
DROP FUNCTION IF EXISTS search_all_content(VECTOR(1536), FLOAT, INT);

-- Extended unified RAG search across all content types
CREATE OR REPLACE FUNCTION search_all_content(
    query_embedding VECTOR(1536),
    match_threshold FLOAT DEFAULT 0.5,
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
    
    -- Search daily summaries
    SELECT
        'daily_summary'::TEXT AS content_type,
        ds.id AS content_id,
        ds.summary_text AS content_text,
        NULL::UUID AS contact_id,
        NULL::TEXT AS contact_name,
        1 - (ds.embedding <=> query_embedding) AS similarity
    FROM daily_summaries ds
    WHERE ds.embedding IS NOT NULL
      AND 1 - (ds.embedding <=> query_embedding) > match_threshold
    
    UNION ALL
    
    -- Search emails
    SELECT
        'email'::TEXT AS content_type,
        e.id AS content_id,
        COALESCE(e.subject || ': ', '') || COALESCE(e.body, '') AS content_text,
        e.contact_id,
        c.name AS contact_name,
        1 - (e.embedding <=> query_embedding) AS similarity
    FROM emails e
    LEFT JOIN crm_contacts c ON e.contact_id = c.id
    WHERE e.embedding IS NOT NULL
      AND 1 - (e.embedding <=> query_embedding) > match_threshold
    
    UNION ALL
    
    -- Search iMessage chunks
    SELECT
        'imessage'::TEXT AS content_type,
        im.id AS content_id,
        im.combined_text AS content_text,
        im.contact_id,
        c.name AS contact_name,
        1 - (im.embedding <=> query_embedding) AS similarity
    FROM imessage_chunks im
    LEFT JOIN crm_contacts c ON im.contact_id = c.id
    WHERE im.embedding IS NOT NULL
      AND 1 - (im.embedding <=> query_embedding) > match_threshold
    
    ORDER BY similarity DESC
    LIMIT match_count;
END;
$$ LANGUAGE plpgsql;
