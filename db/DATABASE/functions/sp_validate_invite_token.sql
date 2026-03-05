CREATE OR REPLACE FUNCTION public.sp_validate_invite_token(p_token character varying)
 RETURNS TABLE(valid boolean, invite_id bigint, email character varying, organization_id bigint, organization_name character varying, role_name character varying, expires_at timestamp with time zone, user_exists boolean, user_id bigint)
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_invite RECORD;
    v_user_id BIGINT;
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
            FALSE, NULL::BIGINT, NULL::VARCHAR, NULL::BIGINT, 
            NULL::VARCHAR, NULL::VARCHAR, NULL::TIMESTAMP WITH TIME ZONE, FALSE, NULL::BIGINT;
        RETURN;
    END IF;
    
    -- Check if expired or not pending
    IF v_invite.status != 'PENDING' OR v_invite.expires_at < CURRENT_TIMESTAMP THEN
        RETURN QUERY SELECT 
            FALSE, v_invite.invite_id::BIGINT, v_invite.email::VARCHAR, v_invite.organization_id::BIGINT,
            v_invite.organization_name::VARCHAR, v_invite.role_name::VARCHAR, v_invite.expires_at, FALSE, NULL::BIGINT;
        RETURN;
    END IF;
    
    -- Check if user exists
    SELECT ua.user_id INTO v_user_id
    FROM user_accounts ua
    WHERE ua.email = v_invite.email;
    
    RETURN QUERY SELECT 
        TRUE,
        v_invite.invite_id::BIGINT,
        v_invite.email::VARCHAR,
        v_invite.organization_id::BIGINT,
        v_invite.organization_name::VARCHAR,
        v_invite.role_name::VARCHAR,
        v_invite.expires_at,
        v_user_id IS NOT NULL,
        v_user_id;
END;
$function$
;
