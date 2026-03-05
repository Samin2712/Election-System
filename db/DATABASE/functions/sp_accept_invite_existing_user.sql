CREATE OR REPLACE FUNCTION public.sp_accept_invite_existing_user(p_token character varying, p_user_id bigint)
 RETURNS TABLE(success boolean, organization_id bigint, organization_name character varying, role_name character varying, message character varying)
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_invite RECORD;
    v_user_email VARCHAR;
    v_org_id BIGINT;
    v_org_name VARCHAR;
    v_role VARCHAR;
BEGIN
    SELECT ua.email INTO v_user_email FROM user_accounts ua WHERE ua.user_id = p_user_id;
    
    SELECT 
        oi.invite_id, oi.email, oi.organization_id, o.organization_name,
        oi.role_name, oi.status, oi.expires_at
    INTO v_invite
    FROM organization_invites oi
    JOIN organizations o ON oi.organization_id = o.organization_id
    WHERE oi.token = p_token AND oi.status = 'PENDING' AND oi.expires_at > CURRENT_TIMESTAMP;
    
    IF v_invite IS NULL THEN
        RETURN QUERY SELECT FALSE, NULL::BIGINT, NULL::VARCHAR, NULL::VARCHAR, 'Invalid or expired invite token'::VARCHAR;
        RETURN;
    END IF;
    
    IF v_invite.email != v_user_email THEN
        RETURN QUERY SELECT FALSE, NULL::BIGINT, NULL::VARCHAR, NULL::VARCHAR, 'This invitation was sent to a different email address'::VARCHAR;
        RETURN;
    END IF;

    v_org_id := v_invite.organization_id;
    v_org_name := v_invite.organization_name;
    v_role := v_invite.role_name;

    -- Add or reactivate member
    INSERT INTO org_members (organization_id, user_id, role_name, is_active)
    VALUES (v_org_id, p_user_id, v_role, TRUE)
    ON CONFLICT ON CONSTRAINT org_members_pkey
    DO UPDATE SET is_active = TRUE, role_name = EXCLUDED.role_name;

    -- Reactivate voter record (APPROVED, not ELIGIBLE)
    UPDATE voters v
    SET status = 'APPROVED', is_approved = TRUE
    WHERE v.organization_id = v_org_id AND v.user_id = p_user_id;

    -- Mark invite as accepted
    UPDATE organization_invites SET status = 'ACCEPTED' 
    WHERE organization_invites.invite_id = v_invite.invite_id;

    RETURN QUERY SELECT TRUE, v_org_id, v_org_name, v_role, 'Successfully joined organization'::VARCHAR;
END;
$function$
;
