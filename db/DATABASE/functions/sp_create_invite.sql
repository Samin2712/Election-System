CREATE OR REPLACE FUNCTION public.sp_create_invite(p_organization_id bigint, p_email character varying, p_token character varying, p_role_name character varying, p_created_by bigint, p_days_valid integer DEFAULT 7)
 RETURNS integer
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_invite_id INTEGER;
    v_is_admin BOOLEAN;
BEGIN
    -- Check if creator is admin/owner using our is_org_admin function
    SELECT is_org_admin(p_created_by, p_organization_id) INTO v_is_admin;

    IF NOT v_is_admin THEN
        RAISE EXCEPTION 'Only OWNERS or ADMINS can send invites';
    END IF;

    -- Insert invite
    INSERT INTO organization_invites (
        organization_id, email, token, role_name, created_by, expires_at
    ) VALUES (
        p_organization_id, p_email, p_token, p_role_name, p_created_by, 
        CURRENT_TIMESTAMP + (p_days_valid::text || ' days')::INTERVAL
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
$function$
;
