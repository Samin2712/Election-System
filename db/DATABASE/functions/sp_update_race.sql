CREATE OR REPLACE FUNCTION public.sp_update_race(p_race_id bigint, p_race_name text, p_description text, p_max_votes_per_voter integer, p_updated_by bigint)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_org_id BIGINT;
  v_election_status election_status;
  v_can_manage BOOLEAN;
BEGIN
  -- Get election details via race
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
  v_can_manage := is_org_admin(p_updated_by, v_org_id);
  
  IF NOT v_can_manage THEN
    RAISE EXCEPTION 'Not authorized to update race'
      USING ERRCODE = '28000';
  END IF;

  -- Can only update races in DRAFT elections
  IF v_election_status != 'DRAFT' THEN
    RAISE EXCEPTION 'Can only update races in DRAFT elections'
      USING ERRCODE = '22023';
  END IF;

  -- Validate max_votes_per_voter
  IF p_max_votes_per_voter < 1 THEN
    RAISE EXCEPTION 'max_votes_per_voter must be at least 1'
      USING ERRCODE = '22023';
  END IF;

  -- Update race
  UPDATE election_races
  SET
    race_name = p_race_name,
    description = p_description,
    max_votes_per_voter = p_max_votes_per_voter
  WHERE race_id = p_race_id;

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
    p_updated_by,
    'RACE_UPDATE',
    'election_races',
    p_race_id,
    jsonb_build_object('race_name', p_race_name)
  );
END;
$function$
;
