-- Trigger on table: elections
CREATE TRIGGER audit_elections AFTER INSERT OR DELETE OR UPDATE ON elections FOR EACH ROW EXECUTE FUNCTION trg_audit_generic();
