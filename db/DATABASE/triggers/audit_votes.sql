-- Trigger on table: votes
CREATE TRIGGER audit_votes AFTER INSERT OR DELETE OR UPDATE ON votes FOR EACH ROW EXECUTE FUNCTION trg_audit_generic();
