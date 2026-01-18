-- Migration 025: Fix Unique Constraint on Join Requests
-- Drop the overly restrictive constraint that prevents duplicate statuses (e.g. multiple REJECTED history)
-- Enforce only ONE 'PENDING' request per user per org

BEGIN;

-- 1. Drop the existing unique constraint
ALTER TABLE organization_join_requests
DROP CONSTRAINT IF EXISTS organization_join_requests_organization_id_user_id_status_key;

-- 2. Add a partial unique index to ensure only one PENDING request at a time
CREATE UNIQUE INDEX IF NOT EXISTS idx_one_pending_request_per_user
ON organization_join_requests (organization_id, user_id)
WHERE status = 'PENDING';

-- 3. Fix sp_approve_join_request return types to be absolutely safe with casting
-- Make sure email is cast to TEXT then CITEXT if needed, or just CITEXT
DROP FUNCTION IF EXISTS sp_approve_join_request(INTEGER, BIGINT, VARCHAR(64));

CREATE FUNCTION sp_approve_join_request(
    p_request_id INTEGER,
    p_admin_user_id BIGINT,
    p_approval_token VARCHAR(64)
)
RETURNS TABLE (
    user_id BIGINT,
    username VARCHAR(50),
    email CITEXT,
    token VARCHAR(64)
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_org_id BIGINT;
    v_user_id BIGINT;
    v_is_admin BOOLEAN;
BEGIN
    -- Get organization and user from request
    SELECT organization_id, r.user_id
    INTO v_org_id, v_user_id
    FROM organization_join_requests r
    WHERE request_id = p_request_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Join request not found'
            USING ERRCODE = '22023';
    END IF;

    -- Check if requesting user is admin/owner
    SELECT is_org_admin(p_admin_user_id, v_org_id) INTO v_is_admin;
    
    IF NOT v_is_admin THEN
        RAISE EXCEPTION 'Not authorized to approve join requests'
            USING ERRCODE = '28000';
    END IF;

    -- Update request with approval token
    -- Note: This might create a second APPROVED row for the same user/org, which uses audit history
    UPDATE organization_join_requests
    SET 
        status = 'APPROVED',
        approval_token = p_approval_token,
        approved_by = p_admin_user_id,
        updated_at = NOW()
    WHERE request_id = p_request_id;

    -- Return user details
    RETURN QUERY
    SELECT 
        u.user_id,
        u.username,
        u.email::CITEXT,  -- Explicit cast
        p_approval_token::VARCHAR(64) as token
    FROM user_accounts u
    WHERE u.user_id = v_user_id;
END;
$$;

COMMIT;
