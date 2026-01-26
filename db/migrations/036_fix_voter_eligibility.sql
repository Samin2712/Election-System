-- Migration 036: Fix Voter Eligibility - Auto-add USER type to elections
-- This fixes the "Voter type USER is not eligible for this election" error

BEGIN;

-- 1. Add USER as eligible member type to all existing elections
INSERT INTO election_eligible_member_types (election_id, member_type)
SELECT election_id, 'USER'
FROM elections
WHERE NOT EXISTS (
    SELECT 1 
    FROM election_eligible_member_types 
    WHERE election_eligible_member_types.election_id = elections.election_id 
    AND member_type = 'USER'
);

-- 2. Update sp_create_election to automatically add USER as eligible type
CREATE OR REPLACE FUNCTION sp_create_election(
  p_organization_id BIGINT,
  p_election_name TEXT,
  p_description TEXT,
  p_created_by_user_id BIGINT
)
RETURNS BIGINT
LANGUAGE plpgsql
AS $$
DECLARE
  v_election_id BIGINT;
  v_can_create BOOLEAN;
BEGIN
  -- Check if user is OWNER/ADMIN
  v_can_create := is_org_admin(p_created_by_user_id, p_organization_id);
  
  IF NOT v_can_create THEN
    RAISE EXCEPTION 'Not authorized to create elections'
      USING ERRCODE = '28000';
  END IF;

  -- Insert election
  INSERT INTO elections (
    organization_id, 
    election_name, 
    description, 
    status, 
    created_by
  )
  VALUES (
    p_organization_id,
    p_election_name,
    p_description,
    'DRAFT',
    p_created_by_user_id
  )
  RETURNING election_id INTO v_election_id;

  -- Automatically add USER as eligible member type
  INSERT INTO election_eligible_member_types (election_id, member_type)
  VALUES (v_election_id, 'USER');

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
    p_created_by_user_id,
    'ELECTION_CREATE',
    'elections',
    v_election_id,
    jsonb_build_object(
      'election_name', p_election_name,
      'description', p_description
    )
  );

  RETURN v_election_id;
END;
$$;

COMMIT;
