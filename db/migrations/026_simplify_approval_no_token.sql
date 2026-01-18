-- Migration 026: Simplify Approval Flow (Direct Add, No Token)
-- 1. Drop strict unique constraint ensuring we avoid "Duplicate Key" errors
-- 2. Update sp_approve_join_request to directly add user to org_members

BEGIN;

-- Ensure the restrictive constraint is dropped (Retrying this to be sure)
ALTER TABLE organization_join_requests
DROP CONSTRAINT IF EXISTS organization_join_requests_organization_id_user_id_status_key;

-- Ensure partial index exists for One Pending Request per user
CREATE UNIQUE INDEX IF NOT EXISTS idx_one_pending_request_per_user
ON organization_join_requests (organization_id, user_id)
WHERE status = 'PENDING';

-- Drop old function signature
DROP FUNCTION IF EXISTS sp_approve_join_request(INTEGER, BIGINT, VARCHAR(64));
DROP FUNCTION IF EXISTS sp_approve_join_request(BIGINT, BIGINT, VARCHAR(64));

-- Create new simplified function (No Token)
CREATE OR REPLACE FUNCTION sp_approve_join_request(
    p_request_id INTEGER,
    p_admin_user_id BIGINT
)
RETURNS TABLE (
    user_id BIGINT,
    username VARCHAR(50),
    email CITEXT,
    organization_name VARCHAR(200)
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_org_id BIGINT;
    v_user_id BIGINT;
    v_is_admin BOOLEAN;
    v_org_name VARCHAR(200);
BEGIN
    -- Get organization and user from request
    SELECT r.organization_id, r.user_id, o.organization_name
    INTO v_org_id, v_user_id, v_org_name
    FROM organization_join_requests r
    JOIN organizations o ON r.organization_id = o.organization_id
    WHERE r.request_id = p_request_id;

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

    -- 1. DIRECTLY ADD USER TO ORGANIZATION
    INSERT INTO org_members (organization_id, user_id, role_name, is_active)
    VALUES (v_org_id, v_user_id, 'MEMBER', TRUE)
    ON CONFLICT (organization_id, user_id)
    DO UPDATE SET is_active = TRUE, role_name = 'MEMBER';

    -- 2. UPDATE REQUEST STATUS TO APPROVED
    UPDATE organization_join_requests
    SET 
        status = 'APPROVED',
        approval_token = NULL, -- No token needed
        approved_by = p_admin_user_id,
        updated_at = NOW()
    WHERE request_id = p_request_id;

    -- 3. LOG ACTION
    INSERT INTO audit_logs (organization_id, user_id, action_type, entity_name, entity_id, details_json)
    VALUES (
        v_org_id,
        p_admin_user_id,
        'MEMBER_APPROVED',
        'org_members',
        v_user_id,
        jsonb_build_object('approved_user_id', v_user_id, 'method', 'direct_approval')
    );

    -- Return details for email notification
    RETURN QUERY
    SELECT 
        u.user_id,
        u.username,
        u.email::CITEXT,
        v_org_name
    FROM user_accounts u
    WHERE u.user_id = v_user_id;
END;
$$;

COMMIT;
