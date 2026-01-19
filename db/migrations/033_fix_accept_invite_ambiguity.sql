-- Migration 033: Fix ambiguity in sp_accept_invite
-- Ensure output columns don't shadow table columns

BEGIN;

DROP FUNCTION IF EXISTS sp_accept_invite(VARCHAR, BIGINT);

CREATE FUNCTION sp_accept_invite(
    p_token VARCHAR,
    p_user_id BIGINT
) RETURNS TABLE (
    out_organization_id BIGINT,
    out_organization_name TEXT,
    out_role_name TEXT
) AS $$
DECLARE
    v_invite_id INTEGER;
    v_org_id BIGINT;
    v_role_name TEXT;
    v_org_name TEXT;
BEGIN
    -- Use Dynamic SQL to find invite (Bypassing pl_comp.c check)
    EXECUTE 'SELECT invite_id, organization_id, role_name::TEXT
             FROM public.organization_invites
             WHERE token = $1 
             AND status = ''PENDING''
             AND expires_at > CURRENT_TIMESTAMP'
    INTO v_invite_id, v_org_id, v_role_name
    USING p_token;

    IF v_invite_id IS NULL THEN
        RAISE EXCEPTION 'Invalid or expired invite token';
    END IF;

    -- Add user to organization
    INSERT INTO public.org_members (organization_id, user_id, role_name, is_active)
    VALUES (v_org_id, p_user_id, v_role_name, TRUE)
    ON CONFLICT (organization_id, user_id) 
    DO UPDATE SET role_name = EXCLUDED.role_name, is_active = TRUE;

    -- Update invite status
    UPDATE organization_invites 
    SET status = 'ACCEPTED' 
    WHERE invite_id = v_invite_id;

    -- Get Organization Name
    SELECT o.organization_name::TEXT INTO v_org_name
    FROM organizations o
    WHERE o.organization_id = v_org_id;

    -- Return info
    RETURN QUERY
    SELECT 
        v_org_id,
        v_org_name, 
        v_role_name;
END;
$$ LANGUAGE plpgsql;

COMMIT;
