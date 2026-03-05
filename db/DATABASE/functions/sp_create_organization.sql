CREATE OR REPLACE FUNCTION public.sp_create_organization(p_organization_name text, p_organization_type text, p_organization_code text, p_created_by_user_id bigint)
 RETURNS bigint
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_org_id BIGINT;  -- Changed from INT to BIGINT
BEGIN
  INSERT INTO organizations (organization_name, organization_type, organization_code)
  VALUES (p_organization_name, p_organization_type, p_organization_code)
  RETURNING organization_id INTO v_org_id;

  INSERT INTO org_members (organization_id, user_id, role_name, is_active)
  VALUES (v_org_id, p_created_by_user_id, 'OWNER', TRUE)
  ON CONFLICT (organization_id, user_id)
  DO UPDATE SET role_name = EXCLUDED.role_name, is_active = TRUE;

  INSERT INTO audit_logs (organization_id, user_id, action_type, entity_name, entity_id, details_json)
  VALUES (
    v_org_id,
    p_created_by_user_id,
    'ORG_CREATE',
    'organizations',
    v_org_id,
    jsonb_build_object(
      'organization_name', p_organization_name,
      'organization_type', p_organization_type,
      'organization_code', p_organization_code
    )
  );

  RETURN v_org_id;
END;
$function$
;
