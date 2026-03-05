CREATE OR REPLACE FUNCTION public.sp_submit_org_request(p_user_id bigint, p_org_name text, p_org_type text, p_org_code text, p_purpose text DEFAULT NULL::text, p_expected_members integer DEFAULT NULL::integer, p_proof_url text DEFAULT NULL::text)
 RETURNS bigint
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_request_id BIGINT;
  v_existing_code BIGINT;
  v_pending_count INT;
BEGIN
  -- Check if org code already exists in organizations
  SELECT organization_id INTO v_existing_code
  FROM organizations
  WHERE organization_code = p_org_code;

  IF FOUND THEN
    RAISE EXCEPTION 'Organization code already exists'
      USING ERRCODE = '23505';
  END IF;

  -- Check if user already has a pending request for this code
  SELECT COUNT(*) INTO v_pending_count
  FROM organization_requests
  WHERE requested_by = p_user_id
    AND organization_code = p_org_code
    AND status = 'PENDING';

  IF v_pending_count > 0 THEN
    RAISE EXCEPTION 'You already have a pending request for this organization code'
      USING ERRCODE = '23505';
  END IF;

  INSERT INTO organization_requests (
    requested_by,
    organization_name,
    organization_type,
    organization_code,
    purpose,
    expected_members,
    proof_document_url
  )
  VALUES (
    p_user_id,
    p_org_name,
    p_org_type,
    p_org_code,
    p_purpose,
    p_expected_members,
    p_proof_url
  )
  RETURNING request_id INTO v_request_id;

  RETURN v_request_id;
END;
$function$
;
