CREATE OR REPLACE FUNCTION public.sp_list_pending_voters(p_organization_id bigint)
 RETURNS TABLE(voter_id bigint, user_id bigint, member_id character varying, voter_type character varying, registered_at timestamp with time zone)
 LANGUAGE sql
 STABLE
AS $function$
  SELECT 
    voter_id,
    user_id,
    member_id,
    voter_type,
    registered_at
  FROM voters
  WHERE organization_id = p_organization_id
    AND is_approved = FALSE
    AND status = 'PENDING'
  ORDER BY registered_at ASC;
$function$
;
