CREATE OR REPLACE FUNCTION public.is_org_admin(p_user_id bigint, p_organization_id bigint)
 RETURNS boolean
 LANGUAGE sql
 STABLE
AS $function$
  SELECT EXISTS (
    SELECT 1 FROM org_members
    WHERE organization_id = p_organization_id
      AND user_id = p_user_id
      AND is_active = TRUE
      AND role_name IN ('OWNER', 'ADMIN')
  );
$function$
;
