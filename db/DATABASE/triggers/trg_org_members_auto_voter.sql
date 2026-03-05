-- Trigger on table: org_members
CREATE TRIGGER trg_org_members_auto_voter AFTER INSERT OR UPDATE OF is_active ON org_members FOR EACH ROW EXECUTE FUNCTION tg_auto_register_voter();
