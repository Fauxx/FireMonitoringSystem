-- V15: Recreate legacy views referencing the normalized schema
CREATE OR REPLACE VIEW final_sensor_latest AS
SELECT 
    e.id, 
    e.h_id, 
    e.status, 
    d.lat, 
    d.lon, 
    e.received_at
FROM final_sensor_events e
JOIN device_registry d ON e.h_id = d.h_id
WHERE e.id IN (
    SELECT MAX(id) FROM final_sensor_events GROUP BY h_id
);
