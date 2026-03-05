CREATE OR REPLACE FUNCTION public.sp_get_remaining_votes(p_race_id bigint, p_voter_user_id bigint, p_organization_id bigint)
 RETURNS TABLE(max_votes integer, votes_cast integer, votes_remaining integer)
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
  v_voter_id BIGINT;
  v_max_votes INT;
  v_votes_cast INT;
BEGIN
  -- Get max votes for race
  SELECT max_votes_per_voter INTO v_max_votes
  FROM election_races
  WHERE race_id = p_race_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Race not found'
      USING ERRCODE = '22023';
  END IF;

  -- Get voter_id
  SELECT voter_id INTO v_voter_id
  FROM voters
  WHERE user_id = p_voter_user_id
    AND organization_id = p_organization_id;

  IF NOT FOUND THEN
    -- Not registered as voter yet
    RETURN QUERY SELECT v_max_votes, 0, v_max_votes;
    RETURN;
  END IF;

  -- Count votes cast
  SELECT COUNT(*)::INT INTO v_votes_cast
  FROM votes
  WHERE voter_id = v_voter_id
    AND race_id = p_race_id;

  RETURN QUERY SELECT 
    v_max_votes,
    v_votes_cast,
    (v_max_votes - v_votes_cast) AS votes_remaining;
END;
$function$
;
