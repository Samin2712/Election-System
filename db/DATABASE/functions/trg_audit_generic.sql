CREATE OR REPLACE FUNCTION public.trg_audit_generic()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
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
$function$
;
