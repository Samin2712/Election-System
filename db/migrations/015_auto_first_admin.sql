-- Migration 015: Auto-promote first user to system admin
-- Makes the first registered user a system admin automatically

-- Make the first user (user_id = 1) a system admin
UPDATE user_accounts 
SET is_system_admin = TRUE 
WHERE user_id = (
    SELECT MIN(user_id) FROM user_accounts
)
AND is_system_admin = FALSE;  -- Only if not already admin

-- Log the result
DO $$
DECLARE
    v_admin_username VARCHAR(50);
    v_admin_email CITEXT;
BEGIN
    SELECT username, email INTO v_admin_username, v_admin_email
    FROM user_accounts
    WHERE is_system_admin = TRUE
    ORDER BY user_id
    LIMIT 1;
    
    IF FOUND THEN
        RAISE NOTICE 'System admin set: % (%)', v_admin_username, v_admin_email;
    ELSE
        RAISE NOTICE 'No users found - please register first user';
    END IF;
END $$;
