-- Trigger on table: candidate_races
CREATE TRIGGER audit_candidate_races AFTER INSERT OR DELETE OR UPDATE ON candidate_races FOR EACH ROW EXECUTE FUNCTION trg_audit_generic();
