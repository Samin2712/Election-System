CREATE OR REPLACE FUNCTION public.sp_add_candidate_to_race(p_race_id bigint, p_full_name text, p_affiliation_name text, p_bio text, p_manifesto text, p_ballot_order integer, p_added_by bigint, p_photo_url text DEFAULT NULL::text)
 RETURNS bigint
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_candidate_id BIGINT;
  v_candidate_race_id BIGINT;
  v_org_id BIGINT;
  v_election_id BIGINT;
  v_election_status election_status;
  v_can_manage BOOLEAN;
BEGIN
  -- Get election details via race
  SELECT e.organization_id, e.election_id, e.status
  INTO v_org_id, v_election_id, v_election_status
  FROM election_races er
  JOIN elections e ON er.election_id = e.election_id
  WHERE er.race_id = p_race_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Race not found'
      USING ERRCODE = '22023';
  END IF;

  v_can_manage := is_org_admin(p_added_by, v_org_id);
  
  IF NOT v_can_manage THEN
    RAISE EXCEPTION 'Not authorized to add candidates'
      USING ERRCODE = '28000';
  END IF;

  IF v_election_status != 'DRAFT' THEN
    RAISE EXCEPTION 'Can only add candidates to DRAFT elections'
      USING ERRCODE = '22023';
  END IF;

  -- Create candidate with photo_url
  INSERT INTO candidates (
    full_name,
    affiliation_name,
    bio,
    manifesto,
    photo_url,
    is_approved,
    organization_id
  )
  VALUES (
    p_full_name,
    p_affiliation_name,
    p_bio,
    p_manifesto,
    p_photo_url,
    TRUE,
    v_org_id
  )
  RETURNING candidate_id INTO v_candidate_id;

  -- Link candidate to race
  INSERT INTO candidate_races (
    race_id,
    candidate_id,
    ballot_order,
    display_name
  )
  VALUES (
    p_race_id,
    v_candidate_id,
    p_ballot_order,
    p_full_name
  )
  RETURNING candidate_race_id INTO v_candidate_race_id;

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
    p_added_by,
    'CANDIDATE_ADD',
    'candidates',
    v_candidate_id,
    jsonb_build_object(
      'race_id', p_race_id,
      'full_name', p_full_name
    )
  );

  RETURN v_candidate_id;
END;
$function$
;
