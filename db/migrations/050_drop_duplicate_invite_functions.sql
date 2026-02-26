-- Migration 050: Drop duplicate sp_create_bulk_invite functions and recreate
-- Fix "function is not unique" error

-- Drop ALL existing versions of the function
DROP FUNCTION IF EXISTS sp_create_bulk_invite(BIGINT, VARCHAR, VARCHAR, BIGINT, VARCHAR, INTEGER, BIGINT);
DROP FUNCTION IF EXISTS sp_create_bulk_invite(INTEGER, VARCHAR, VARCHAR, INTEGER, VARCHAR, INTEGER, INTEGER);
DROP FUNCTION IF EXISTS sp_create_bulk_invite(BIGINT, VARCHAR, VARCHAR, BIGINT, VARCHAR, INT, BIGINT);

-- Recreate with correct BIGINT types
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
    -- Check if creator is admin/owner
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
          AND om.is_active = TRUE
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
