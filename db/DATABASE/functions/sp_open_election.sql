CREATE OR REPLACE FUNCTION public.sp_open_election(p_election_id bigint)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_start timestamptz;
  v_end   timestamptz;
BEGIN
  SELECT start_datetime, end_datetime INTO v_start, v_end
  FROM elections WHERE election_id = p_election_id;

  IF v_start IS NOT NULL AND v_end IS NOT NULL AND v_end <= v_start THEN
    RAISE EXCEPTION 'Invalid election window';
  END IF;

  UPDATE elections SET status = 'OPEN'
  WHERE election_id = p_election_id;

  INSERT INTO audit_logs(organization_id, user_id, action_type, entity_name, entity_id, details_json)
  VALUES (app_org_id(), app_actor_user_id(), 'OPEN_ELECTION', 'elections', p_election_id, NULL);
END;
$function$
;
