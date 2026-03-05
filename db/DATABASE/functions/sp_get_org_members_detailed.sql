CREATE OR REPLACE FUNCTION public.sp_get_org_members_detailed(p_organization_id bigint)
 RETURNS TABLE(user_id bigint, username character varying, email citext, role_name text, is_active boolean, joined_at timestamp with time zone)
 LANGUAGE plpgsql
AS $function$
BEGIN
    RETURN QUERY
    SELECT 
        u.user_id,
        u.username,
        u.email,
        om.role_name,
        om.is_active,
        om.created_at
    FROM org_members om
    JOIN user_accounts u ON om.user_id = u.user_id
    WHERE om.organization_id = p_organization_id
      AND om.is_active = TRUE  -- Only return active members
    ORDER BY 
        CASE WHEN om.role_name = 'OWNER' THEN 1 
             WHEN om.role_name = 'ADMIN' THEN 2 
             ELSE 3 END,
        om.created_at ASC;
END;
$function$
;
