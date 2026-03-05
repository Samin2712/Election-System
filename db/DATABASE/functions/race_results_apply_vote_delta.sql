CREATE OR REPLACE FUNCTION public.race_results_apply_vote_delta(p_race_id bigint, p_candidate_race_id bigint, p_delta integer)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
BEGIN
  INSERT INTO race_results(race_id, candidate_race_id, total_votes, last_updated)
  VALUES (p_race_id, p_candidate_race_id, GREATEST(p_delta,0), now())
  ON CONFLICT (race_id, candidate_race_id)
  DO UPDATE SET
    total_votes = GREATEST(race_results.total_votes + p_delta, 0),
    last_updated = now();
END;
$function$
;
