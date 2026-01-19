-- Migration 027: Fix sp_accept_invite return type mismatch
-- organizations.organization_id is INTEGER, but function returns BIGINT. Explicit cast required.

BEGIN;

DROP FUNCTION IF EXISTS sp_accept_invite(VARCHAR, BIGINT);

CREATE FUNCTION sp_accept_invite(
    p_token VARCHAR,
    p_user_id BIGINT
) RETURNS TABLE (
    organization_id BIGINT,
    organization_name VARCHAR(200),
    role_name TEXT
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

    -- Add user to organization using org_members
    -- Ensure types match: org_id (BIGINT) user_id (BIGINT)
    INSERT INTO org_members (organization_id, user_id, role_name, is_active)
    VALUES (v_invite.organization_id::BIGINT, p_user_id, v_invite.role_name, TRUE)
    ON CONFLICT (organization_id, user_id) 
    DO UPDATE SET role_name = EXCLUDED.role_name, is_active = TRUE;

    -- Update invite status
    UPDATE organization_invites 
    SET status = 'ACCEPTED' 
    WHERE invite_id = v_invite.invite_id;

    -- Return info with explicit casts
    RETURN QUERY
    SELECT 
        o.organization_id::BIGINT,  -- CAST INTEGER TO BIGINT
        o.organization_name, 
        v_invite.role_name::TEXT
    FROM organizations o
    WHERE o.organization_id = v_invite.organization_id;
END;
$$ LANGUAGE plpgsql;

COMMIT;
