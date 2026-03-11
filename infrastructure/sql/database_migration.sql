-- Database Migration Script
-- Run this script to add required tables and columns

-- 1. Add status column to users table
ALTER TABLE users ADD COLUMN IF NOT EXISTS status VARCHAR(20) DEFAULT 'pending';

-- Update ALL existing users to 'approved' (including those that were just created)
UPDATE users SET status = 'approved';

-- 2. Create verified_incidents table
CREATE TABLE IF NOT EXISTS verified_incidents (
  id SERIAL PRIMARY KEY,
  device_id VARCHAR(50) NOT NULL,
  timestamp TIMESTAMP NOT NULL,
  alert_level INTEGER NOT NULL,
  flame_value NUMERIC,
  smoke_value NUMERIC,
  temp_value NUMERIC,
  verified_by INTEGER REFERENCES users(id),
  verified_at TIMESTAMP DEFAULT NOW(),
  notes TEXT,
  created_at TIMESTAMP DEFAULT NOW()
);

-- Create index for faster queries
CREATE INDEX IF NOT EXISTS idx_verified_incidents_device_id ON verified_incidents(device_id);
CREATE INDEX IF NOT EXISTS idx_verified_incidents_timestamp ON verified_incidents(timestamp);
CREATE INDEX IF NOT EXISTS idx_users_status ON users(status);

-- 3. Create sensor_data_aggregated table for ETL rollups
CREATE TABLE IF NOT EXISTS sensor_data_aggregated (
  id SERIAL PRIMARY KEY,
  m VARCHAR(50) NOT NULL,
  timestamp_window TIMESTAMPTZ NOT NULL,
  alert_level INTEGER,
  event_stage VARCHAR(50),
  host TEXT,
  a TEXT,
  o TEXT,
  fa NUMERIC,
  fb NUMERIC,
  ga NUMERIC,
  gb NUMERIC,
  sa NUMERIC,
  sb NUMERIC,
  ta NUMERIC,
  tb NUMERIC,
  ks INTEGER,
  ls INTEGER,
  k INTEGER,
  l INTEGER,
  la NUMERIC,
  lo NUMERIC,
  readings_count INTEGER,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_sensor_data_aggregated_m_window
  ON sensor_data_aggregated (m, timestamp_window DESC);

-- 4. Create system_metrics table for ETL heartbeat/status
CREATE TABLE IF NOT EXISTS system_metrics (
  id SERIAL PRIMARY KEY,
  timestamp TIMESTAMPTZ NOT NULL,
  active_devices INTEGER DEFAULT 0,
  alerts_today INTEGER DEFAULT 0,
  system_uptime NUMERIC,
  total_locations INTEGER DEFAULT 0,
  status_level INTEGER DEFAULT 1,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_system_metrics_timestamp
  ON system_metrics (timestamp DESC);
