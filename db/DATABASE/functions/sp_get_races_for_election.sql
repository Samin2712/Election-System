CREATE OR REPLACE FUNCTION public.sp_get_races_for_election(p_election_id bigint)
 RETURNS TABLE(race_id bigint, race_name character varying, description text, max_votes_per_voter integer, max_winners integer, candidate_count bigint)
 LANGUAGE sql
 STABLE
AS $function$
  SELECT 
    er.race_id,
    er.race_name,
    er.description,
    er.max_votes_per_voter,
    er.max_winners,
    COUNT(cr.candidate_race_id) AS candidate_count
  FROM election_races er
  LEFT JOIN candidate_races cr ON er.race_id = cr.race_id
  WHERE er.election_id = p_election_id
  GROUP BY er.race_id, er.race_name, er.description, er.max_votes_per_voter, er.max_winners
  ORDER BY er.race_id;
$function$
;
