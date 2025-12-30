BEGIN;

-- Cast a vote safely (relies on enforce_vote_rules trigger)
CREATE OR REPLACE FUNCTION sp_cast_vote(
  p_voter_id bigint,
  p_race_id bigint,
  p_candidate_race_id bigint,
  p_channel vote_channel DEFAULT 'WEB'
)
RETURNS bigint
LANGUAGE plpgsql
AS $$
DECLARE
  v_vote_id bigint;
BEGIN
  INSERT INTO votes(voter_id, race_id, candidate_race_id, cast_channel)
  VALUES (p_voter_id, p_race_id, p_candidate_race_id, p_channel)
  RETURNING vote_id INTO v_vote_id;

  -- Optional: add a semantic audit action row (in addition to generic trigger)
  INSERT INTO audit_logs(organization_id, user_id, action_type, entity_name, entity_id, details_json)
  VALUES (
    app_org_id(),
    app_actor_user_id(),
    'CAST_VOTE',
    'votes',
    v_vote_id,
    jsonb_build_object('race_id', p_race_id, 'candidate_race_id', p_candidate_race_id)
  );

  RETURN v_vote_id;
END;
$$;

-- Open election (sets status to OPEN if timing is valid)
CREATE OR REPLACE FUNCTION sp_open_election(p_election_id bigint)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
  v_start timestamptz;
  v_end   timestamptz;
BEGIN
  SELECT start_datetime, end_datetime INTO v_start, v_end
  FROM elections WHERE election_id = p_election_id;

  IF v_start IS NOT NULL AND v_end IS NOT NULL AND v_end <= v_start THEN
    RAISE EXCEPTION 'Invalid election window';
  END IF;

  UPDATE elections SET status = 'OPEN'
  WHERE election_id = p_election_id;

  INSERT INTO audit_logs(organization_id, user_id, action_type, entity_name, entity_id, details_json)
  VALUES (app_org_id(), app_actor_user_id(), 'OPEN_ELECTION', 'elections', p_election_id, NULL);
END;
$$;

-- Close election
CREATE OR REPLACE FUNCTION sp_close_election(p_election_id bigint)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  UPDATE elections SET status = 'CLOSED'
  WHERE election_id = p_election_id;

  INSERT INTO audit_logs(organization_id, user_id, action_type, entity_name, entity_id, details_json)
  VALUES (app_org_id(), app_actor_user_id(), 'CLOSE_ELECTION', 'elections', p_election_id, NULL);
END;
$$;

COMMIT;
