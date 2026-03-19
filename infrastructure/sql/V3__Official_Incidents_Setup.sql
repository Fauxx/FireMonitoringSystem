-- Official Incidents Table Migration
-- This table stores complete incident records ready for BFP export

CREATE TABLE IF NOT EXISTS official_incidents (
  id SERIAL PRIMARY KEY,
  verified_incident_id INTEGER REFERENCES verified_incidents(id) ON DELETE CASCADE,
  device_id VARCHAR(50) NOT NULL,
  incident_timestamp TIMESTAMP NOT NULL,
  alert_level INTEGER NOT NULL,
  
  -- Sensor Data (from verified incident)
  flame_value NUMERIC,
  smoke_value NUMERIC,
  temp_value NUMERIC,
  
  -- BFP Required Fields
  incident_type VARCHAR(100),
  barangay VARCHAR(100),
  city VARCHAR(100),
  establishment_type VARCHAR(100),
  probable_cause TEXT,
  estimated_damage NUMERIC,
  responding_units TEXT,
  casualties_injured INTEGER DEFAULT 0,
  casualties_fatalities INTEGER DEFAULT 0,
  narrative_remarks TEXT,
  
  -- Audit Fields
  verified_by INTEGER REFERENCES users(id),
  verified_at TIMESTAMP,
  generated_by INTEGER REFERENCES users(id),
  generated_at TIMESTAMP DEFAULT NOW(),
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);

-- Create indexes for faster queries
CREATE INDEX IF NOT EXISTS idx_official_incidents_verified_id ON official_incidents(verified_incident_id);
CREATE INDEX IF NOT EXISTS idx_official_incidents_device_id ON official_incidents(device_id);
CREATE INDEX IF NOT EXISTS idx_official_incidents_timestamp ON official_incidents(incident_timestamp);
CREATE INDEX IF NOT EXISTS idx_official_incidents_generated_at ON official_incidents(generated_at);

-- Add comment to table
COMMENT ON TABLE official_incidents IS 'Complete incident records ready for BFP export with all required reporting fields';

