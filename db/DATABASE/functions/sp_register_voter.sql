CREATE OR REPLACE FUNCTION public.sp_register_voter(p_organization_id bigint, p_user_id bigint)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_member_id VARCHAR(80);
  v_member_type VARCHAR(50);
  v_voter_id BIGINT;
BEGIN
  -- Check if user is an active member in org_members
  IF NOT EXISTS (
    SELECT 1 FROM org_members
    WHERE organization_id = p_organization_id
      AND user_id = p_user_id
      AND is_active = TRUE
  ) THEN
    RAISE EXCEPTION 'User must be an active member of the organization'
      USING ERRCODE = '22023';
  END IF;

  -- Try to find matching member in org_member_master
  -- (This is optional - if no match, we'll use default values)
  SELECT member_id, member_type 
  INTO v_member_id, v_member_type
  FROM org_member_master
  WHERE organization_id = p_organization_id
    AND is_active = TRUE
  LIMIT 1;

  -- If no member found, use user_id as member_id
  IF v_member_id IS NULL THEN
    v_member_id := p_user_id::VARCHAR;
    v_member_type := 'USER';
  END IF;

  -- Insert voter (pending approval)
  INSERT INTO voters (
    user_id,
    organization_id,
    member_id,
    voter_type,
    status,
    is_approved
  )
  VALUES (
    p_user_id,
    p_organization_id,
    v_member_id,
    v_member_type,
    'PENDING',
    FALSE
  )
  ON CONFLICT (organization_id, user_id) 
  DO NOTHING;

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
    p_organization_id,
    p_user_id,
    'VOTER_REGISTER',
    'voters',
    p_user_id,
    jsonb_build_object('member_id', v_member_id)
  );
END;
$function$
;
