CREATE OR REPLACE FUNCTION public.sp_add_org_member(p_organization_id integer, p_user_id integer, p_role_name text, p_added_by_user_id integer)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_can_manage BOOLEAN;
BEGIN
  IF p_role_name NOT IN ('OWNER', 'ADMIN', 'MEMBER') THEN
    RAISE EXCEPTION 'Invalid role_name: %', p_role_name
      USING ERRCODE = '22023';
  END IF;

  SELECT EXISTS (
    SELECT 1
    FROM org_members
    WHERE organization_id = p_organization_id
      AND user_id = p_added_by_user_id
      AND is_active = TRUE
      AND role_name IN ('OWNER', 'ADMIN')
  )
  INTO v_can_manage;

  IF NOT v_can_manage THEN
    RAISE EXCEPTION 'Not authorized to add members'
      USING ERRCODE = '28000';
  END IF;

  INSERT INTO org_members (organization_id, user_id, role_name, is_active)
  VALUES (p_organization_id, p_user_id, p_role_name, TRUE)
  ON CONFLICT (organization_id, user_id)
  DO UPDATE SET role_name = EXCLUDED.role_name, is_active = TRUE;

  INSERT INTO audit_logs (organization_id, user_id, action_type, entity_name, entity_id, details_json)
  VALUES (
    p_organization_id,
    p_added_by_user_id,
    'ORG_ADD_MEMBER',
    'org_members',
    p_organization_id,
    jsonb_build_object('added_user_id', p_user_id, 'role_name', p_role_name)
  );
END;
$function$
;
