-- Fix type mismatch: organization_id is BIGINT, not INTEGER
-- Migration: 048_fix_invitation_types.sql

-- Drop existing functions first (required when changing return types)
DROP FUNCTION IF EXISTS sp_validate_invite_token(VARCHAR);
DROP FUNCTION IF EXISTS sp_create_bulk_invite(INTEGER, VARCHAR, VARCHAR, VARCHAR, INTEGER, INTEGER, INTEGER);
DROP FUNCTION IF EXISTS sp_create_bulk_invite(BIGINT, VARCHAR, VARCHAR, VARCHAR, BIGINT, BIGINT, INTEGER);
DROP FUNCTION IF EXISTS sp_accept_invite_existing_user(VARCHAR, INTEGER);
DROP FUNCTION IF EXISTS sp_accept_invite_existing_user(VARCHAR, BIGINT);
DROP FUNCTION IF EXISTS sp_register_with_invite(VARCHAR, VARCHAR, VARCHAR, VARCHAR);
DROP FUNCTION IF EXISTS sp_get_org_pending_invites(INTEGER, INTEGER);
DROP FUNCTION IF EXISTS sp_get_org_pending_invites(BIGINT, BIGINT);
DROP FUNCTION IF EXISTS sp_resend_invite(INTEGER, INTEGER);
DROP FUNCTION IF EXISTS sp_resend_invite(BIGINT, BIGINT);
DROP FUNCTION IF EXISTS sp_revoke_invite(INTEGER, INTEGER);
DROP FUNCTION IF EXISTS sp_revoke_invite(BIGINT, BIGINT);

-- Fix sp_validate_invite_token - change INTEGER to BIGINT where needed
CREATE OR REPLACE FUNCTION sp_validate_invite_token(
    p_token VARCHAR
) RETURNS TABLE (
    valid BOOLEAN,
    invite_id BIGINT,
    email VARCHAR,
    organization_id BIGINT,
    organization_name VARCHAR,
    role_name VARCHAR,
    expires_at TIMESTAMP WITH TIME ZONE,
    user_exists BOOLEAN,
    user_id BIGINT
) AS $$
DECLARE
    v_invite RECORD;
    v_user_id BIGINT;
BEGIN
    -- Find the invite
    SELECT 
        oi.invite_id,
        oi.email,
        oi.organization_id,
        o.organization_name,
        oi.role_name,
        oi.expires_at,
        oi.status
    INTO v_invite
    FROM organization_invites oi
    JOIN organizations o ON oi.organization_id = o.organization_id
    WHERE oi.token = p_token;
    
    -- Token not found
    IF v_invite IS NULL THEN
        RETURN QUERY SELECT 
            FALSE, NULL::BIGINT, NULL::VARCHAR, NULL::BIGINT, 
            NULL::VARCHAR, NULL::VARCHAR, NULL::TIMESTAMP WITH TIME ZONE, FALSE, NULL::BIGINT;
        RETURN;
    END IF;
    
    -- Check if expired or not pending
    IF v_invite.status != 'PENDING' OR v_invite.expires_at < CURRENT_TIMESTAMP THEN
        RETURN QUERY SELECT 
            FALSE, v_invite.invite_id::BIGINT, v_invite.email::VARCHAR, v_invite.organization_id::BIGINT,
            v_invite.organization_name::VARCHAR, v_invite.role_name::VARCHAR, v_invite.expires_at, FALSE, NULL::BIGINT;
        RETURN;
    END IF;
    
    -- Check if user exists
    SELECT ua.user_id INTO v_user_id
    FROM user_accounts ua
    WHERE ua.email = v_invite.email;
    
    RETURN QUERY SELECT 
        TRUE,
        v_invite.invite_id::BIGINT,
        v_invite.email::VARCHAR,
        v_invite.organization_id::BIGINT,
        v_invite.organization_name::VARCHAR,
        v_invite.role_name::VARCHAR,
        v_invite.expires_at,
        v_user_id IS NOT NULL,
        v_user_id;
END;
$$ LANGUAGE plpgsql;

