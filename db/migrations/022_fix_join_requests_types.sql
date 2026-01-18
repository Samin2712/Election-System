-- Migration 022: Fix sp_get_pending_join_requests type mismatch
-- The function's RETURN TABLE columns must match the query result types exactly

BEGIN;

-- Drop and recreate sp_get_pending_join_requests with matching types
DROP FUNCTION IF EXISTS sp_get_pending_join_requests(BIGINT, BIGINT);

CREATE FUNCTION sp_get_pending_join_requests(
    p_organization_id BIGINT,
    p_admin_user_id BIGINT
)
RETURNS TABLE (
    request_id INTEGER,          -- Changed from BIGINT to match SERIAL
    user_id BIGINT,
    username VARCHAR(100),
    email VARCHAR(255),
    request_message TEXT,
    created_at TIMESTAMPTZ       -- Changed from TIMESTAMP to TIMESTAMPTZ
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
        r.request_id::INTEGER,
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
