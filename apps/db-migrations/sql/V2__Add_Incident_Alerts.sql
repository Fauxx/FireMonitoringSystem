-- Create incident_alerts table used by ETL and /api/incidents
-- Matches the ETL structure where alerts are first filtered from raw Influx data.

CREATE TABLE IF NOT EXISTS incident_alerts (
  id SERIAL PRIMARY KEY,
  m VARCHAR(50) NOT NULL,          -- device id
  time TIMESTAMPTZ NOT NULL,       -- original event time

  -- sensor channels (B side used in ETL for alerting)
  fa NUMERIC,
  fb NUMERIC,
  ga NUMERIC,
  gb NUMERIC,
  sa NUMERIC,
  sb NUMERIC,
  ta NUMERIC,
  tb NUMERIC,

  -- new fields used by ETL logic
  ks INTEGER,
  ls INTEGER,
  k INTEGER,
  l INTEGER,
  alert_level INTEGER NOT NULL,    -- 0–3 as computed by ETL
  event_stage VARCHAR(50),         -- green / orange / confirmed
  started_at TIMESTAMPTZ,
  last_seen TIMESTAMPTZ,
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  host TEXT,
  a TEXT,
  o TEXT,

  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Ensure legacy tables get the new columns when already created
ALTER TABLE incident_alerts ADD COLUMN IF NOT EXISTS ks INTEGER;
ALTER TABLE incident_alerts ADD COLUMN IF NOT EXISTS ls INTEGER;
ALTER TABLE incident_alerts ADD COLUMN IF NOT EXISTS k INTEGER;
ALTER TABLE incident_alerts ADD COLUMN IF NOT EXISTS l INTEGER;
ALTER TABLE incident_alerts ADD COLUMN IF NOT EXISTS started_at TIMESTAMPTZ;
ALTER TABLE incident_alerts ADD COLUMN IF NOT EXISTS last_seen TIMESTAMPTZ;
ALTER TABLE incident_alerts ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE incident_alerts ADD COLUMN IF NOT EXISTS host TEXT;
ALTER TABLE incident_alerts ADD COLUMN IF NOT EXISTS a TEXT;
ALTER TABLE incident_alerts ADD COLUMN IF NOT EXISTS o TEXT;

-- Indexes for fast lookups
CREATE INDEX IF NOT EXISTS idx_incident_alerts_m_time
  ON incident_alerts (m, time DESC);
CREATE INDEX IF NOT EXISTS idx_incident_alerts_alert_level
  ON incident_alerts (alert_level);
CREATE INDEX IF NOT EXISTS idx_incident_alerts_last_seen
  ON incident_alerts (last_seen DESC);
