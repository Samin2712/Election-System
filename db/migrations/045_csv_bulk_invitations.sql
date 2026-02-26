-- CSV Bulk Invitations System
-- Migration: 045_csv_bulk_invitations.sql

-- 1. Add batch tracking table for CSV uploads
CREATE TABLE IF NOT EXISTS invitation_batches (
    batch_id SERIAL PRIMARY KEY,
    organization_id INTEGER NOT NULL REFERENCES organizations(organization_id) ON DELETE CASCADE,
    created_by INTEGER NOT NULL REFERENCES user_accounts(user_id),
    total_emails INTEGER NOT NULL DEFAULT 0,
    successful_emails INTEGER NOT NULL DEFAULT 0,
    failed_emails INTEGER NOT NULL DEFAULT 0,
    status VARCHAR(20) NOT NULL CHECK (status IN ('PROCESSING', 'COMPLETED', 'FAILED')) DEFAULT 'PROCESSING',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP WITH TIME ZONE
);

-- 2. Add batch_id to organization_invites for tracking
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'organization_invites' AND column_name = 'batch_id'
    ) THEN
        ALTER TABLE organization_invites ADD COLUMN batch_id INTEGER REFERENCES invitation_batches(batch_id);
    END IF;
    
    -- Add invited_at column if not exists
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'organization_invites' AND column_name = 'invited_at'
    ) THEN
        ALTER TABLE organization_invites ADD COLUMN invited_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP;
    END IF;
    
    -- Add email_sent column to track if email was sent
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'organization_invites' AND column_name = 'email_sent'
    ) THEN
        ALTER TABLE organization_invites ADD COLUMN email_sent BOOLEAN DEFAULT FALSE;
    END IF;
    
    -- Add email_sent_at column
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'organization_invites' AND column_name = 'email_sent_at'
    ) THEN
        ALTER TABLE organization_invites ADD COLUMN email_sent_at TIMESTAMP WITH TIME ZONE;
    END IF;
END $$;

-- Index for batch lookups
CREATE INDEX IF NOT EXISTS idx_invites_batch ON organization_invites(batch_id);

-- 3. Create a function to create bulk invites
CREATE OR REPLACE FUNCTION sp_create_bulk_invite(
    p_organization_id INTEGER,
    p_email VARCHAR,
    p_token VARCHAR,
    p_role_name VARCHAR,
    p_created_by INTEGER,
    p_batch_id INTEGER,
    p_days_valid INTEGER DEFAULT 7
) RETURNS TABLE (
    invite_id INTEGER,
    status VARCHAR,
    message VARCHAR
) AS $$
DECLARE
    v_invite_id INTEGER;
    v_user_role VARCHAR;
    v_existing_member BOOLEAN;
BEGIN
    -- Check if creator is admin/owner
    SELECT r.role_name INTO v_user_role
    FROM organization_members om
    JOIN roles r ON om.role_id = r.role_id
    WHERE om.organization_id = p_organization_id AND om.user_id = p_created_by;

    IF v_user_role NOT IN ('OWNER', 'ADMIN') THEN
        RETURN QUERY SELECT NULL::INTEGER, 'ERROR'::VARCHAR, 'Only OWNERS or ADMINS can send invites'::VARCHAR;
        RETURN;
    END IF;
    
    -- Check if user is already a member
    SELECT EXISTS (
        SELECT 1 FROM organization_members om
        JOIN user_accounts ua ON om.user_id = ua.user_id
        WHERE om.organization_id = p_organization_id AND ua.email = p_email
    ) INTO v_existing_member;
    
    IF v_existing_member THEN
        RETURN QUERY SELECT NULL::INTEGER, 'SKIPPED'::VARCHAR, 'User is already a member'::VARCHAR;
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

