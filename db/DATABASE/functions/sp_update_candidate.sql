CREATE OR REPLACE FUNCTION public.sp_update_candidate(p_candidate_id bigint, p_full_name text, p_affiliation_name text, p_bio text, p_manifesto text, p_updated_by bigint, p_photo_url text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_org_id BIGINT;
  v_can_manage BOOLEAN;
BEGIN
  SELECT organization_id INTO v_org_id
  FROM candidates
  WHERE candidate_id = p_candidate_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Candidate not found'
      USING ERRCODE = '22023';
  END IF;

  v_can_manage := is_org_admin(p_updated_by, v_org_id);
  
  IF NOT v_can_manage THEN
    RAISE EXCEPTION 'Not authorized to update candidate'
      USING ERRCODE = '28000';
  END IF;

  UPDATE candidates
  SET
    full_name = p_full_name,
    affiliation_name = p_affiliation_name,
    bio = p_bio,
    manifesto = p_manifesto,
    photo_url = COALESCE(p_photo_url, photo_url)
  WHERE candidate_id = p_candidate_id;

  UPDATE candidate_races
  SET display_name = p_full_name
  WHERE candidate_id = p_candidate_id;

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
    'CANDIDATE_UPDATE',
    'candidates',
    p_candidate_id,
    jsonb_build_object('full_name', p_full_name)
  );
END;
$function$
;
