-- Migration 049: Fix inactive member re-invitation and member list
-- This fixes:
-- 1. sp_create_bulk_invite: Only skip ACTIVE members, allow re-inviting inactive ones
-- 2. sp_accept_invite_existing_user: Reactivate inactive members instead of doing nothing
-- 3. sp_get_org_members_detailed: Only return ACTIVE members (hide removed members from list)

-- ==========================================
-- 1. Fix sp_create_bulk_invite - Only skip active members
-- ==========================================
CREATE OR REPLACE FUNCTION sp_create_bulk_invite(
    p_organization_id BIGINT,
    p_email VARCHAR,
    p_role_name VARCHAR,
    p_created_by BIGINT,
    p_token VARCHAR,
    p_days_valid INTEGER,
    p_batch_id BIGINT
) RETURNS TABLE (
    invite_id BIGINT,
    status VARCHAR,
    message VARCHAR
) AS $$
DECLARE
    v_invite_id BIGINT;
    v_user_role TEXT;
    v_existing_active_member BOOLEAN;
BEGIN
    -- Check if creator is admin/owner (org_members uses role_name directly)
    SELECT om.role_name INTO v_user_role
    FROM org_members om
    WHERE om.organization_id = p_organization_id AND om.user_id = p_created_by;

    IF v_user_role NOT IN ('OWNER', 'ADMIN') THEN
        RETURN QUERY SELECT NULL::BIGINT, 'ERROR'::VARCHAR, 'Only OWNERS or ADMINS can send invites'::VARCHAR;
        RETURN;
    END IF;
    
    -- Check if user is already an ACTIVE member (not inactive/removed)
    SELECT EXISTS (
        SELECT 1 FROM org_members om
        JOIN user_accounts ua ON om.user_id = ua.user_id
        WHERE om.organization_id = p_organization_id 
          AND ua.email = p_email
          AND om.is_active = TRUE  -- Only skip if ACTIVE
    ) INTO v_existing_active_member;
    
    IF v_existing_active_member THEN
        RETURN QUERY SELECT NULL::BIGINT, 'SKIPPED'::VARCHAR, 'User is already an active member'::VARCHAR;
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

-- ==========================================
-- 2. Fix sp_accept_invite_existing_user - Reactivate inactive members
-- ==========================================
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

    -- Add user to organization OR reactivate if they were removed
    INSERT INTO org_members (organization_id, user_id, role_name, is_active)
    VALUES (v_invite.organization_id, p_user_id, v_invite.role_name, TRUE)
    ON CONFLICT (organization_id, user_id) 
    DO UPDATE SET 
        is_active = TRUE,
        role_name = EXCLUDED.role_name;

    -- Also reactivate voter record if it exists
    UPDATE voters
    SET status = 'ELIGIBLE', is_approved = TRUE
    WHERE organization_id = v_invite.organization_id AND user_id = p_user_id;

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

-- ==========================================
-- 3. Fix sp_get_org_members_detailed - Only return ACTIVE members
-- ==========================================
CREATE OR REPLACE FUNCTION sp_get_org_members_detailed(
    p_organization_id BIGINT
)
RETURNS TABLE (
    user_id BIGINT,
    username VARCHAR(50),
    email CITEXT,
    role_name TEXT,
    is_active BOOLEAN,
    joined_at TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        u.user_id,
        u.username,
        u.email,
        om.role_name,
        om.is_active,
        om.created_at
    FROM org_members om
    JOIN user_accounts u ON om.user_id = u.user_id
    WHERE om.organization_id = p_organization_id
      AND om.is_active = TRUE  -- Only return active members
    ORDER BY 
        CASE WHEN om.role_name = 'OWNER' THEN 1 
             WHEN om.role_name = 'ADMIN' THEN 2 
             ELSE 3 END,
        om.created_at ASC;
END;
$$ LANGUAGE plpgsql;

-- ==========================================
-- 4. Also fix voters when member list updates
-- ==========================================

-- Make sure when a member is reactivated, their voter status is also restored
-- This is already handled in sp_accept_invite_existing_user above
