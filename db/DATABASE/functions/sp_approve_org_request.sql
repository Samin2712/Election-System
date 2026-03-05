CREATE OR REPLACE FUNCTION public.sp_approve_org_request(p_request_id bigint, p_admin_user_id bigint, p_admin_notes text DEFAULT NULL::text)
 RETURNS bigint
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_req RECORD;
  v_org_id BIGINT;
BEGIN
  -- Get and lock the request
  SELECT * INTO v_req
  FROM organization_requests
  WHERE request_id = p_request_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Request not found'
      USING ERRCODE = '22023';
  END IF;

  IF v_req.status != 'PENDING' THEN
    RAISE EXCEPTION 'Request has already been %', v_req.status
      USING ERRCODE = '22023';
  END IF;

  -- Create the organization using existing sp
  v_org_id := sp_create_organization(
    v_req.organization_name,
    v_req.organization_type,
    v_req.organization_code,
    v_req.requested_by
  );

  -- Mark request as approved
  UPDATE organization_requests
  SET
    status = 'APPROVED',
    admin_notes = p_admin_notes,
    reviewed_by = p_admin_user_id,
    reviewed_at = now(),
    updated_at = now()
  WHERE request_id = p_request_id;

  RETURN v_org_id;
END;
$function$
;
