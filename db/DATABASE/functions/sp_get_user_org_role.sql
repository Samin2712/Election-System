CREATE OR REPLACE FUNCTION public.sp_get_user_org_role(p_user_id bigint, p_organization_id bigint)
 RETURNS TABLE(role_name text, is_active boolean)
 LANGUAGE plpgsql
 STABLE
AS $function$
BEGIN
    RETURN QUERY
    SELECT 
        om.role_name,
        om.is_active
    FROM org_members om
    WHERE om.user_id = p_user_id
    AND om.organization_id = p_organization_id
    LIMIT 1;
END;
$function$
;
