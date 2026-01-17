BEGIN;

-- =====================================================
-- PHASE 4: ELECTION MANAGEMENT
-- Extends existing elections, election_races, candidates tables
-- Adds stored procedures for election lifecycle
-- =====================================================

-- 1) Add created_by column to elections if not exists
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'elections' AND column_name = 'created_by'
  ) THEN
    ALTER TABLE elections ADD COLUMN created_by BIGINT REFERENCES user_accounts(user_id);
  END IF;
END $$;

-- 2) Add max_winners column to election_races if not exists
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'election_races' AND column_name = 'max_winners'
  ) THEN
    ALTER TABLE election_races ADD COLUMN max_winners INT NOT NULL DEFAULT 1;
  END IF;
END $$;

-- 3) Add is_approved column to candidates if not exists
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'candidates' AND column_name = 'is_approved'
  ) THEN
    ALTER TABLE candidates ADD COLUMN is_approved BOOLEAN NOT NULL DEFAULT TRUE;
  END IF;
END $$;

-- 4) Add manifesto column to candidates if not exists
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'candidates' AND column_name = 'manifesto'
  ) THEN
    ALTER TABLE candidates ADD COLUMN manifesto TEXT;
  END IF;
END $$;

-- 5) Link candidates to org_member_master
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'candidates' AND column_name = 'organization_id'
  ) THEN
    ALTER TABLE candidates ADD COLUMN organization_id BIGINT REFERENCES organizations(organization_id);
    ALTER TABLE candidates ADD COLUMN member_id VARCHAR(80);
  END IF;
END $$;

-- =====================================================
-- STORED PROCEDURES FOR ELECTION MANAGEMENT
-- =====================================================

-- Helper: Check if user is OWNER or ADMIN of organization
CREATE OR REPLACE FUNCTION is_org_admin(p_user_id BIGINT, p_organization_id BIGINT)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1 FROM org_members
    WHERE organization_id = p_organization_id
      AND user_id = p_user_id
      AND is_active = TRUE
      AND role_name IN ('OWNER', 'ADMIN')
  );
$$;

-- 1) CREATE ELECTION
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

-- 2) UPDATE ELECTION (only in DRAFT status)
CREATE OR REPLACE FUNCTION sp_update_election(
  p_election_id BIGINT,
  p_election_name TEXT,
  p_description TEXT,
  p_start_at TIMESTAMPTZ,
  p_end_at TIMESTAMPTZ,
  p_updated_by BIGINT
)
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
  v_org_id BIGINT;
  v_status election_status;
  v_can_update BOOLEAN;
BEGIN
  -- Get election org and status
  SELECT organization_id, status 
  INTO v_org_id, v_status
  FROM elections 
  WHERE election_id = p_election_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Election not found'
      USING ERRCODE = '22023';
  END IF;

  -- Check if user is OWNER/ADMIN
  v_can_update := is_org_admin(p_updated_by, v_org_id);
  
  IF NOT v_can_update THEN
    RAISE EXCEPTION 'Not authorized to update election'
      USING ERRCODE = '28000';
  END IF;

  -- Can only update DRAFT elections
  IF v_status != 'DRAFT' THEN
    RAISE EXCEPTION 'Can only update elections in DRAFT status'
      USING ERRCODE = '22023';
  END IF;

  -- Validate dates
  IF p_start_at IS NOT NULL AND p_end_at IS NOT NULL AND p_end_at <= p_start_at THEN
    RAISE EXCEPTION 'End time must be after start time'
      USING ERRCODE = '22023';
  END IF;

  -- Update election
  UPDATE elections
  SET 
    election_name = p_election_name,
    description = p_description,
    start_datetime = p_start_at,
    end_datetime = p_end_at
  WHERE election_id = p_election_id;

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
    v_org_id,
    p_updated_by,
    'ELECTION_UPDATE',
    'elections',
    p_election_id,
    jsonb_build_object(
      'election_name', p_election_name,
      'start_at', p_start_at,
      'end_at', p_end_at
    )
  );
END;
$$;

-- 3) OPEN ELECTION (with validation)
CREATE OR REPLACE FUNCTION sp_open_election(
  p_election_id BIGINT,
  p_opened_by BIGINT
)
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
  v_org_id BIGINT;
  v_status election_status;
  v_race_count INT;
  v_candidate_count INT;
  v_can_open BOOLEAN;
