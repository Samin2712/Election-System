CREATE OR REPLACE FUNCTION public.sp_create_race(p_election_id bigint, p_race_name text, p_description text, p_max_votes_per_voter integer, p_max_winners integer DEFAULT 1, p_created_by bigint DEFAULT NULL::bigint)
 RETURNS bigint
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_race_id BIGINT;
  v_org_id BIGINT;
  v_election_status election_status;
  v_can_manage BOOLEAN;
BEGIN
  -- Get election details
  SELECT organization_id, status
  INTO v_org_id, v_election_status
  FROM elections
  WHERE election_id = p_election_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Election not found'
      USING ERRCODE = '22023';
  END IF;

  -- Check if user is OWNER/ADMIN (if p_created_by is provided)
  IF p_created_by IS NOT NULL THEN
    v_can_manage := is_org_admin(p_created_by, v_org_id);
    
    IF NOT v_can_manage THEN
      RAISE EXCEPTION 'Not authorized to manage races'
        USING ERRCODE = '28000';
    END IF;
  END IF;

  -- Can only add races to DRAFT elections
  IF v_election_status != 'DRAFT' THEN
    RAISE EXCEPTION 'Can only add races to DRAFT elections'
      USING ERRCODE = '22023';
  END IF;

  -- Validate max_votes_per_voter
  IF p_max_votes_per_voter < 1 THEN
    RAISE EXCEPTION 'max_votes_per_voter must be at least 1'
      USING ERRCODE = '22023';
  END IF;

  -- Validate max_winners
  IF p_max_winners < 1 THEN
    RAISE EXCEPTION 'max_winners must be at least 1'
      USING ERRCODE = '22023';
  END IF;

  -- Insert race
  INSERT INTO election_races (
    election_id,
    race_name,
    description,
    max_votes_per_voter,
    max_winners
  )
  VALUES (
    p_election_id,
    p_race_name,
    p_description,
    p_max_votes_per_voter,
    p_max_winners
  )
  RETURNING race_id INTO v_race_id;

  -- Audit log (if user provided)
  IF p_created_by IS NOT NULL THEN
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
      p_created_by,
      'RACE_CREATE',
      'election_races',
      v_race_id,
      jsonb_build_object(
        'election_id', p_election_id,
        'race_name', p_race_name,
        'max_winners', p_max_winners
      )
    );
  END IF;

  RETURN v_race_id;
END;
$function$
;
