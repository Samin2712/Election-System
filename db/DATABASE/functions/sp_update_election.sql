CREATE OR REPLACE FUNCTION public.sp_update_election(p_election_id bigint, p_election_name text, p_description text, p_start_at timestamp with time zone, p_end_at timestamp with time zone, p_updated_by bigint)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_org_id BIGINT;
  v_status election_status;
  v_can_update BOOLEAN;
BEGIN
  -- Get election org and status
  SELECT organization_id, status 
  INTO v_org_id, v_status
  FROM elections 
  WHERE election_id = p_election_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Election not found'
      USING ERRCODE = '22023';
  END IF;

  -- Check if user is OWNER/ADMIN
  v_can_update := is_org_admin(p_updated_by, v_org_id);
  
  IF NOT v_can_update THEN
    RAISE EXCEPTION 'Not authorized to update election'
      USING ERRCODE = '28000';
  END IF;

  -- Can update DRAFT or SCHEDULED elections (not OPEN or CLOSED)
  IF v_status NOT IN ('DRAFT', 'SCHEDULED') THEN
    RAISE EXCEPTION 'Can only update elections in DRAFT or SCHEDULED status'
      USING ERRCODE = '22023';
  END IF;

  -- Validate dates
  IF p_start_at IS NOT NULL AND p_end_at IS NOT NULL AND p_end_at <= p_start_at THEN
    RAISE EXCEPTION 'End time must be after start time'
      USING ERRCODE = '22023';
  END IF;

  -- Update election
  UPDATE elections
  SET 
    election_name = p_election_name,
    description = p_description,
    start_datetime = p_start_at,
    end_datetime = p_end_at
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
    p_updated_by,
    'ELECTION_UPDATE',
    'elections',
    p_election_id,
    jsonb_build_object(
      'election_name', p_election_name,
      'start_at', p_start_at,
      'end_at', p_end_at
    )
  );
END;
$function$
;
