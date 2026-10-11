-- V12: Add GPS coordinates to Device Registry for Stateful Frontend Maps

ALTER TABLE device_registry 
ADD COLUMN IF NOT EXISTS lat NUMERIC(10, 6),
ADD COLUMN IF NOT EXISTS lon NUMERIC(10, 6);

-- Add some default coordinates for our simulated devices so the map doesn't break
UPDATE device_registry SET lat = 14.5995, lon = 121.0365 WHERE h_id = 'FMS-V1-0001';
UPDATE device_registry SET lat = 14.6010, lon = 121.0380 WHERE h_id = 'FMS-V1-0002';
UPDATE device_registry SET lat = 14.5980, lon = 121.0350 WHERE h_id = 'FMS-V1-0003';
