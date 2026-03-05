CREATE OR REPLACE FUNCTION public.sp_get_voter_status(p_organization_id bigint, p_user_id bigint)
 RETURNS TABLE(voter_id bigint, is_approved boolean, status voter_status, approved_by bigint, approved_at timestamp with time zone, registered_at timestamp with time zone)
 LANGUAGE sql
 STABLE
AS $function$
  SELECT 
    voter_id,
    is_approved,
    status,
    approved_by,
    approved_at,
    registered_at
  FROM voters
  WHERE organization_id = p_organization_id
    AND user_id = p_user_id;
$function$
;
