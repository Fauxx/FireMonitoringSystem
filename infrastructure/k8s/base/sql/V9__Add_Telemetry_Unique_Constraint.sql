-- V9: Prevent telemetry duplication
-- Add unique constraint on final_sensor_events to prevent duplicate rows for the same device at the same timestamp.

ALTER TABLE final_sensor_events 
  ADD CONSTRAINT unique_device_reading UNIQUE (h_id, received_at);
