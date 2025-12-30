BEGIN;

CREATE OR REPLACE FUNCTION race_results_apply_vote_delta(p_race_id bigint, p_candidate_race_id bigint, p_delta int)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  INSERT INTO race_results(race_id, candidate_race_id, total_votes, last_updated)
  VALUES (p_race_id, p_candidate_race_id, GREATEST(p_delta,0), now())
  ON CONFLICT (race_id, candidate_race_id)
  DO UPDATE SET
    total_votes = GREATEST(race_results.total_votes + p_delta, 0),
    last_updated = now();
END;
$$;

CREATE OR REPLACE FUNCTION trg_votes_to_results()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  -- Count only valid votes
  IF (TG_OP = 'INSERT') THEN
    IF NEW.is_valid THEN
      PERFORM race_results_apply_vote_delta(NEW.race_id, NEW.candidate_race_id, 1);
    END IF;
    RETURN NEW;
  ELSIF (TG_OP = 'DELETE') THEN
    IF OLD.is_valid THEN
      PERFORM race_results_apply_vote_delta(OLD.race_id, OLD.candidate_race_id, -1);
    END IF;
    RETURN OLD;
  ELSIF (TG_OP = 'UPDATE') THEN
    -- handle validity changes / candidate changes
    IF OLD.is_valid THEN
      PERFORM race_results_apply_vote_delta(OLD.race_id, OLD.candidate_race_id, -1);
    END IF;
    IF NEW.is_valid THEN
      PERFORM race_results_apply_vote_delta(NEW.race_id, NEW.candidate_race_id, 1);
    END IF;
    RETURN NEW;
  END IF;

  RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS trg_votes_to_results ON votes;
CREATE TRIGGER trg_votes_to_results
AFTER INSERT OR UPDATE OR DELETE ON votes
FOR EACH ROW EXECUTE FUNCTION trg_votes_to_results();

COMMIT;
