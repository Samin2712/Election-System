CREATE OR REPLACE FUNCTION public.sp_get_voter_race_votes(p_voter_user_id bigint, p_race_id bigint)
 RETURNS TABLE(candidate_id bigint, candidate_name character varying, vote_id bigint, cast_at timestamp with time zone)
 LANGUAGE sql
 STABLE
AS $function$
  SELECT 
    c.candidate_id,
    c.full_name AS candidate_name,
    v.vote_id,
    v.cast_at
  FROM votes v
  JOIN voters vr ON v.voter_id = vr.voter_id
  JOIN candidate_races cr ON v.candidate_race_id = cr.candidate_race_id
  JOIN candidates c ON cr.candidate_id = c.candidate_id
  WHERE vr.user_id = p_voter_user_id
    AND v.race_id = p_race_id
  ORDER BY v.cast_at ASC;
$function$
;
