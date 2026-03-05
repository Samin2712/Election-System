CREATE OR REPLACE FUNCTION public.sp_get_user_organizations(p_user_id bigint)
 RETURNS TABLE(organization_id bigint, organization_name character varying, organization_type character varying, organization_code character varying, organization_status character varying, user_role text, is_member_active boolean, joined_at timestamp with time zone)
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
    RETURN QUERY
    SELECT 
        o.organization_id,
        o.organization_name,
        o.organization_type,
        o.organization_code,
        COALESCE(o.status, 'ACTIVE') as organization_status,
        om.role_name as user_role,
        om.is_active as is_member_active,
        om.created_at as joined_at
    FROM organizations o
    JOIN org_members om ON o.organization_id = om.organization_id
    WHERE om.user_id = p_user_id
    AND om.is_active = TRUE
    ORDER BY om.created_at DESC;
END;
$function$
;
