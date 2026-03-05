CREATE OR REPLACE FUNCTION public.sp_resend_invite(p_invite_id bigint, p_user_id bigint)
 RETURNS TABLE(email character varying, token character varying, organization_name character varying, expires_at timestamp with time zone)
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_invite RECORD;
    v_user_role TEXT;
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
    
    -- Check permissions (using role_name directly)
    SELECT om.role_name INTO v_user_role
    FROM org_members om
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
        v_invite.email::VARCHAR,
        v_new_token,
        v_invite.organization_name::VARCHAR,
        v_invite.expires_at;
END;
$function$
;
