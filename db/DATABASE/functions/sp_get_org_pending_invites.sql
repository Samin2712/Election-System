CREATE OR REPLACE FUNCTION public.sp_get_org_pending_invites(p_organization_id bigint, p_user_id bigint)
 RETURNS TABLE(invite_id bigint, email character varying, role_name character varying, status character varying, created_at timestamp with time zone, expires_at timestamp with time zone, email_sent boolean, email_sent_at timestamp with time zone)
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_user_role TEXT;
BEGIN
    -- Check if user is admin/owner (using role_name directly)
    SELECT om.role_name INTO v_user_role
    FROM org_members om
    WHERE om.organization_id = p_organization_id AND om.user_id = p_user_id;

    IF v_user_role NOT IN ('OWNER', 'ADMIN') THEN
        RAISE EXCEPTION 'Not authorized to view invites' USING ERRCODE = '28000';
    END IF;

    RETURN QUERY 
    SELECT 
        oi.invite_id,
        oi.email,
        oi.role_name,
        oi.status,
        oi.created_at,
        oi.expires_at,
        COALESCE(oi.email_sent, FALSE),
        oi.email_sent_at
    FROM organization_invites oi
    WHERE oi.organization_id = p_organization_id
    ORDER BY oi.created_at DESC;
END;
$function$
;