-- Fix sp_create_bulk_invite
CREATE OR REPLACE FUNCTION sp_create_bulk_invite(
    p_organization_id BIGINT,
    p_email VARCHAR,
    p_token VARCHAR,
    p_role_name VARCHAR,
    p_created_by BIGINT,
    p_batch_id BIGINT,
    p_days_valid INTEGER DEFAULT 7
) RETURNS TABLE (
    invite_id BIGINT,
    status VARCHAR,
    message VARCHAR
) AS $$
DECLARE
    v_invite_id BIGINT;
    v_user_role TEXT;
    v_existing_member BOOLEAN;
BEGIN
    -- Check if creator is admin/owner (org_members uses role_name directly)
    SELECT om.role_name INTO v_user_role
    FROM org_members om
    WHERE om.organization_id = p_organization_id AND om.user_id = p_created_by;

    IF v_user_role NOT IN ('OWNER', 'ADMIN') THEN
        RETURN QUERY SELECT NULL::BIGINT, 'ERROR'::VARCHAR, 'Only OWNERS or ADMINS can send invites'::VARCHAR;
        RETURN;
    END IF;
    
    -- Check if user is already a member
    SELECT EXISTS (
        SELECT 1 FROM org_members om
        JOIN user_accounts ua ON om.user_id = ua.user_id
        WHERE om.organization_id = p_organization_id AND ua.email = p_email
    ) INTO v_existing_member;
    
    IF v_existing_member THEN
        RETURN QUERY SELECT NULL::BIGINT, 'SKIPPED'::VARCHAR, 'User is already a member'::VARCHAR;
        RETURN;
    END IF;

    -- Insert or update invite
    INSERT INTO organization_invites (
        organization_id, email, token, role_name, created_by, expires_at, batch_id, status
    ) VALUES (
        p_organization_id, p_email, p_token, p_role_name, p_created_by, 
        CURRENT_TIMESTAMP + (p_days_valid::text || ' days')::INTERVAL,
        p_batch_id, 'PENDING'
    )
    ON CONFLICT (organization_id, email) 
    DO UPDATE SET 
        token = EXCLUDED.token,
        status = 'PENDING',
        created_at = CURRENT_TIMESTAMP,
        expires_at = EXCLUDED.expires_at,
        batch_id = EXCLUDED.batch_id,
        email_sent = FALSE,
        email_sent_at = NULL
    RETURNING organization_invites.invite_id INTO v_invite_id;

    RETURN QUERY SELECT v_invite_id, 'SUCCESS'::VARCHAR, 'Invite created successfully'::VARCHAR;
END;
$$ LANGUAGE plpgsql;

-- Fix sp_accept_invite_existing_user
CREATE OR REPLACE FUNCTION sp_accept_invite_existing_user(
    p_token VARCHAR,
    p_user_id BIGINT
) RETURNS TABLE (
    success BOOLEAN,
    organization_id BIGINT,
    organization_name VARCHAR,
    role_name VARCHAR,
    message VARCHAR
) AS $$
DECLARE
    v_invite RECORD;
    v_user_email VARCHAR;
BEGIN
    -- Get user email
    SELECT email INTO v_user_email FROM user_accounts WHERE user_id = p_user_id;
    
    -- Find valid invite
    SELECT 
        oi.invite_id,
        oi.email,
        oi.organization_id,
        o.organization_name,
        oi.role_name,
        oi.status,
        oi.expires_at
    INTO v_invite
    FROM organization_invites oi
    JOIN organizations o ON oi.organization_id = o.organization_id
    WHERE oi.token = p_token 
    AND oi.status = 'PENDING'
    AND oi.expires_at > CURRENT_TIMESTAMP;
    
    IF v_invite IS NULL THEN
        RETURN QUERY SELECT FALSE, NULL::BIGINT, NULL::VARCHAR, NULL::VARCHAR, 'Invalid or expired invite token'::VARCHAR;
        RETURN;
    END IF;
    
    -- Verify email matches
    IF v_invite.email != v_user_email THEN
        RETURN QUERY SELECT FALSE, NULL::BIGINT, NULL::VARCHAR, NULL::VARCHAR, 'This invitation was sent to a different email address'::VARCHAR;
        RETURN;
    END IF;

    -- Add user to organization (using role_name directly, not role_id)
    INSERT INTO org_members (organization_id, user_id, role_name, is_active)
    VALUES (v_invite.organization_id, p_user_id, v_invite.role_name, TRUE)
    ON CONFLICT (organization_id, user_id) DO NOTHING;

    -- Update invite status
    UPDATE organization_invites 
    SET status = 'ACCEPTED' 
    WHERE organization_invites.invite_id = v_invite.invite_id;

    RETURN QUERY SELECT 
        TRUE, 
        v_invite.organization_id::BIGINT, 
        v_invite.organization_name::VARCHAR, 
        v_invite.role_name::VARCHAR,
        'Successfully joined organization'::VARCHAR;
