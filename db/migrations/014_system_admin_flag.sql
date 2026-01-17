-- Migration 014: Simple System Admin Flag
-- Adds is_system_admin flag to user_accounts table

-- Add is_system_admin column to user_accounts
ALTER TABLE user_accounts 
ADD COLUMN IF NOT EXISTS is_system_admin BOOLEAN DEFAULT FALSE;

-- Create index for quick lookups
CREATE INDEX IF NOT EXISTS idx_user_accounts_system_admin 
ON user_accounts(is_system_admin) WHERE is_system_admin = TRUE;

-- Drop old function from migration 013 if exists
DROP FUNCTION IF EXISTS is_system_admin(BIGINT);

-- Create new function to check if user is system admin
CREATE OR REPLACE FUNCTION is_system_admin(p_user_id BIGINT)
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_is_admin BOOLEAN;
BEGIN
    SELECT is_system_admin INTO v_is_admin
    FROM user_accounts
    WHERE user_id = p_user_id;
    
    RETURN COALESCE(v_is_admin, FALSE);
END;
$$;

COMMENT ON COLUMN user_accounts.is_system_admin IS 'TRUE if user has system-wide admin privileges';

-- Example: Make first user a system admin (uncomment to use)
-- UPDATE user_accounts SET is_system_admin = TRUE WHERE user_id = 1;