-- 4. Function to validate a token (public - no auth required)
CREATE OR REPLACE FUNCTION sp_validate_invite_token(
    p_token VARCHAR
) RETURNS TABLE (
    valid BOOLEAN,
    invite_id INTEGER,
    email VARCHAR,
    organization_id INTEGER,
    organization_name VARCHAR,
    role_name VARCHAR,
    expires_at TIMESTAMP WITH TIME ZONE,
    user_exists BOOLEAN,
    user_id INTEGER
) AS $$
DECLARE
    v_invite RECORD;
    v_user_id INTEGER;
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
            FALSE, NULL::INTEGER, NULL::VARCHAR, NULL::INTEGER, 
            NULL::VARCHAR, NULL::VARCHAR, NULL::TIMESTAMP WITH TIME ZONE, FALSE, NULL::INTEGER;
        RETURN;
    END IF;
    
    -- Check if expired or not pending
    IF v_invite.status != 'PENDING' OR v_invite.expires_at < CURRENT_TIMESTAMP THEN
        RETURN QUERY SELECT 
            FALSE, v_invite.invite_id, v_invite.email, v_invite.organization_id,
            v_invite.organization_name, v_invite.role_name, v_invite.expires_at, FALSE, NULL::INTEGER;
        RETURN;
    END IF;
    
    -- Check if user exists
    SELECT ua.user_id INTO v_user_id
    FROM user_accounts ua
    WHERE ua.email = v_invite.email;
    
    RETURN QUERY SELECT 
        TRUE,
        v_invite.invite_id,
        v_invite.email,
        v_invite.organization_id,
        v_invite.organization_name,
        v_invite.role_name,
        v_invite.expires_at,
        v_user_id IS NOT NULL,
        v_user_id;
END;
$$ LANGUAGE plpgsql;

-- 5. Function to accept invite for existing user
CREATE OR REPLACE FUNCTION sp_accept_invite_existing_user(
    p_token VARCHAR,
    p_user_id INTEGER
) RETURNS TABLE (
    success BOOLEAN,
    organization_id INTEGER,
    organization_name VARCHAR,
    role_name VARCHAR,
    message VARCHAR
) AS $$
DECLARE
    v_invite RECORD;
    v_role_id INTEGER;
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
        RETURN QUERY SELECT FALSE, NULL::INTEGER, NULL::VARCHAR, NULL::VARCHAR, 'Invalid or expired invite token'::VARCHAR;
        RETURN;
    END IF;
    
    -- Verify email matches
    IF v_invite.email != v_user_email THEN
        RETURN QUERY SELECT FALSE, NULL::INTEGER, NULL::VARCHAR, NULL::VARCHAR, 'This invitation was sent to a different email address'::VARCHAR;
        RETURN;
    END IF;

    -- Get Role ID
    SELECT role_id INTO v_role_id FROM roles WHERE roles.role_name = v_invite.role_name;
    IF v_role_id IS NULL THEN
        RETURN QUERY SELECT FALSE, NULL::INTEGER, NULL::VARCHAR, NULL::VARCHAR, 'Invalid role in invite'::VARCHAR;
        RETURN;
    END IF;

    -- Add user to organization
    INSERT INTO organization_members (organization_id, user_id, role_id)
    VALUES (v_invite.organization_id, p_user_id, v_role_id)
    ON CONFLICT (organization_id, user_id) DO NOTHING;

    -- Update invite status
    UPDATE organization_invites 
    SET status = 'ACCEPTED' 
    WHERE organization_invites.invite_id = v_invite.invite_id;

    RETURN QUERY SELECT 
        TRUE, 
        v_invite.organization_id, 
        v_invite.organization_name, 
        v_invite.role_name,
        'Successfully joined organization'::VARCHAR;
END;
$$ LANGUAGE plpgsql;

-- 6. Function to register new user with invite token
CREATE OR REPLACE FUNCTION sp_register_with_invite(
    p_username VARCHAR,
    p_email VARCHAR,
    p_password_hash VARCHAR,
    p_token VARCHAR
) RETURNS TABLE (
    user_id INTEGER,
    organization_id INTEGER,
    organization_name VARCHAR,
    role_name VARCHAR,
    success BOOLEAN,
    message VARCHAR
) AS $$
DECLARE
    v_invite RECORD;
    v_user_id INTEGER;
    v_role_id INTEGER;
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
        RETURN QUERY SELECT NULL::INTEGER, NULL::INTEGER, NULL::VARCHAR, NULL::VARCHAR, FALSE, 'Invalid or expired invite token'::VARCHAR;
        RETURN;
    END IF;
    
    -- Verify email matches
    IF v_invite.email != p_email THEN
        RETURN QUERY SELECT NULL::INTEGER, NULL::INTEGER, NULL::VARCHAR, NULL::VARCHAR, FALSE, 'Email does not match invitation'::VARCHAR;
        RETURN;
    END IF;
    
    -- Get default role for user accounts
    SELECT r.role_id INTO v_default_role_id FROM roles r WHERE r.role_name = 'USER';
    
    -- Create user account
    INSERT INTO user_accounts (username, email, password_hash, role_id, is_active)
    VALUES (p_username, p_email, p_password_hash, v_default_role_id, TRUE)
    RETURNING user_accounts.user_id INTO v_user_id;
    
    -- Get Role ID for organization membership
    SELECT r.role_id INTO v_role_id FROM roles r WHERE r.role_name = v_invite.role_name;
    
    -- Add user to organization
    INSERT INTO organization_members (organization_id, user_id, role_id)
    VALUES (v_invite.organization_id, v_user_id, v_role_id);
    
    -- Update invite status
    UPDATE organization_invites 
    SET status = 'ACCEPTED' 
    WHERE organization_invites.invite_id = v_invite.invite_id;
    
    RETURN QUERY SELECT 
        v_user_id, 
        v_invite.organization_id, 
        v_invite.organization_name, 
        v_invite.role_name,
        TRUE,
        'Registration successful'::VARCHAR;
