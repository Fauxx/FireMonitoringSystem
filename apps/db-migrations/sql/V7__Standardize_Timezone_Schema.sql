-- V7: Standardize Timezone & Schema Mapping
-- Ensures the API can query historical_fire_incidents using consistent Manila time boundaries.

-- 1. Create a helper function for Manila Time Conversion to simplify API queries
CREATE OR REPLACE FUNCTION to_manila(ts TIMESTAMPTZ) 
RETURNS TIMESTAMP AS $$
BEGIN
    RETURN ts AT TIME ZONE 'Asia/Manila';
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- 2. Add last_seen_at to historical_fire_incidents to support duration tracking
ALTER TABLE historical_fire_incidents 
  ADD COLUMN IF NOT EXISTS last_seen_at TIMESTAMPTZ DEFAULT NOW(),
  ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT TRUE;

-- 3. Update existing records to have a valid last_seen_at
UPDATE historical_fire_incidents SET last_seen_at = incident_timestamp WHERE last_seen_at IS NULL;

-- 4. Create an index for the debouncing logic (h_id + active status)
CREATE INDEX IF NOT EXISTS idx_hfi_active_session 
  ON historical_fire_incidents (h_id, is_active) 
  WHERE (is_active = TRUE);
