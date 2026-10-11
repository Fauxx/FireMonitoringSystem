-- V4: Store final JSON schema payloads
-- Payload shape:
-- {
--   "h_id": "REYES_P",
--   "d_id": "K1",
--   "pos": "Kitchen",
--   "env": { "t": 28.5, "s": 105.2 },
--   "log": { "st": 1 },
--   "loc": [14.5995, 121.0365]
-- }

CREATE TABLE IF NOT EXISTS final_sensor_events (
  id BIGSERIAL PRIMARY KEY,
  received_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  h_id TEXT NOT NULL,
  d_id TEXT NOT NULL,
  pos TEXT,
  temp_c NUMERIC(10,2),           -- env.t
  smoke_ppm NUMERIC(12,2),        -- env.s
  status SMALLINT,                -- log.st
  lat NUMERIC(10,6),
  lon NUMERIC(10,6),
  raw_payload JSONB NOT NULL      -- full original message
);

CREATE INDEX IF NOT EXISTS idx_final_sensor_events_device_ts
  ON final_sensor_events (d_id, received_at DESC);

CREATE INDEX IF NOT EXISTS idx_final_sensor_events_location
  ON final_sensor_events USING btree (lat, lon);

