CREATE OR REPLACE FUNCTION public.sp_register_with_invite(p_username character varying, p_email character varying, p_password_hash character varying, p_token character varying)
 RETURNS TABLE(user_id bigint, organization_id bigint, organization_name character varying, role_name character varying, success boolean, message character varying)
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_invite RECORD;
    v_user_id BIGINT;
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
        RETURN QUERY SELECT NULL::BIGINT, NULL::BIGINT, NULL::VARCHAR, NULL::VARCHAR, FALSE, 'Invalid or expired invite token'::VARCHAR;
        RETURN;
    END IF;
    
    -- Verify email matches
    IF v_invite.email != p_email THEN
        RETURN QUERY SELECT NULL::BIGINT, NULL::BIGINT, NULL::VARCHAR, NULL::VARCHAR, FALSE, 'Email does not match invitation'::VARCHAR;
        RETURN;
    END IF;
    
    -- Get default role for user accounts
    SELECT r.role_id INTO v_default_role_id FROM roles r WHERE r.role_name = 'USER';
    
    -- Create user account
    INSERT INTO user_accounts (username, email, password_hash, role_id, is_active)
    VALUES (p_username, p_email, p_password_hash, v_default_role_id, TRUE)
    RETURNING user_accounts.user_id INTO v_user_id;
    
    -- Add user to organization (using role_name directly)
    INSERT INTO org_members (organization_id, user_id, role_name, is_active)
    VALUES (v_invite.organization_id, v_user_id, v_invite.role_name, TRUE);
    
    -- Update invite status
    UPDATE organization_invites 
    SET status = 'ACCEPTED' 
    WHERE organization_invites.invite_id = v_invite.invite_id;
    
    RETURN QUERY SELECT 
        v_user_id, 
        v_invite.organization_id::BIGINT, 
        v_invite.organization_name::VARCHAR, 
        v_invite.role_name::VARCHAR,
        TRUE,
        'Registration successful'::VARCHAR;
END;
$function$
;
