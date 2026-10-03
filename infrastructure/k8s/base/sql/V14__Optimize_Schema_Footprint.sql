-- V14: Database Normalization (3NF) & Index Optimization

-- Drop the view that depends on the columns we are about to delete
DROP VIEW IF EXISTS final_sensor_latest CASCADE;

-- 1. Remove redundant static data from time-series tables (Minimizes disk space)
ALTER TABLE final_sensor_events 
  DROP COLUMN IF EXISTS lat CASCADE,
  DROP COLUMN IF EXISTS lon CASCADE,
  DROP COLUMN IF EXISTS raw_payload CASCADE,
  DROP COLUMN IF EXISTS d_id CASCADE,
  DROP COLUMN IF EXISTS pos CASCADE;

-- 2. Add missing specific metric columns to the event table
ALTER TABLE final_sensor_events
  ADD COLUMN IF NOT EXISTS flame_intensity NUMERIC(10,2);

-- 3. Create High-Performance Time-Series Indexes
CREATE INDEX IF NOT EXISTS idx_fse_hid_time ON final_sensor_events (h_id, received_at DESC);
CREATE INDEX IF NOT EXISTS idx_hfi_hid_active ON historical_fire_incidents (h_id) WHERE is_active = TRUE;