END;
$$ LANGUAGE plpgsql;

-- Fix sp_register_with_invite
CREATE OR REPLACE FUNCTION sp_register_with_invite(
    p_username VARCHAR,
    p_email VARCHAR,
    p_password_hash VARCHAR,
    p_token VARCHAR
) RETURNS TABLE (
    user_id BIGINT,
    organization_id BIGINT,
    organization_name VARCHAR,
    role_name VARCHAR,
    success BOOLEAN,
    message VARCHAR
) AS $$
DECLARE
    v_invite RECORD;
    v_user_id BIGINT;
    v_default_role_id INTEGER;
BEGIN
    -- Find valid invite
    SELECT 
        oi.invite_id,
        oi.email,
        oi.organization_id,
        o.organization_name,
        oi.role_name,
        oi.status,
        oi.expires_at
    INTO v_invite
    FROM organization_invites oi
    JOIN organizations o ON oi.organization_id = o.organization_id
    WHERE oi.token = p_token 
    AND oi.status = 'PENDING'
    AND oi.expires_at > CURRENT_TIMESTAMP;
    
    IF v_invite IS NULL THEN
        RETURN QUERY SELECT NULL::BIGINT, NULL::BIGINT, NULL::VARCHAR, NULL::VARCHAR, FALSE, 'Invalid or expired invite token'::VARCHAR;
        RETURN;
    END IF;
    
    -- Verify email matches
    IF v_invite.email != p_email THEN
        RETURN QUERY SELECT NULL::BIGINT, NULL::BIGINT, NULL::VARCHAR, NULL::VARCHAR, FALSE, 'Email does not match invitation'::VARCHAR;
        RETURN;
    END IF;
    
    -- Get default role for user accounts
    SELECT r.role_id INTO v_default_role_id FROM roles r WHERE r.role_name = 'USER';
    
    -- Create user account
    INSERT INTO user_accounts (username, email, password_hash, role_id, is_active)
    VALUES (p_username, p_email, p_password_hash, v_default_role_id, TRUE)
    RETURNING user_accounts.user_id INTO v_user_id;
    
    -- Add user to organization (using role_name directly)
    INSERT INTO org_members (organization_id, user_id, role_name, is_active)
    VALUES (v_invite.organization_id, v_user_id, v_invite.role_name, TRUE);
    
    -- Update invite status
    UPDATE organization_invites 
    SET status = 'ACCEPTED' 
    WHERE organization_invites.invite_id = v_invite.invite_id;
    
    RETURN QUERY SELECT 
        v_user_id, 
        v_invite.organization_id::BIGINT, 
        v_invite.organization_name::VARCHAR, 
        v_invite.role_name::VARCHAR,
        TRUE,
        'Registration successful'::VARCHAR;
END;
$$ LANGUAGE plpgsql;

-- Fix sp_get_org_pending_invites
CREATE OR REPLACE FUNCTION sp_get_org_pending_invites(
    p_organization_id BIGINT,
    p_user_id BIGINT
) RETURNS TABLE (
    invite_id BIGINT,
    email VARCHAR,
    role_name VARCHAR,
    status VARCHAR,
    created_at TIMESTAMP WITH TIME ZONE,
    expires_at TIMESTAMP WITH TIME ZONE,
    email_sent BOOLEAN,
    email_sent_at TIMESTAMP WITH TIME ZONE
) AS $$
DECLARE
    v_user_role TEXT;
