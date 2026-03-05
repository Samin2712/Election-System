CREATE OR REPLACE FUNCTION public.sp_close_election(p_election_id bigint, p_closed_by bigint)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_org_id BIGINT;
  v_status election_status;
  v_can_close BOOLEAN;
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
  v_can_close := is_org_admin(p_closed_by, v_org_id);
  
  IF NOT v_can_close THEN
    RAISE EXCEPTION 'Not authorized to close election'
      USING ERRCODE = '28000';
  END IF;

  -- Must be in OPEN status
  IF v_status != 'OPEN' THEN
    RAISE EXCEPTION 'Can only close elections in OPEN status'
      USING ERRCODE = '22023';
  END IF;

  -- Close the election
  UPDATE elections
  SET 
    status = 'CLOSED',
    end_datetime = COALESCE(end_datetime, now())
  WHERE election_id = p_election_id;

  -- Audit log
  INSERT INTO audit_logs (
    organization_id, 
    user_id, 
    action_type, 
    entity_name, 
    entity_id
  )
  VALUES (
    v_org_id,
    p_closed_by,
    'ELECTION_CLOSE',
    'elections',
    p_election_id
  );
END;
$function$
;
