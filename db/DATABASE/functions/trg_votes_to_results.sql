CREATE OR REPLACE FUNCTION public.trg_votes_to_results()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
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
$function$
;
