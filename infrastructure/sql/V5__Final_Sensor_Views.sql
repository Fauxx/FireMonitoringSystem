-- V5: Convenience view and indexes for final sensor payloads

-- Latest row per device_id (d_id)
CREATE OR REPLACE VIEW final_sensor_latest AS
SELECT DISTINCT ON (d_id)
  id,
  received_at,
  h_id,
  d_id,
  pos,
  temp_c,
  smoke_ppm,
  status,
  lat,
  lon,
  raw_payload
FROM final_sensor_events
ORDER BY d_id, received_at DESC;

-- Indexes to speed up household/device lookups
CREATE INDEX IF NOT EXISTS idx_final_sensor_events_household_ts
  ON final_sensor_events (h_id, received_at DESC);

CREATE INDEX IF NOT EXISTS idx_final_sensor_events_status_ts
  ON final_sensor_events (status, received_at DESC);

