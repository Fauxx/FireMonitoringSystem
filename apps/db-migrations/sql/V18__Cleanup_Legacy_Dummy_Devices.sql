-- Remove legacy dummy devices that pollute the dashboard
DELETE FROM device_registry 
WHERE h_id IN ('node-001', 'TEST', 'node-normal', 'node-warning', 'node-critical');
