-- Migration 023: Fix sp_get_pending_join_requests with correct column types
-- Match the exact types from organization_join_requests and user_accounts tables

BEGIN;

-- Drop the function to recreate with correct types
DROP FUNCTION IF EXISTS sp_get_pending_join_requests(BIGINT, BIGINT);

CREATE FUNCTION sp_get_pending_join_requests(
    p_organization_id BIGINT,
    p_admin_user_id BIGINT
)
RETURNS TABLE (
    request_id INTEGER,          -- SERIAL = INTEGER
    user_id BIGINT,              -- BIGINT
    username VARCHAR(50),        -- VARCHAR(50) from user_accounts
    email CITEXT,                -- CITEXT from user_accounts
    request_message TEXT,        -- TEXT
    created_at TIMESTAMP         -- TIMESTAMP (not TIMESTAMPTZ)
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_is_admin BOOLEAN;
BEGIN
    -- Check if requesting user is admin/owner
    SELECT is_org_admin(p_admin_user_id, p_organization_id) INTO v_is_admin;
    
    IF NOT v_is_admin THEN
        RAISE EXCEPTION 'Not authorized to view join requests'
            USING ERRCODE = '28000';
    END IF;

    RETURN QUERY
    SELECT 
        r.request_id,
        r.user_id,
        u.username,
        u.email,
        r.request_message,
        r.created_at
    FROM organization_join_requests r
    JOIN user_accounts u ON r.user_id = u.user_id
    WHERE r.organization_id = p_organization_id
    AND r.status = 'PENDING'
    ORDER BY r.created_at DESC;
END;
$$;

COMMIT;
