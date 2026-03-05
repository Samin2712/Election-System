CREATE OR REPLACE FUNCTION public.sp_get_elections_by_org(p_organization_id bigint)
 RETURNS TABLE(election_id bigint, election_name character varying, description text, start_datetime timestamp with time zone, end_datetime timestamp with time zone, status election_status, created_at timestamp with time zone, created_by bigint)
 LANGUAGE sql
 STABLE
AS $function$
  SELECT 
    election_id,
    election_name,
    description,
    start_datetime,
    end_datetime,
    status,
    created_at,
    created_by
  FROM elections
  WHERE organization_id = p_organization_id
  ORDER BY created_at DESC;
$function$
;
