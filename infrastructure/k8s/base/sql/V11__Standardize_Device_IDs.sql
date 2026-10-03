-- V11: Standardize Device IDs and add Foreign Keys

-- 1. Add owner_id to device_registry
ALTER TABLE device_registry ADD COLUMN IF NOT EXISTS owner_id INTEGER REFERENCES users(id) ON DELETE SET NULL;

-- 2. Rename 'm' to 'h_id' in legacy tables
DO $$ 
BEGIN
  IF EXISTS(SELECT * FROM information_schema.columns WHERE table_name='sensor_data_aggregated' and column_name='m') THEN
    ALTER TABLE sensor_data_aggregated RENAME COLUMN m TO h_id;
  END IF;
  
  IF EXISTS(SELECT * FROM information_schema.columns WHERE table_name='incident_alerts' and column_name='m') THEN
    ALTER TABLE incident_alerts RENAME COLUMN m TO h_id;
  END IF;
  
  IF EXISTS(SELECT * FROM information_schema.columns WHERE table_name='verified_incidents' and column_name='device_id') THEN
    ALTER TABLE verified_incidents RENAME COLUMN device_id TO h_id;
  END IF;

  IF EXISTS(SELECT * FROM information_schema.columns WHERE table_name='official_incidents' and column_name='device_id') THEN
    ALTER TABLE official_incidents RENAME COLUMN device_id TO h_id;
  END IF;
END $$;

-- 3. Insert any unknown h_ids into device_registry before adding constraints
INSERT INTO device_registry (h_id, owner_name)
SELECT DISTINCT id_col, 'Unknown Device' 
FROM (
  SELECT h_id as id_col FROM sensor_data_aggregated WHERE h_id IS NOT NULL
  UNION
  SELECT h_id FROM incident_alerts WHERE h_id IS NOT NULL
  UNION
  SELECT h_id FROM verified_incidents WHERE h_id IS NOT NULL
  UNION
  SELECT h_id FROM official_incidents WHERE h_id IS NOT NULL
  UNION
  SELECT h_id FROM final_sensor_events WHERE h_id IS NOT NULL
  UNION
  SELECT h_id FROM historical_fire_incidents WHERE h_id IS NOT NULL
) as all_ids
WHERE id_col NOT IN (SELECT h_id FROM device_registry);

-- 4. Add Foreign Keys to ensure referential integrity
ALTER TABLE sensor_data_aggregated 
  DROP CONSTRAINT IF EXISTS fk_sda_hid,
  ADD CONSTRAINT fk_sda_hid FOREIGN KEY (h_id) REFERENCES device_registry(h_id) ON DELETE CASCADE;

ALTER TABLE incident_alerts 
  DROP CONSTRAINT IF EXISTS fk_ia_hid,
  ADD CONSTRAINT fk_ia_hid FOREIGN KEY (h_id) REFERENCES device_registry(h_id) ON DELETE CASCADE;

ALTER TABLE verified_incidents 
  DROP CONSTRAINT IF EXISTS fk_vi_hid,
  ADD CONSTRAINT fk_vi_hid FOREIGN KEY (h_id) REFERENCES device_registry(h_id) ON DELETE CASCADE;

ALTER TABLE official_incidents 
  DROP CONSTRAINT IF EXISTS fk_oi_hid,
  ADD CONSTRAINT fk_oi_hid FOREIGN KEY (h_id) REFERENCES device_registry(h_id) ON DELETE CASCADE;

ALTER TABLE final_sensor_events 
  DROP CONSTRAINT IF EXISTS fk_fse_hid,
  ADD CONSTRAINT fk_fse_hid FOREIGN KEY (h_id) REFERENCES device_registry(h_id) ON DELETE CASCADE;

ALTER TABLE historical_fire_incidents 
  DROP CONSTRAINT IF EXISTS fk_hfi_hid,
  ADD CONSTRAINT fk_hfi_hid FOREIGN KEY (h_id) REFERENCES device_registry(h_id) ON DELETE CASCADE;
