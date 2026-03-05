CREATE OR REPLACE FUNCTION public.sp_cast_vote(p_election_id bigint, p_race_id bigint, p_candidate_id bigint, p_voter_user_id bigint)
 RETURNS bigint
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_vote_id BIGINT;
  v_voter_id BIGINT;
  v_org_id BIGINT;
  v_election_status election_status;
  v_candidate_race_id BIGINT;
  v_max_votes INT;
  v_current_vote_count INT;
BEGIN
  -- Get election details
  SELECT organization_id, status
  INTO v_org_id, v_election_status
  FROM elections
  WHERE election_id = p_election_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Election not found'
      USING ERRCODE = '22023';
  END IF;

  -- Election must be OPEN
  IF v_election_status != 'OPEN' THEN
    RAISE EXCEPTION 'Election is not open for voting'
      USING ERRCODE = '22023';
  END IF;

  -- Verify race belongs to election and get max_votes_per_voter
  SELECT max_votes_per_voter INTO v_max_votes
  FROM election_races
  WHERE race_id = p_race_id
    AND election_id = p_election_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Race does not belong to this election'
      USING ERRCODE = '22023';
  END IF;

  -- Get voter_id and check if approved
  SELECT voter_id INTO v_voter_id
  FROM voters
  WHERE user_id = p_voter_user_id
    AND organization_id = v_org_id
    AND is_approved = TRUE
    AND status = 'APPROVED';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Voter not approved for this organization'
      USING ERRCODE = '28000';
  END IF;

  -- Get candidate_race_id and verify candidate is approved
  SELECT cr.candidate_race_id INTO v_candidate_race_id
  FROM candidate_races cr
  JOIN candidates c ON cr.candidate_id = c.candidate_id
  WHERE cr.race_id = p_race_id
    AND cr.candidate_id = p_candidate_id
    AND c.is_approved = TRUE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Candidate not found or not approved for this race'
      USING ERRCODE = '22023';
  END IF;

  -- Check if already voted for THIS SPECIFIC CANDIDATE
  IF EXISTS (
    SELECT 1 FROM votes
    WHERE voter_id = v_voter_id
      AND race_id = p_race_id
      AND candidate_race_id = v_candidate_race_id
  ) THEN
    RAISE EXCEPTION 'Already voted for this candidate in this race'
      USING ERRCODE = '23505';
  END IF;

  -- Check vote count limit (max_votes_per_voter)
  SELECT COUNT(*) INTO v_current_vote_count
  FROM votes
  WHERE voter_id = v_voter_id
    AND race_id = p_race_id;

  IF v_current_vote_count >= v_max_votes THEN
    RAISE EXCEPTION 'Maximum votes reached for this race (% votes allowed)', v_max_votes
      USING ERRCODE = '23505';
  END IF;

  -- Cast vote
  INSERT INTO votes (
    voter_id,
    race_id,
    candidate_race_id,
    cast_channel
  )
  VALUES (
    v_voter_id,
    p_race_id,
    v_candidate_race_id,
    'WEB'
  )
  RETURNING vote_id INTO v_vote_id;

  -- Audit log
  INSERT INTO audit_logs (
    organization_id,
    user_id,
    action_type,
    entity_name,
    entity_id,
    details_json
  )
  VALUES (
    v_org_id,
    p_voter_user_id,
    'VOTE_CAST',
    'votes',
    v_vote_id,
    jsonb_build_object(
      'election_id', p_election_id,
      'race_id', p_race_id,
      'candidate_id', p_candidate_id,
      'vote_count', v_current_vote_count + 1,
      'max_allowed', v_max_votes
    )
  );

  RETURN v_vote_id;
END;
$function$
;