END;
$$ LANGUAGE plpgsql;

-- 7. Function to get organization's pending invites
CREATE OR REPLACE FUNCTION sp_get_org_pending_invites(
    p_organization_id INTEGER,
    p_user_id INTEGER
) RETURNS TABLE (
    invite_id INTEGER,
    email VARCHAR,
    role_name VARCHAR,
    status VARCHAR,
    created_at TIMESTAMP WITH TIME ZONE,
    expires_at TIMESTAMP WITH TIME ZONE,
    email_sent BOOLEAN,
    email_sent_at TIMESTAMP WITH TIME ZONE
) AS $$
DECLARE
    v_user_role VARCHAR;
BEGIN
    -- Check if user is admin/owner
    SELECT r.role_name INTO v_user_role
    FROM organization_members om
    JOIN roles r ON om.role_id = r.role_id
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

-- 8. Function to resend invite
CREATE OR REPLACE FUNCTION sp_resend_invite(
    p_invite_id INTEGER,
    p_user_id INTEGER
) RETURNS TABLE (
    email VARCHAR,
    token VARCHAR,
    organization_name VARCHAR,
    expires_at TIMESTAMP WITH TIME ZONE
) AS $$
DECLARE
    v_invite RECORD;
    v_user_role VARCHAR;
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
    
    -- Check permissions
    SELECT r.role_name INTO v_user_role
    FROM organization_members om
    JOIN roles r ON om.role_id = r.role_id
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
        v_invite.email,
        v_new_token,
        v_invite.organization_name,
        v_invite.expires_at;
END;
$$ LANGUAGE plpgsql;

-- 9. Function to revoke invite
CREATE OR REPLACE FUNCTION sp_revoke_invite(
    p_invite_id INTEGER,
    p_user_id INTEGER
) RETURNS BOOLEAN AS $$
DECLARE
    v_org_id INTEGER;
    v_user_role VARCHAR;
BEGIN
    -- Get organization from invite
    SELECT organization_id INTO v_org_id FROM organization_invites WHERE invite_id = p_invite_id;
    
    IF v_org_id IS NULL THEN
        RAISE EXCEPTION 'Invite not found';
    END IF;
    
    -- Check permissions
    SELECT r.role_name INTO v_user_role
    FROM organization_members om
    JOIN roles r ON om.role_id = r.role_id
    WHERE om.organization_id = v_org_id AND om.user_id = p_user_id;

    IF v_user_role NOT IN ('OWNER', 'ADMIN') THEN
        RAISE EXCEPTION 'Not authorized to revoke invites' USING ERRCODE = '28000';
    END IF;
    
    UPDATE organization_invites SET status = 'REVOKED' WHERE invite_id = p_invite_id;
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

COMMENT ON TABLE invitation_batches IS 'Tracks CSV bulk invitation uploads';
COMMENT ON FUNCTION sp_create_bulk_invite IS 'Creates a single invite as part of a bulk operation';
COMMENT ON FUNCTION sp_validate_invite_token IS 'Validates an invite token - public endpoint';
COMMENT ON FUNCTION sp_accept_invite_existing_user IS 'Accepts an invite for an existing user';
COMMENT ON FUNCTION sp_register_with_invite IS 'Registers a new user with an invite token';
