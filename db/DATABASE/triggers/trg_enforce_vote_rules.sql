-- Trigger on table: votes
CREATE TRIGGER trg_enforce_vote_rules BEFORE INSERT ON votes FOR EACH ROW EXECUTE FUNCTION enforce_vote_rules();
