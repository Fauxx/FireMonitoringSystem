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

