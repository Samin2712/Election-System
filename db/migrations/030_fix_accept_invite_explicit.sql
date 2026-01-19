-- Migration 030: Fix sp_accept_invite using explicit variables
-- Avoid RECORD usage to prevent PL/pgSQL type inference issues

BEGIN;

DROP FUNCTION IF EXISTS sp_accept_invite(VARCHAR, BIGINT);

CREATE FUNCTION sp_accept_invite(
    p_token VARCHAR,
    p_user_id BIGINT
) RETURNS TABLE (
    organization_id BIGINT,
    organization_name TEXT,
    role_name TEXT
) AS $$
DECLARE
    v_invite_id INTEGER;
    v_org_id BIGINT;
    v_role_name TEXT;
    v_found BOOLEAN;
BEGIN
    -- Find valid invite
    SELECT invite_id, organization_id, role_name::TEXT
    INTO v_invite_id, v_org_id, v_role_name
    FROM organization_invites
    WHERE token = p_token 
    AND status = 'PENDING'
    AND expires_at > CURRENT_TIMESTAMP;

    IF v_invite_id IS NULL THEN
        RAISE EXCEPTION 'Invalid or expired invite token';
    END IF;

    RAISE NOTICE 'Accepting Invite: OrgID=%, UserID=%, Role=%', v_org_id, p_user_id, v_role_name;

    -- Add user to organization
    INSERT INTO org_members (organization_id, user_id, role_name, is_active)
    VALUES (v_org_id, p_user_id, v_role_name, TRUE)
    ON CONFLICT (organization_id, user_id) 
    DO UPDATE SET role_name = EXCLUDED.role_name, is_active = TRUE;

    -- Update invite status
    UPDATE organization_invites 
    SET status = 'ACCEPTED' 
    WHERE invite_id = v_invite_id;

    -- Return info
    RETURN QUERY
    SELECT 
        o.organization_id::BIGINT,
        o.organization_name::TEXT,
        v_role_name
    FROM organizations o
    WHERE o.organization_id = v_org_id;
END;
$$ LANGUAGE plpgsql;

COMMIT;
