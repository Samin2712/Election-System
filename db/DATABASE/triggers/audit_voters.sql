-- Trigger on table: voters
CREATE TRIGGER audit_voters AFTER INSERT OR DELETE OR UPDATE ON voters FOR EACH ROW EXECUTE FUNCTION trg_audit_generic();
