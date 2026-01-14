-- Migration: Add company association to contacts
-- Created: 2026-01-14
-- Purpose: Enable individual contacts to be linked to company contacts

-- Add is_company flag to distinguish company contacts from individuals
ALTER TABLE crm_contacts ADD COLUMN IF NOT EXISTS is_company BOOLEAN DEFAULT FALSE;

-- Add company_id to link individual contacts to their parent company
ALTER TABLE crm_contacts ADD COLUMN IF NOT EXISTS company_id UUID REFERENCES crm_contacts(id);

-- Index for efficient company lookups
CREATE INDEX IF NOT EXISTS idx_crm_contacts_company_id ON crm_contacts(company_id);

-- Partial index for quickly finding all companies
CREATE INDEX IF NOT EXISTS idx_crm_contacts_is_company ON crm_contacts(is_company) WHERE is_company = TRUE;

-- Update SCHEMA.sql documentation
COMMENT ON COLUMN crm_contacts.is_company IS 'True if this contact represents a company rather than an individual';
COMMENT ON COLUMN crm_contacts.company_id IS 'Reference to parent company contact (for individuals who work at a company)';