BEGIN
  -- Get election details
  SELECT organization_id, status 
  INTO v_org_id, v_status
  FROM elections 
  WHERE election_id = p_election_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Election not found'
      USING ERRCODE = '22023';
  END IF;

  -- Check if user is OWNER/ADMIN
  v_can_open := is_org_admin(p_opened_by, v_org_id);
  
  IF NOT v_can_open THEN
    RAISE EXCEPTION 'Not authorized to open election'
      USING ERRCODE = '28000';
  END IF;

  -- Must be in DRAFT status
  IF v_status != 'DRAFT' THEN
    RAISE EXCEPTION 'Can only open elections in DRAFT status'
      USING ERRCODE = '22023';
  END IF;

  -- Must have at least 1 race
  SELECT COUNT(*) INTO v_race_count
  FROM election_races
  WHERE election_id = p_election_id;

  IF v_race_count = 0 THEN
    RAISE EXCEPTION 'Election must have at least one race'
      USING ERRCODE = '22023';
  END IF;

  -- Each race must have at least 1 approved candidate
  SELECT COUNT(*) INTO v_candidate_count
  FROM election_races er
  WHERE er.election_id = p_election_id
    AND NOT EXISTS (
      SELECT 1 FROM candidate_races cr
      JOIN candidates c ON cr.candidate_id = c.candidate_id
      WHERE cr.race_id = er.race_id
        AND c.is_approved = TRUE
    );

  IF v_candidate_count > 0 THEN
    RAISE EXCEPTION 'Each race must have at least one approved candidate'
      USING ERRCODE = '22023';
  END IF;

  -- Open the election
  UPDATE elections
  SET 
    status = 'OPEN',
    start_datetime = COALESCE(start_datetime, now())
  WHERE election_id = p_election_id;

  -- Audit log
  INSERT INTO audit_logs (
    organization_id, 
    user_id, 
    action_type, 
    entity_name, 
    entity_id
  )
  VALUES (
    v_org_id,
    p_opened_by,
    'ELECTION_OPEN',
    'elections',
    p_election_id
  );
END;
$$;

-- 4) CLOSE ELECTION
CREATE OR REPLACE FUNCTION sp_close_election(
  p_election_id BIGINT,
  p_closed_by BIGINT
)
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
  v_org_id BIGINT;
  v_status election_status;
  v_can_close BOOLEAN;
BEGIN
  -- Get election details
  SELECT organization_id, status 
  INTO v_org_id, v_status
  FROM elections 
  WHERE election_id = p_election_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Election not found'
      USING ERRCODE = '22023';
  END IF;

  -- Check if user is OWNER/ADMIN
  v_can_close := is_org_admin(p_closed_by, v_org_id);
  
  IF NOT v_can_close THEN
    RAISE EXCEPTION 'Not authorized to close election'
      USING ERRCODE = '28000';
  END IF;

  -- Must be in OPEN status
  IF v_status != 'OPEN' THEN
    RAISE EXCEPTION 'Can only close elections in OPEN status'
      USING ERRCODE = '22023';
  END IF;

  -- Close the election
  UPDATE elections
  SET 
    status = 'CLOSED',
    end_datetime = COALESCE(end_datetime, now())
  WHERE election_id = p_election_id;

  -- Audit log
  INSERT INTO audit_logs (
    organization_id, 
    user_id, 
    action_type, 
    entity_name, 
    entity_id
  )
  VALUES (
    v_org_id,
    p_closed_by,
    'ELECTION_CLOSE',
    'elections',
    p_election_id
  );
END;
$$;

-- 5) GET ELECTIONS BY ORG
CREATE OR REPLACE FUNCTION sp_get_elections_by_org(p_organization_id BIGINT)
RETURNS TABLE (
  election_id BIGINT,
  election_name VARCHAR(200),
  description TEXT,
  start_datetime TIMESTAMPTZ,
  end_datetime TIMESTAMPTZ,
  status election_status,
  created_at TIMESTAMPTZ,
  created_by BIGINT
)
LANGUAGE sql
STABLE
AS $$
  SELECT 
    election_id,
    election_name,
    description,
    start_datetime,
    end_datetime,
    status,
    created_at,
    created_by
  FROM elections
  WHERE organization_id = p_organization_id
  ORDER BY created_at DESC;
$$;

COMMIT;
