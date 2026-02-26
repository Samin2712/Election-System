-- Migration 052: Fix ambiguous column reference in sp_accept_invite_existing_user
-- The RETURNS TABLE columns (organization_id, role_name) clash with table columns

-- Drop old version first to avoid conflicts
DROP FUNCTION IF EXISTS sp_accept_invite_existing_user(VARCHAR, BIGINT);

CREATE FUNCTION sp_accept_invite_existing_user(
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
    v_org_id BIGINT;
    v_org_name VARCHAR;
    v_role VARCHAR;
BEGIN
    -- Get user email
    SELECT ua.email INTO v_user_email FROM user_accounts ua WHERE ua.user_id = p_user_id;
    
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

    -- Save values to avoid ambiguity
    v_org_id := v_invite.organization_id;
    v_org_name := v_invite.organization_name;
    v_role := v_invite.role_name;

    -- Add user to organization OR reactivate if they were removed
    INSERT INTO org_members (organization_id, user_id, role_name, is_active)
    VALUES (v_org_id, p_user_id, v_role, TRUE)
    ON CONFLICT (organization_id, user_id) 
    DO UPDATE SET 
        is_active = TRUE,
        role_name = EXCLUDED.role_name;

    -- Also reactivate voter record if it exists
    UPDATE voters v
    SET status = 'ELIGIBLE', is_approved = TRUE
    WHERE v.organization_id = v_org_id AND v.user_id = p_user_id;

    -- Update invite status
    UPDATE organization_invites 
    SET status = 'ACCEPTED' 
    WHERE organization_invites.invite_id = v_invite.invite_id;

    RETURN QUERY SELECT 
        TRUE, 
        v_org_id, 
        v_org_name,
        v_role,
        'Successfully joined organization'::VARCHAR;
END;
$$ LANGUAGE plpgsql;
