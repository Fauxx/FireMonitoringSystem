-- Seed simulated devices to satisfy foreign key constraints during simulation testing
INSERT INTO device_registry (h_id, owner_name, contact_number, barangay, address_text, structure_type)
VALUES 
    ('node-sim-01', 'Simulator 1', 'N/A', 'Brgy. Simulated', 'Virtual Node 01', 'Test/Dev'),
    ('node-sim-02', 'Simulator 2', 'N/A', 'Brgy. Simulated', 'Virtual Node 02', 'Test/Dev'),
    ('node-sim-03', 'Simulator 3', 'N/A', 'Brgy. Simulated', 'Virtual Node 03', 'Test/Dev'),
    ('node-sim-04', 'Simulator 4', 'N/A', 'Brgy. Simulated', 'Virtual Node 04', 'Test/Dev'),
    ('node-sim-05', 'Simulator 5', 'N/A', 'Brgy. Simulated', 'Virtual Node 05', 'Test/Dev'),
    ('node-sim-06', 'Simulator 6', 'N/A', 'Brgy. Simulated', 'Virtual Node 06', 'Test/Dev'),
    ('node-sim-07', 'Simulator 7', 'N/A', 'Brgy. Simulated', 'Virtual Node 07', 'Test/Dev'),
    ('node-sim-08', 'Simulator 8', 'N/A', 'Brgy. Simulated', 'Virtual Node 08', 'Test/Dev'),
    ('node-sim-09', 'Simulator 9', 'N/A', 'Brgy. Simulated', 'Virtual Node 09', 'Test/Dev'),
    ('node-sim-10', 'Simulator 10', 'N/A', 'Brgy. Simulated', 'Virtual Node 10', 'Test/Dev')
ON CONFLICT (h_id) DO NOTHING;
