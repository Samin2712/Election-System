-- Organization Invites System

-- 1. Create invites table
CREATE TABLE organization_invites (
    invite_id SERIAL PRIMARY KEY,
    organization_id INTEGER NOT NULL REFERENCES organizations(organization_id) ON DELETE CASCADE,
    email VARCHAR(255) NOT NULL,
    token VARCHAR(64) NOT NULL UNIQUE,
    role_name VARCHAR(50) NOT NULL DEFAULT 'MEMBER',
    status VARCHAR(20) NOT NULL CHECK (status IN ('PENDING', 'ACCEPTED', 'EXPIRED', 'REVOKED')) DEFAULT 'PENDING',
    created_by INTEGER REFERENCES user_accounts(user_id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    CONSTRAINT unique_active_invite_per_email UNIQUE (organization_id, email)
);

-- Index for token lookups
CREATE INDEX idx_invites_token ON organization_invites(token) WHERE status = 'PENDING';

-- 2. Procedure to create an invite
CREATE OR REPLACE FUNCTION sp_create_invite(
    p_organization_id INTEGER,
    p_email VARCHAR,
    p_token VARCHAR,
    p_role_name VARCHAR,
    p_created_by INTEGER,
    p_days_valid INTEGER DEFAULT 7
) RETURNS INTEGER AS $$
DECLARE
    v_invite_id INTEGER;
    v_user_role VARCHAR;
BEGIN
    -- Check if creator is admin/owner
    SELECT r.role_name INTO v_user_role
    FROM organization_members om
    JOIN roles r ON om.role_id = r.role_id
    WHERE om.organization_id = p_organization_id AND om.user_id = p_created_by;

    IF v_user_role NOT IN ('OWNER', 'ADMIN') THEN
        RAISE EXCEPTION 'Only OWNERS or ADMINS can send invites';
    END IF;

    -- Insert invite
    INSERT INTO organization_invites (
        organization_id, email, token, role_name, created_by, expires_at
    ) VALUES (
        p_organization_id, p_email, p_token, p_role_name, p_created_by, CURRENT_TIMESTAMP + (p_days_valid::text || ' days')::INTERVAL
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

-- 3. Procedure to accept an invite
CREATE OR REPLACE FUNCTION sp_accept_invite(
    p_token VARCHAR,
    p_user_id INTEGER
) RETURNS TABLE (
    organization_id INTEGER,
    organization_name VARCHAR,
    role_name VARCHAR
) AS $$
DECLARE
    v_invite RECORD;
    v_role_id INTEGER;
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

    -- Get Role ID
    SELECT role_id INTO v_role_id FROM roles WHERE role_name = v_invite.role_name;
    IF v_role_id IS NULL THEN
        RAISE EXCEPTION 'Invalid role in invite';
    END IF;

    -- Add user to organization
    INSERT INTO organization_members (organization_id, user_id, role_id)
    VALUES (v_invite.organization_id, p_user_id, v_role_id)
    ON CONFLICT (organization_id, user_id) DO NOTHING;

    -- Update invite status
    UPDATE organization_invites 
    SET status = 'ACCEPTED' 
    WHERE invite_id = v_invite.invite_id;

    -- Return info
    RETURN QUERY
    SELECT o.organization_id, o.name, v_invite.role_name
    FROM organizations o
    WHERE o.organization_id = v_invite.organization_id;
END;
$$ LANGUAGE plpgsql;
