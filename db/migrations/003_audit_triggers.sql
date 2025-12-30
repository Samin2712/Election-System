BEGIN;

-- Session vars (set from Node per request/transaction)
CREATE OR REPLACE FUNCTION app_actor_user_id()
RETURNS bigint
LANGUAGE sql
AS $$
  SELECT NULLIF(current_setting('app.actor_user_id', true), '')::bigint;
$$;

CREATE OR REPLACE FUNCTION app_org_id()
RETURNS bigint
LANGUAGE sql
AS $$
  SELECT NULLIF(current_setting('app.organization_id', true), '')::bigint;
$$;

CREATE OR REPLACE FUNCTION app_request_id()
RETURNS text
LANGUAGE sql
AS $$
  SELECT NULLIF(current_setting('app.request_id', true), '');
$$;

-- Generic audit trigger: writes to audit_logs.details_json
CREATE OR REPLACE FUNCTION trg_audit_generic()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_entity_id bigint;
BEGIN
  -- Your PK names differ per table, so we try common ones:
  -- if table has *_id columns, you can customize per table later.
  v_entity_id :=
    COALESCE(
      (to_jsonb(COALESCE(NEW, OLD)) ->> 'vote_id')::bigint,
      (to_jsonb(COALESCE(NEW, OLD)) ->> 'election_id')::bigint,
      (to_jsonb(COALESCE(NEW, OLD)) ->> 'race_id')::bigint,
      (to_jsonb(COALESCE(NEW, OLD)) ->> 'voter_id')::bigint,
      (to_jsonb(COALESCE(NEW, OLD)) ->> 'candidate_race_id')::bigint,
      (to_jsonb(COALESCE(NEW, OLD)) ->> 'candidate_id')::bigint,
      (to_jsonb(COALESCE(NEW, OLD)) ->> 'organization_id')::bigint,
      (to_jsonb(COALESCE(NEW, OLD)) ->> 'user_id')::bigint
    );

  INSERT INTO audit_logs(
    organization_id,
    user_id,
    action_type,
    entity_name,
    entity_id,
    details_json
  )
  VALUES (
    COALESCE(app_org_id(), (to_jsonb(COALESCE(NEW, OLD)) ->> 'organization_id')::bigint),
    app_actor_user_id(),
    TG_OP,
    TG_TABLE_NAME,
    v_entity_id,
    jsonb_build_object(
      'request_id', app_request_id(),
      'old', CASE WHEN TG_OP IN ('UPDATE','DELETE') THEN to_jsonb(OLD) ELSE NULL END,
      'new', CASE WHEN TG_OP IN ('INSERT','UPDATE') THEN to_jsonb(NEW) ELSE NULL END
    )
  );

  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  END IF;
  RETURN NEW;
END;
$$;

-- Attach auditing to key mutable tables
DO $$
BEGIN
  -- votes
  EXECUTE 'DROP TRIGGER IF EXISTS audit_votes ON votes';
  EXECUTE 'CREATE TRIGGER audit_votes AFTER INSERT OR UPDATE OR DELETE ON votes FOR EACH ROW EXECUTE FUNCTION trg_audit_generic()';

  -- elections
  EXECUTE 'DROP TRIGGER IF EXISTS audit_elections ON elections';
  EXECUTE 'CREATE TRIGGER audit_elections AFTER INSERT OR UPDATE OR DELETE ON elections FOR EACH ROW EXECUTE FUNCTION trg_audit_generic()';

  -- voters
  EXECUTE 'DROP TRIGGER IF EXISTS audit_voters ON voters';
  EXECUTE 'CREATE TRIGGER audit_voters AFTER INSERT OR UPDATE OR DELETE ON voters FOR EACH ROW EXECUTE FUNCTION trg_audit_generic()';

  -- candidate_races
  EXECUTE 'DROP TRIGGER IF EXISTS audit_candidate_races ON candidate_races';
  EXECUTE 'CREATE TRIGGER audit_candidate_races AFTER INSERT OR UPDATE OR DELETE ON candidate_races FOR EACH ROW EXECUTE FUNCTION trg_audit_generic()';
END $$;

COMMIT;
