-- V16: Remove Lat/Lon from historical_fire_incidents to follow normalization pattern
-- Coordinate information is now joined from device_registry when needed.

ALTER TABLE historical_fire_incidents 
  DROP COLUMN IF EXISTS lat CASCADE,
  DROP COLUMN IF EXISTS lon CASCADE;
