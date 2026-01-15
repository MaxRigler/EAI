-- Supabase Migration: Custom Labels for Contacts
-- Run this SQL in your Supabase dashboard (SQL Editor)
-- Created: 2026-01-15

-- =====================================================
-- TABLE 1: contact_labels
-- Stores label definitions (name, color)
-- =====================================================

CREATE TABLE IF NOT EXISTS public.contact_labels (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    color TEXT NOT NULL DEFAULT '#3B82F6',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable Row Level Security
ALTER TABLE public.contact_labels ENABLE ROW LEVEL SECURITY;

-- Create policy for access (adjust based on your auth setup)
CREATE POLICY "Allow all access to contact_labels" ON public.contact_labels
    FOR ALL USING (true);

-- Index for efficient label name searches
CREATE INDEX IF NOT EXISTS idx_contact_labels_name ON public.contact_labels(name);

-- =====================================================
-- TABLE 2: contact_label_assignments
-- Junction table for many-to-many contact-label relationships
-- =====================================================

CREATE TABLE IF NOT EXISTS public.contact_label_assignments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    label_id UUID NOT NULL REFERENCES public.contact_labels(id) ON DELETE CASCADE,
    contact_id UUID NOT NULL REFERENCES public.crm_contacts(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(label_id, contact_id)
);

-- Enable Row Level Security
ALTER TABLE public.contact_label_assignments ENABLE ROW LEVEL SECURITY;

-- Create policy for access
CREATE POLICY "Allow all access to contact_label_assignments" ON public.contact_label_assignments
    FOR ALL USING (true);

-- Indexes for efficient querying
-- Index for: "get all labels for a contact"
CREATE INDEX IF NOT EXISTS idx_label_assignments_contact ON public.contact_label_assignments(contact_id);

-- Index for: "get all contacts with a label"
CREATE INDEX IF NOT EXISTS idx_label_assignments_label ON public.contact_label_assignments(label_id);

-- Composite index for: efficient filtering queries
CREATE INDEX IF NOT EXISTS idx_label_assignments_label_contact ON public.contact_label_assignments(label_id, contact_id);

-- =====================================================
-- VERIFICATION: Check tables were created
-- =====================================================

-- Uncomment to verify:
-- SELECT table_name FROM information_schema.tables WHERE table_schema = 'public' AND table_name LIKE 'contact_label%';
