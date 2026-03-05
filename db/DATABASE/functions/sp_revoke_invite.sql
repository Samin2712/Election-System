CREATE OR REPLACE FUNCTION public.sp_revoke_invite(p_invite_id bigint, p_user_id bigint)
 RETURNS boolean
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_org_id BIGINT;
    v_user_role TEXT;
BEGIN
    -- Get organization from invite
    SELECT organization_id INTO v_org_id FROM organization_invites WHERE invite_id = p_invite_id;
    
    IF v_org_id IS NULL THEN
        RAISE EXCEPTION 'Invite not found';
    END IF;
    
    -- Check permissions (using role_name directly)
    SELECT om.role_name INTO v_user_role
    FROM org_members om
    WHERE om.organization_id = v_org_id AND om.user_id = p_user_id;

    IF v_user_role NOT IN ('OWNER', 'ADMIN') THEN
        RAISE EXCEPTION 'Not authorized to revoke invites' USING ERRCODE = '28000';
    END IF;
    
    UPDATE organization_invites SET status = 'REVOKED' WHERE invite_id = p_invite_id;
    
    RETURN TRUE;
END;
$function$
;
