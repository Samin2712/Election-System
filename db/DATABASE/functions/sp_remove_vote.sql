CREATE OR REPLACE FUNCTION public.sp_remove_vote(p_voter_user_id bigint, p_race_id bigint, p_candidate_id bigint)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_voter_id BIGINT;
  v_vote_id BIGINT;
  v_org_id BIGINT;
BEGIN
  -- Get voter_id
  SELECT voter_id, organization_id INTO v_voter_id, v_org_id
  FROM voters
  WHERE user_id = p_voter_user_id
    AND is_approved = TRUE
    AND status = 'APPROVED';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Voter not found or not approved'
      USING ERRCODE = '28000';
  END IF;

  -- Delete the vote
  DELETE FROM votes
  WHERE voter_id = v_voter_id
    AND race_id = p_race_id
    AND candidate_race_id IN (
      SELECT candidate_race_id 
      FROM candidate_races 
      WHERE race_id = p_race_id 
        AND candidate_id = p_candidate_id
    )
  RETURNING vote_id INTO v_vote_id;

  IF v_vote_id IS NULL THEN
    RAISE EXCEPTION 'Vote not found'
      USING ERRCODE = '22023';
  END IF;

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
    p_voter_user_id,
    'VOTE_REMOVED',
    'votes',
    v_vote_id,
    jsonb_build_object(
      'race_id', p_race_id,
      'candidate_id', p_candidate_id
    )
  );
END;
$function$
;
