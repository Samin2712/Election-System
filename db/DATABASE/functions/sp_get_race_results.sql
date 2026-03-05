CREATE OR REPLACE FUNCTION public.sp_get_race_results(p_election_id bigint, p_race_id bigint)
 RETURNS TABLE(candidate_id bigint, display_name character varying, vote_count bigint)
 LANGUAGE sql
 STABLE
AS $function$
  SELECT 
    c.candidate_id,
    COALESCE(cr.display_name, c.full_name) AS display_name,
    COUNT(v.vote_id) AS vote_count
  FROM candidate_races cr
  JOIN candidates c ON cr.candidate_id = c.candidate_id
  LEFT JOIN votes v ON v.candidate_race_id = cr.candidate_race_id
  WHERE cr.race_id = p_race_id
  GROUP BY c.candidate_id, cr.display_name, c.full_name
  ORDER BY vote_count DESC, display_name ASC;
$function$
;
