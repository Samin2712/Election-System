CREATE OR REPLACE FUNCTION public.sp_approve_voter(p_organization_id bigint, p_user_id bigint, p_approved_by bigint)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_can_approve BOOLEAN;
BEGIN
  -- Check if approver is OWNER/ADMIN
  v_can_approve := is_org_admin(p_approved_by, p_organization_id);
  
  IF NOT v_can_approve THEN
    RAISE EXCEPTION 'Not authorized to approve voters'
      USING ERRCODE = '28000';
  END IF;

  -- Check if voter exists
  IF NOT EXISTS (
    SELECT 1 FROM voters
    WHERE organization_id = p_organization_id
      AND user_id = p_user_id
  ) THEN
    RAISE EXCEPTION 'Voter registration not found'
      USING ERRCODE = '22023';
  END IF;

  -- Approve voter
  UPDATE voters
  SET 
    status = 'APPROVED',
    is_approved = TRUE,
    approved_by = p_approved_by,
    approved_at = now()
  WHERE organization_id = p_organization_id
    AND user_id = p_user_id;

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
    p_approved_by,
    'VOTER_APPROVE',
    'voters',
    p_user_id,
    jsonb_build_object('approved_user_id', p_user_id)
  );
END;
$function$
;
