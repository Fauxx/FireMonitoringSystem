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

  alert_level INTEGER NOT NULL,    -- 0–3 as computed by ETL
  event_stage VARCHAR(50),         -- green / pre-alert / confirmed

  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for fast lookups
CREATE INDEX IF NOT EXISTS idx_incident_alerts_m_time
  ON incident_alerts (m, time DESC);

CREATE INDEX IF NOT EXISTS idx_incident_alerts_alert_level
  ON incident_alerts (alert_level);


