-- V6: Flattened architecture migrations
-- Drops legacy columns and recreates views to support flat, status-based telemetry.
-- Creates the historical fire incidents registry table.

-- 1. Drop view and index that depend on legacy columns
DROP VIEW IF EXISTS final_sensor_latest;
DROP INDEX IF EXISTS idx_final_sensor_events_device_ts;

-- 2. Alter final_sensor_events to remove legacy columns
ALTER TABLE final_sensor_events
  DROP COLUMN IF EXISTS d_id,
  DROP COLUMN IF EXISTS pos,
  DROP COLUMN IF EXISTS temp_c,
  DROP COLUMN IF EXISTS smoke_ppm;

-- 3. Recreate the final_sensor_latest view mapped to h_id
CREATE OR REPLACE VIEW final_sensor_latest AS
SELECT DISTINCT ON (h_id)
  id,
  received_at,
  h_id,
  status,
  lat,
  lon,
  raw_payload
FROM final_sensor_events
ORDER BY h_id, received_at DESC;

-- 4. Create the historical fire incidents registry table
CREATE TABLE IF NOT EXISTS historical_fire_incidents (
  id SERIAL PRIMARY KEY,
  h_id TEXT NOT NULL,
  lat NUMERIC(10,6) NOT NULL,
  lon NUMERIC(10,6) NOT NULL,
  status SMALLINT NOT NULL DEFAULT 2,
  incident_timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 5. Create indexes on historical_fire_incidents for fast queries
CREATE INDEX IF NOT EXISTS idx_historical_fire_incidents_h_id_ts
  ON historical_fire_incidents (h_id, incident_timestamp DESC);

CREATE INDEX IF NOT EXISTS idx_historical_fire_incidents_ts
  ON historical_fire_incidents (incident_timestamp DESC);
