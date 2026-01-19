-- Migration 032: Fix column ambiguity in sp_approve_join_request
-- Rename output columns to avoid collision with table column names

BEGIN;

DROP FUNCTION IF EXISTS sp_approve_join_request(INTEGER, BIGINT);

CREATE OR REPLACE FUNCTION sp_approve_join_request(
    p_request_id INTEGER,
    p_admin_user_id BIGINT
)
RETURNS TABLE (
    out_user_id BIGINT,
    out_username VARCHAR(50),
    out_email CITEXT,
    out_organization_name VARCHAR(200)
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_org_id BIGINT;
    v_user_id BIGINT;
    v_is_admin BOOLEAN;
    v_org_name VARCHAR(200);
BEGIN
    -- 1. Get organization and user from request (Use aliases to be safe)
    SELECT r.organization_id, r.user_id, o.organization_name
    INTO v_org_id, v_user_id, v_org_name
    FROM organization_join_requests r
    JOIN organizations o ON r.organization_id = o.organization_id
    WHERE r.request_id = p_request_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Join request not found'
            USING ERRCODE = '22023';
    END IF;

    -- 2. Check if approving user is admin for this org
    SELECT is_org_admin(p_admin_user_id, v_org_id) INTO v_is_admin;
    
    IF NOT v_is_admin THEN
        RAISE EXCEPTION 'Not authorized to approve join requests'
            USING ERRCODE = '28000';
    END IF;

    -- 3. DIRECTLY ADD USER TO ORGANIZATION (Member role)
    -- Using explicit table name to avoid any ambiguity
    INSERT INTO public.org_members (organization_id, user_id, role_name, is_active)
    VALUES (v_org_id, v_user_id, 'MEMBER', TRUE)
    ON CONFLICT (organization_id, user_id)
    DO UPDATE SET is_active = TRUE, role_name = 'MEMBER';

    -- 4. UPDATE REQUEST STATUS TO APPROVED
    UPDATE organization_join_requests
    SET 
        status = 'APPROVED',
        approval_token = NULL,
        approved_by = p_admin_user_id,
        updated_at = NOW()
    WHERE request_id = p_request_id;

    -- 5. LOG ACTION
    INSERT INTO audit_logs (organization_id, user_id, action_type, entity_name, entity_id, details_json)
    VALUES (
        v_org_id,
        p_admin_user_id,
        'MEMBER_APPROVED',
        'org_members',
        v_user_id,
        jsonb_build_object('approved_user_id', v_user_id, 'method', 'direct_approval')
    );

    -- 6. RETURN USER DETAILS
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
