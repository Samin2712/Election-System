CREATE OR REPLACE FUNCTION public.sp_schedule_election(p_election_id bigint, p_start_datetime timestamp with time zone, p_end_datetime timestamp with time zone, p_scheduled_by bigint)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_org_id BIGINT;
  v_status election_status;
  v_race_count INT;
  v_candidate_count INT;
  v_can_schedule BOOLEAN;
BEGIN
  -- Get election details
  SELECT organization_id, status 
  INTO v_org_id, v_status
  FROM elections 
  WHERE election_id = p_election_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Election not found'
      USING ERRCODE = '22023';
  END IF;

  -- Check if user is OWNER/ADMIN
  v_can_schedule := is_org_admin(p_scheduled_by, v_org_id);
  
  IF NOT v_can_schedule THEN
    RAISE EXCEPTION 'Not authorized to schedule election'
      USING ERRCODE = '28000';
  END IF;

  -- Must be in DRAFT status
  IF v_status != 'DRAFT' THEN
    RAISE EXCEPTION 'Can only schedule elections in DRAFT status'
      USING ERRCODE = '22023';
  END IF;

  -- Validate dates
  IF p_end_datetime <= p_start_datetime THEN
    RAISE EXCEPTION 'End time must be after start time'
      USING ERRCODE = '22023';
  END IF;

  -- Start time must be in the future
  IF p_start_datetime <= NOW() THEN
    RAISE EXCEPTION 'Start time must be in the future'
      USING ERRCODE = '22023';
  END IF;

  -- Must have at least 1 race
  SELECT COUNT(*) INTO v_race_count
  FROM election_races
  WHERE election_id = p_election_id;

  IF v_race_count = 0 THEN
    RAISE EXCEPTION 'Election must have at least one race'
      USING ERRCODE = '22023';
  END IF;

  -- Each race must have at least 1 approved candidate
  SELECT COUNT(*) INTO v_candidate_count
  FROM election_races er
  WHERE er.election_id = p_election_id
    AND NOT EXISTS (
      SELECT 1 FROM candidate_races cr
      JOIN candidates c ON cr.candidate_id = c.candidate_id
      WHERE cr.race_id = er.race_id
        AND c.is_approved = TRUE
    );

  IF v_candidate_count > 0 THEN
    RAISE EXCEPTION 'Each race must have at least one approved candidate'
      USING ERRCODE = '22023';
  END IF;

  -- Schedule the election
  UPDATE elections
  SET 
    status = 'SCHEDULED',
    start_datetime = p_start_datetime,
    end_datetime = p_end_datetime
  WHERE election_id = p_election_id;

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
    p_scheduled_by,
    'ELECTION_SCHEDULED',
    'elections',
    p_election_id,
    jsonb_build_object(
      'start_datetime', p_start_datetime,
      'end_datetime', p_end_datetime
    )
  );
END;
$function$
;
