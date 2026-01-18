-- Migration 024: Fix approve and invite functions type mismatches and table references
BEGIN;

-- ============================================================
-- PART 1: Fix sp_approve_join_request type mismatches
-- ============================================================

DROP FUNCTION IF EXISTS sp_approve_join_request(BIGINT, BIGINT, VARCHAR(64));

CREATE FUNCTION sp_approve_join_request(
    p_request_id INTEGER,        -- SERIAL = INTEGER
    p_admin_user_id BIGINT,
    p_approval_token VARCHAR(64)
)
RETURNS TABLE (
    user_id BIGINT,
    username VARCHAR(50),        -- Match user_accounts.username
    email CITEXT,                -- Match user_accounts.email
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
    UPDATE organization_join_requests
    SET 
        status = 'APPROVED',
        approval_token = p_approval_token,
        approved_by = p_admin_user_id,
        updated_at = NOW()
    WHERE request_id = p_request_id;

    -- Return user details for notification
    RETURN QUERY
    SELECT 
        u.user_id,
        u.username,
        u.email,
        p_approval_token as token
    FROM user_accounts u
    WHERE u.user_id = v_user_id;
END;
$$;

-- ============================================================
-- PART 2: Fix organization_invites table to use BIGINT
-- ============================================================

-- Update organization_invites to use BIGINT
ALTER TABLE organization_invites 
  ALTER COLUMN organization_id TYPE BIGINT,
  ALTER COLUMN created_by TYPE BIGINT;

-- ============================================================
-- PART 3: Fix sp_create_invite to work with org_members
-- ============================================================

DROP FUNCTION IF EXISTS sp_create_invite(INTEGER, VARCHAR, VARCHAR, VARCHAR, INTEGER, INTEGER);

CREATE FUNCTION sp_create_invite(
    p_organization_id BIGINT,    -- Changed to BIGINT
    p_email VARCHAR,
    p_token VARCHAR,
    p_role_name VARCHAR,
    p_created_by BIGINT,         -- Changed to BIGINT
    p_days_valid INTEGER DEFAULT 7
) RETURNS INTEGER AS $$
DECLARE
    v_invite_id INTEGER;
    v_is_admin BOOLEAN;
BEGIN
    -- Check if creator is admin/owner using our is_org_admin function
    SELECT is_org_admin(p_created_by, p_organization_id) INTO v_is_admin;

    IF NOT v_is_admin THEN
        RAISE EXCEPTION 'Only OWNERS or ADMINS can send invites';
    END IF;

    -- Insert invite
    INSERT INTO organization_invites (
        organization_id, email, token, role_name, created_by, expires_at
    ) VALUES (
        p_organization_id, p_email, p_token, p_role_name, p_created_by, 
        CURRENT_TIMESTAMP + (p_days_valid::text || ' days')::INTERVAL
    )
    ON CONFLICT (organization_id, email) 
    DO UPDATE SET 
        token = EXCLUDED.token,
        status = 'PENDING',
        created_at = CURRENT_TIMESTAMP,
        expires_at = EXCLUDED.expires_at
    RETURNING invite_id INTO v_invite_id;

    RETURN v_invite_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- PART 4: Fix sp_accept_invite to use org_members instead of organization_members
-- ============================================================

DROP FUNCTION IF EXISTS sp_accept_invite(VARCHAR, INTEGER);

CREATE FUNCTION sp_accept_invite(
    p_token VARCHAR,
    p_user_id BIGINT             -- Changed to BIGINT
) RETURNS TABLE (
    organization_id BIGINT,      -- Changed to BIGINT
    organization_name VARCHAR(200),  -- Match organizations table
    role_name TEXT               -- Changed to TEXT to match org_members
) AS $$
DECLARE
    v_invite RECORD;
BEGIN
    -- Find valid invite
    SELECT * INTO v_invite
    FROM organization_invites
    WHERE token = p_token 
    AND status = 'PENDING'
    AND expires_at > CURRENT_TIMESTAMP;

    IF v_invite IS NULL THEN
        RAISE EXCEPTION 'Invalid or expired invite token';
    END IF;

    -- Add user to organization using org_members (not organization_members)
    INSERT INTO org_members (organization_id, user_id, role_name, is_active)
    VALUES (v_invite.organization_id, p_user_id, v_invite.role_name, TRUE)
    ON CONFLICT (organization_id, user_id) 
    DO UPDATE SET role_name = EXCLUDED.role_name, is_active = TRUE;

    -- Update invite status
    UPDATE organization_invites 
    SET status = 'ACCEPTED' 
    WHERE invite_id = v_invite.invite_id;

    -- Return info
    RETURN QUERY
    SELECT o.organization_id, o.organization_name, v_invite.role_name::TEXT
    FROM organizations o
    WHERE o.organization_id = v_invite.organization_id;
END;
$$ LANGUAGE plpgsql;

COMMIT;
