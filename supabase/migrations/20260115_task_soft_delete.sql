-- Migration: Add soft delete support to tasks table
-- Run this in Supabase SQL Editor

-- Add is_deleted column (defaults to false for existing tasks)
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS is_deleted BOOLEAN DEFAULT FALSE;

-- Add deleted_at column for tracking when task was deleted
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;

-- Create index for efficient filtering of non-deleted tasks
CREATE INDEX IF NOT EXISTS idx_tasks_not_deleted ON tasks(is_deleted) WHERE is_deleted = FALSE;

-- Verify the changes
SELECT column_name, data_type, column_default 
FROM information_schema.columns 
WHERE table_name = 'tasks' 
AND column_name IN ('is_deleted', 'deleted_at');
