BEGIN;

-- 1) Org members table (AUTH users + roles)
-- NOTE: assumes user_accounts has primary key user_id (INT)
CREATE TABLE IF NOT EXISTS org_members (
  organization_id INT NOT NULL REFERENCES organizations(organization_id) ON DELETE CASCADE,
  user_id INT NOT NULL REFERENCES user_accounts(user_id) ON DELETE CASCADE,
  role_name TEXT NOT NULL CHECK (role_name IN ('OWNER', 'ADMIN', 'MEMBER')),
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (organization_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_org_members_user_id ON org_members(user_id);
CREATE INDEX IF NOT EXISTS idx_org_members_org_id ON org_members(organization_id);


-- 2) Create organization + add creator as OWNER + audit log (FIXED columns)
CREATE OR REPLACE FUNCTION sp_create_organization(
  p_organization_name  TEXT,
  p_organization_type  TEXT,
  p_organization_code  TEXT,
  p_created_by_user_id INT
)
RETURNS INT
LANGUAGE plpgsql
AS $$
DECLARE
  v_org_id INT;
BEGIN
  INSERT INTO organizations (organization_name, organization_type, organization_code)
  VALUES (p_organization_name, p_organization_type, p_organization_code)
  RETURNING organization_id INTO v_org_id;

  INSERT INTO org_members (organization_id, user_id, role_name, is_active)
  VALUES (v_org_id, p_created_by_user_id, 'OWNER', TRUE)
  ON CONFLICT (organization_id, user_id)
  DO UPDATE SET role_name = EXCLUDED.role_name, is_active = TRUE;

  -- ✅ audit_logs columns from your pgAdmin:
  -- (organization_id, user_id, action_type, entity_name, entity_id, details_json, action_timestamp)
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
$$;


-- 3) Add org member (only OWNER/ADMIN can add) + audit log (FIXED columns)
CREATE OR REPLACE FUNCTION sp_add_org_member(
  p_organization_id   INT,
  p_user_id           INT,
  p_role_name         TEXT,
  p_added_by_user_id  INT
)
RETURNS VOID
LANGUAGE plpgsql
AS $$
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
$$;


-- 4) List org members
CREATE OR REPLACE FUNCTION sp_get_org_members(
  p_organization_id INT
)
RETURNS TABLE (
  user_id INT,
  role_name TEXT,
  is_active BOOLEAN,
  joined_at TIMESTAMPTZ
)
LANGUAGE sql
AS $$
  SELECT user_id, role_name, is_active, created_at AS joined_at
  FROM org_members
  WHERE organization_id = p_organization_id
  ORDER BY created_at ASC;
$$;

COMMIT;
