CREATE OR REPLACE FUNCTION public.sp_reject_org_request(p_request_id bigint, p_admin_user_id bigint, p_admin_notes text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_status org_request_status;
BEGIN
  SELECT status INTO v_status
  FROM organization_requests
  WHERE request_id = p_request_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Request not found'
      USING ERRCODE = '22023';
  END IF;

  IF v_status != 'PENDING' THEN
    RAISE EXCEPTION 'Request has already been %', v_status
      USING ERRCODE = '22023';
  END IF;

  UPDATE organization_requests
  SET
    status = 'REJECTED',
    admin_notes = p_admin_notes,
    reviewed_by = p_admin_user_id,
    reviewed_at = now(),
    updated_at = now()
  WHERE request_id = p_request_id;
END;
$function$
;