BEGIN
    -- Check if user is admin/owner (using role_name directly)
    SELECT om.role_name INTO v_user_role
    FROM org_members om
    WHERE om.organization_id = p_organization_id AND om.user_id = p_user_id;

    IF v_user_role NOT IN ('OWNER', 'ADMIN') THEN
        RAISE EXCEPTION 'Not authorized to view invites' USING ERRCODE = '28000';
    END IF;

    RETURN QUERY 
    SELECT 
        oi.invite_id,
        oi.email,
        oi.role_name,
        oi.status,
        oi.created_at,
        oi.expires_at,
        COALESCE(oi.email_sent, FALSE),
        oi.email_sent_at
    FROM organization_invites oi
    WHERE oi.organization_id = p_organization_id
    ORDER BY oi.created_at DESC;
END;
$$ LANGUAGE plpgsql;

-- Fix sp_resend_invite
CREATE OR REPLACE FUNCTION sp_resend_invite(
    p_invite_id BIGINT,
    p_user_id BIGINT
) RETURNS TABLE (
    email VARCHAR,
    token VARCHAR,
    organization_name VARCHAR,
    expires_at TIMESTAMP WITH TIME ZONE
) AS $$
DECLARE
    v_invite RECORD;
    v_user_role TEXT;
    v_new_token VARCHAR;
BEGIN
    -- Get invite details
    SELECT 
        oi.invite_id,
        oi.email,
        oi.organization_id,
        o.organization_name,
        oi.token
    INTO v_invite
    FROM organization_invites oi
    JOIN organizations o ON oi.organization_id = o.organization_id
    WHERE oi.invite_id = p_invite_id;
    
    IF v_invite IS NULL THEN
        RAISE EXCEPTION 'Invite not found';
    END IF;
    
    -- Check permissions (using role_name directly)
    SELECT om.role_name INTO v_user_role
    FROM org_members om
    WHERE om.organization_id = v_invite.organization_id AND om.user_id = p_user_id;

    IF v_user_role NOT IN ('OWNER', 'ADMIN') THEN
        RAISE EXCEPTION 'Not authorized to resend invites' USING ERRCODE = '28000';
    END IF;
    
    -- Generate new token and reset expiry
    v_new_token := encode(gen_random_bytes(16), 'hex');
    
    UPDATE organization_invites 
    SET 
        token = v_new_token,
        status = 'PENDING',
        expires_at = CURRENT_TIMESTAMP + INTERVAL '7 days',
        email_sent = FALSE,
        email_sent_at = NULL
    WHERE organization_invites.invite_id = p_invite_id
    RETURNING organization_invites.email, organization_invites.expires_at INTO v_invite.email, v_invite.expires_at;
    
    RETURN QUERY SELECT 
        v_invite.email::VARCHAR,
        v_new_token,
        v_invite.organization_name::VARCHAR,
        v_invite.expires_at;
END;
$$ LANGUAGE plpgsql;

-- Fix sp_revoke_invite
CREATE OR REPLACE FUNCTION sp_revoke_invite(
    p_invite_id BIGINT,
    p_user_id BIGINT
) RETURNS BOOLEAN AS $$
DECLARE
    v_org_id BIGINT;
    v_user_role TEXT;
BEGIN
    -- Get organization from invite
    SELECT organization_id INTO v_org_id FROM organization_invites WHERE invite_id = p_invite_id;
    
    IF v_org_id IS NULL THEN
        RAISE EXCEPTION 'Invite not found';
    END IF;
    
    -- Check permissions (using role_name directly)
    SELECT om.role_name INTO v_user_role
    FROM org_members om
    WHERE om.organization_id = v_org_id AND om.user_id = p_user_id;

    IF v_user_role NOT IN ('OWNER', 'ADMIN') THEN
        RAISE EXCEPTION 'Not authorized to revoke invites' USING ERRCODE = '28000';
    END IF;
    
    UPDATE organization_invites SET status = 'REVOKED' WHERE invite_id = p_invite_id;
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;
