BEGIN;

CREATE OR REPLACE FUNCTION enforce_vote_rules()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_election_id bigint;
  v_org_id bigint;
  v_status election_status;
  v_start timestamptz;
  v_end   timestamptz;

  v_voter_org bigint;
  v_voter_status voter_status;
  v_member_type text;

  v_candidate_race_race_id bigint;
BEGIN
  -- 1) race -> election
  SELECT r.election_id INTO v_election_id
  FROM election_races r
  WHERE r.race_id = NEW.race_id;

  IF v_election_id IS NULL THEN
    RAISE EXCEPTION 'Invalid race_id: %', NEW.race_id;
  END IF;

  -- 2) election info
  SELECT organization_id, status, start_datetime, end_datetime
    INTO v_org_id, v_status, v_start, v_end
  FROM elections
  WHERE election_id = v_election_id;

  IF v_status <> 'OPEN' THEN
    RAISE EXCEPTION 'Election is not OPEN (status=%)', v_status;
  END IF;

  IF v_start IS NOT NULL AND now() < v_start THEN
    RAISE EXCEPTION 'Voting has not started yet';
  END IF;

  IF v_end IS NOT NULL AND now() > v_end THEN
    RAISE EXCEPTION 'Voting has ended';
  END IF;

  -- 3) voter checks
  SELECT organization_id, status, voter_type
    INTO v_voter_org, v_voter_status, v_member_type
  FROM voters
  WHERE voter_id = NEW.voter_id;

  IF v_voter_org IS NULL THEN
    RAISE EXCEPTION 'Invalid voter_id: %', NEW.voter_id;
  END IF;

  IF v_voter_status <> 'APPROVED' THEN
    RAISE EXCEPTION 'Voter is not APPROVED (status=%)', v_voter_status;
  END IF;

  IF v_voter_org <> v_org_id THEN
    RAISE EXCEPTION 'Voter organization mismatch';
  END IF;

  -- 4) eligible member type for election
  IF NOT EXISTS (
    SELECT 1
    FROM election_eligible_member_types eemt
    WHERE eemt.election_id = v_election_id
      AND eemt.member_type = v_member_type
  ) THEN
    RAISE EXCEPTION 'Voter type % is not eligible for this election', v_member_type;
  END IF;

  -- 5) candidate_race must belong to same race
  SELECT cr.race_id INTO v_candidate_race_race_id
  FROM candidate_races cr
  WHERE cr.candidate_race_id = NEW.candidate_race_id;

  IF v_candidate_race_race_id IS NULL THEN
    RAISE EXCEPTION 'Invalid candidate_race_id: %', NEW.candidate_race_id;
  END IF;

  IF v_candidate_race_race_id <> NEW.race_id THEN
    RAISE EXCEPTION 'Candidate is not running in this race';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_enforce_vote_rules ON votes;
CREATE TRIGGER trg_enforce_vote_rules
BEFORE INSERT ON votes
FOR EACH ROW EXECUTE FUNCTION enforce_vote_rules();

COMMIT;
