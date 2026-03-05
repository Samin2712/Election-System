CREATE OR REPLACE FUNCTION public.sp_get_candidates_for_race(p_race_id bigint)
 RETURNS TABLE(candidate_id bigint, full_name character varying, affiliation_name character varying, bio text, manifesto text, photo_url text, is_approved boolean, ballot_order integer, display_name character varying)
 LANGUAGE sql
 STABLE
AS $function$
  SELECT
    c.candidate_id,
    c.full_name,
    c.affiliation_name,
    c.bio,
    c.manifesto,
    c.photo_url,
    c.is_approved,
    cr.ballot_order,
    cr.display_name
  FROM candidate_races cr
  JOIN candidates c ON cr.candidate_id = c.candidate_id
  WHERE cr.race_id = p_race_id
  ORDER BY cr.ballot_order NULLS LAST, c.full_name;
$function$
;
