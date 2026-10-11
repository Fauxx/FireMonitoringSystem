CREATE TABLE IF NOT EXISTS device_registry (
    h_id VARCHAR(50) PRIMARY KEY,
    owner_name VARCHAR(100),
    contact_number VARCHAR(20),
    barangay VARCHAR(100),
    address_text TEXT,
    structure_type VARCHAR(50),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Insert a mock/test device so the UI has something to show for node-001 or others
INSERT INTO device_registry (h_id, owner_name, contact_number, barangay, address_text, structure_type)
VALUES ('node-001', 'Juan Dela Cruz', '0917-123-4567', 'Brgy. 143', '123 Rizal Ave, near Chapel', 'Residential (Light Materials)')
ON CONFLICT (h_id) DO NOTHING;
