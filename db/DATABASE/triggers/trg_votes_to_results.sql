-- Trigger on table: votes
CREATE TRIGGER trg_votes_to_results AFTER INSERT OR DELETE OR UPDATE ON votes FOR EACH ROW EXECUTE FUNCTION trg_votes_to_results();
