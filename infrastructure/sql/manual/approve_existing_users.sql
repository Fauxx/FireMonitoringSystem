-- Script to approve all existing users in the database
-- Run this script to set all current users to 'approved' status

UPDATE users SET status = 'approved' WHERE status IS NULL OR status = 'pending';

-- Verify the update
SELECT id, username, email, role, status FROM users ORDER BY created_at DESC;

