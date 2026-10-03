-- V13: Add Advanced KPIs and Metrics to Historical Fire Incidents

ALTER TABLE historical_fire_incidents 
ADD COLUMN IF NOT EXISTS avg_temperature_c NUMERIC(10, 2) DEFAULT 0,
ADD COLUMN IF NOT EXISTS avg_smoke_ppm NUMERIC(10, 2) DEFAULT 0,
ADD COLUMN IF NOT EXISTS avg_flame_intensity NUMERIC(10, 2) DEFAULT 0,
ADD COLUMN IF NOT EXISTS readings_count INTEGER DEFAULT 0;
