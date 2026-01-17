-- Migration 019: User Registration Request System
BEGIN;

-- Table to store user requests to join organizations
CREATE TABLE IF NOT EXISTS organization_join_requests (
    request_id SERIAL PRIMARY KEY,
    organization_id BIGINT NOT NULL REFERENCES organizations(organization_id),
    user_id BIGINT NOT NULL REFERENCES user_accounts(user_id),
    request_message TEXT,
    status VARCHAR(20) NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'APPROVED', 'REJECTED')),
    approval_token VARCHAR(64) UNIQUE,
    approved_by BIGINT REFERENCES user_accounts(user_id),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(organization_id, user_id, status) -- One pending request per user per org
);

CREATE INDEX idx_join_requests_org ON organization_join_requests(organization_id);
CREATE INDEX idx_join_requests_user ON organization_join_requests(user_id);
CREATE INDEX idx_join_requests_status ON organization_join_requests(status);
CREATE INDEX idx_join_requests_token ON organization_join_requests(approval_token);

-- Function: User requests to join organization
CREATE OR REPLACE FUNCTION sp_request_to_join_organization(
    p_organization_id BIGINT,
    p_user_id BIGINT,
    p_message TEXT DEFAULT NULL
)
RETURNS BIGINT
LANGUAGE plpgsql
AS $$
DECLARE
    v_request_id BIGINT;
    v_already_member BOOLEAN;
    v_pending_request BOOLEAN;
BEGIN
    -- Check if user is already a member
    SELECT EXISTS(
        SELECT 1 FROM org_members 
        WHERE organization_id = p_organization_id 
        AND user_id = p_user_id 
        AND is_active = TRUE
    ) INTO v_already_member;

    IF v_already_member THEN
        RAISE EXCEPTION 'You are already a member of this organization'
            USING ERRCODE = '23505';
    END IF;

    -- Check if there's already a pending request
    SELECT EXISTS(
        SELECT 1 FROM organization_join_requests 
        WHERE organization_id = p_organization_id 
        AND user_id = p_user_id 
        AND status = 'PENDING'
    ) INTO v_pending_request;

    IF v_pending_request THEN
        RAISE EXCEPTION 'You already have a pending request for this organization'
            USING ERRCODE = '23505';
    END IF;

    -- Create join request
    INSERT INTO organization_join_requests (
        organization_id,
        user_id,
        request_message,
        status
    )
    VALUES (
        p_organization_id,
        p_user_id,
        p_message,
        'PENDING'
    )
    RETURNING request_id INTO v_request_id;

    RETURN v_request_id;
END;
$$;

-- Function: Get pending join requests for an organization
CREATE OR REPLACE FUNCTION sp_get_pending_join_requests(
    p_organization_id BIGINT,
    p_admin_user_id BIGINT
)
RETURNS TABLE (
    request_id BIGINT,
    user_id BIGINT,
    username VARCHAR(100),
    email VARCHAR(255),
    request_message TEXT,
    created_at TIMESTAMP
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
        r.request_id,
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

-- Function: Approve join request and generate token
CREATE OR REPLACE FUNCTION sp_approve_join_request(
    p_request_id BIGINT,
    p_admin_user_id BIGINT,
    p_approval_token VARCHAR(64)
)
RETURNS TABLE (
    user_id BIGINT,
    username VARCHAR(100),
    email VARCHAR(255),
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

-- Function: Complete registration with token
CREATE OR REPLACE FUNCTION sp_complete_registration_with_token(
    p_token VARCHAR(64),
    p_user_id BIGINT
)
RETURNS TABLE (
    organization_id BIGINT,
    organization_name VARCHAR(200)
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_request_id BIGINT;
    v_org_id BIGINT;
    v_request_user_id BIGINT;
BEGIN
    -- Find the request by token
    SELECT r.request_id, r.organization_id, r.user_id
    INTO v_request_id, v_org_id, v_request_user_id
    FROM organization_join_requests r
    WHERE r.approval_token = p_token
    AND r.status = 'APPROVED';

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Invalid or expired registration token'
            USING ERRCODE = '22023';
    END IF;

    -- Verify the token belongs to this user
    IF v_request_user_id != p_user_id THEN
        RAISE EXCEPTION 'This token does not belong to you'
            USING ERRCODE = '28000';
    END IF;

    -- Add user to organization as MEMBER
    INSERT INTO org_members (
        organization_id,
        user_id,
        role_name,
        is_active
    )
    VALUES (
        v_org_id,
        p_user_id,
        'MEMBER',
        TRUE
    )
    ON CONFLICT (organization_id, user_id) 
    DO UPDATE SET is_active = TRUE, role_name = 'MEMBER';

    -- Invalidate the token by updating status
    UPDATE organization_join_requests
    SET approval_token = NULL  -- Clear token after use
    WHERE request_id = v_request_id;

    -- Audit log
    INSERT INTO audit_logs (
        organization_id,
        user_id,
        action_type,
        entity_name,
        entity_id
    )
    VALUES (
        v_org_id,
        p_user_id,
        'USER_JOINED_ORG',
        'org_members',
        v_org_id
    );

    -- Return org details
    RETURN QUERY
    SELECT o.organization_id, o.organization_name
    FROM organizations o
    WHERE o.organization_id = v_org_id;
END;
$$;

-- Function: Reject join request
CREATE OR REPLACE FUNCTION sp_reject_join_request(
    p_request_id BIGINT,
    p_admin_user_id BIGINT
)
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
    v_org_id BIGINT;
    v_is_admin BOOLEAN;
BEGIN
    -- Get organization from request
    SELECT organization_id
    INTO v_org_id
    FROM organization_join_requests
    WHERE request_id = p_request_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Join request not found'
            USING ERRCODE = '22023';
    END IF;

    -- Check if requesting user is admin/owner
    SELECT is_org_admin(p_admin_user_id, v_org_id) INTO v_is_admin;
    
    IF NOT v_is_admin THEN
        RAISE EXCEPTION 'Not authorized to reject join requests'
            USING ERRCODE = '28000';
    END IF;

    -- Update request status
    UPDATE organization_join_requests
    SET 
        status = 'REJECTED',
        updated_at = NOW()
    WHERE request_id = p_request_id;
END;
$$;

COMMIT;
