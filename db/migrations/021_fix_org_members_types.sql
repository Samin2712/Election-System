-- Migration 021: Fix type mismatch in org_members table
-- The org_members table uses INT but should use BIGINT to match user_accounts and organizations tables

BEGIN;

-- Drop dependent views/functions first if any exist
-- (none in this case, is_org_admin uses org_members directly)

-- Alter org_members to use BIGINT instead of INT
ALTER TABLE org_members 
  ALTER COLUMN organization_id TYPE BIGINT,
  ALTER COLUMN user_id TYPE BIGINT;

-- Recreate sp_create_organization to use BIGINT
CREATE OR REPLACE FUNCTION sp_create_organization(
  p_organization_name  TEXT,
  p_organization_type  TEXT,
  p_organization_code  TEXT,
  p_created_by_user_id BIGINT  -- Changed from INT to BIGINT
)
RETURNS BIGINT  -- Changed from INT to BIGINT
LANGUAGE plpgsql
AS $$
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
$$;

-- Recreate sp_add_org_member to use BIGINT
CREATE OR REPLACE FUNCTION sp_add_org_member(
  p_organization_id   BIGINT,  -- Changed from INT to BIGINT
  p_user_id           BIGINT,  -- Changed from INT to BIGINT
  p_role_name         TEXT,
  p_added_by_user_id  BIGINT   -- Changed from INT to BIGINT
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

-- Recreate sp_get_org_members to use BIGINT
CREATE OR REPLACE FUNCTION sp_get_org_members(
  p_organization_id BIGINT  -- Changed from INT to BIGINT
)
RETURNS TABLE (
  user_id BIGINT,  -- Changed from INT to BIGINT
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
