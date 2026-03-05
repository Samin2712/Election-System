CREATE OR REPLACE FUNCTION public.sp_remove_candidate_from_race(p_race_id bigint, p_candidate_id bigint, p_removed_by bigint)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_org_id BIGINT;
  v_election_status election_status;
  v_can_manage BOOLEAN;
BEGIN
  -- Get election details
  SELECT e.organization_id, e.status
  INTO v_org_id, v_election_status
  FROM election_races er
  JOIN elections e ON er.election_id = e.election_id
  WHERE er.race_id = p_race_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Race not found'
      USING ERRCODE = '22023';
  END IF;

  -- Check if user is OWNER/ADMIN
  v_can_manage := is_org_admin(p_removed_by, v_org_id);
  
  IF NOT v_can_manage THEN
    RAISE EXCEPTION 'Not authorized to remove candidates'
      USING ERRCODE = '28000';
  END IF;

  -- Can only remove candidates from DRAFT elections
  IF v_election_status != 'DRAFT' THEN
    RAISE EXCEPTION 'Can only remove candidates from DRAFT elections'
      USING ERRCODE = '22023';
  END IF;

  -- Remove candidate from race
  DELETE FROM candidate_races
  WHERE race_id = p_race_id AND candidate_id = p_candidate_id;

  -- Audit log
  INSERT INTO audit_logs (
    organization_id,
    user_id,
    action_type,
    entity_name,
    entity_id,
    details_json
  )
  VALUES (
    v_org_id,
    p_removed_by,
    'CANDIDATE_REMOVE',
    'candidate_races',
    p_candidate_id,
    jsonb_build_object('race_id', p_race_id)
  );
END;
$function$
;
