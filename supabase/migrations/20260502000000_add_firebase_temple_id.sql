-- ============================================
-- Add firebase_temple_id column to temples table
-- This maps Supabase rows to Firestore document IDs
-- so the cron job writes live status to the correct temple.
-- ============================================

-- Add the column (nullable so existing rows are not broken)
ALTER TABLE temples
  ADD COLUMN IF NOT EXISTS firebase_temple_id TEXT;

-- Add a unique index so ON CONFLICT (firebase_temple_id) works in upserts
CREATE UNIQUE INDEX IF NOT EXISTS idx_temples_firebase_temple_id
  ON temples(firebase_temple_id)
  WHERE firebase_temple_id IS NOT NULL;

-- Back-fill: for rows where firebase_temple_id is NULL,
-- set it equal to id (the Firestore doc ID used as PK when the row was first inserted).
UPDATE temples
SET firebase_temple_id = id
WHERE firebase_temple_id IS NULL;

-- Add index for fast lookups by firebase_temple_id
CREATE INDEX IF NOT EXISTS idx_temples_firebase_id_lookup
  ON temples(firebase_temple_id);
