-- Migration 018: Add SCHEDULED status and auto-opening functionality
BEGIN;

-- 1. Add SCHEDULED to election_status enum
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_enum 
        WHERE enumlabel = 'SCHEDULED' 
        AND enumtypid = (SELECT oid FROM pg_type WHERE typname = 'election_status')
    ) THEN
        ALTER TYPE election_status ADD VALUE 'SCHEDULED' AFTER 'DRAFT';
    END IF;
END $$;

-- 2. Update sp_update_election to allow updates in SCHEDULED status
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

  -- Can update DRAFT or SCHEDULED elections (not OPEN or CLOSED)
  IF v_status NOT IN ('DRAFT', 'SCHEDULED') THEN
    RAISE EXCEPTION 'Can only update elections in DRAFT or SCHEDULED status'
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

-- 3. Create sp_schedule_election to set election to SCHEDULED status
CREATE OR REPLACE FUNCTION sp_schedule_election(
  p_election_id BIGINT,
  p_start_datetime TIMESTAMPTZ,
  p_end_datetime TIMESTAMPTZ,
  p_scheduled_by BIGINT
)
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
  v_org_id BIGINT;
  v_status election_status;
  v_race_count INT;
  v_candidate_count INT;
  v_can_schedule BOOLEAN;
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
  v_can_schedule := is_org_admin(p_scheduled_by, v_org_id);
  
  IF NOT v_can_schedule THEN
    RAISE EXCEPTION 'Not authorized to schedule election'
      USING ERRCODE = '28000';
  END IF;

  -- Must be in DRAFT status
  IF v_status != 'DRAFT' THEN
    RAISE EXCEPTION 'Can only schedule elections in DRAFT status'
      USING ERRCODE = '22023';
  END IF;

  -- Validate dates
  IF p_end_datetime <= p_start_datetime THEN
    RAISE EXCEPTION 'End time must be after start time'
      USING ERRCODE = '22023';
  END IF;

  -- Start time must be in the future
  IF p_start_datetime <= NOW() THEN
    RAISE EXCEPTION 'Start time must be in the future'
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

  -- Schedule the election
  UPDATE elections
  SET 
    status = 'SCHEDULED',
    start_datetime = p_start_datetime,
    end_datetime = p_end_datetime
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
    p_scheduled_by,
    'ELECTION_SCHEDULED',
    'elections',
    p_election_id,
    jsonb_build_object(
      'start_datetime', p_start_datetime,
      'end_datetime', p_end_datetime
    )
  );
END;
$$;

-- 4. Update sp_open_election to allow opening SCHEDULED elections
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

  -- Must be in DRAFT or SCHEDULED status
  IF v_status NOT IN ('DRAFT', 'SCHEDULED') THEN
    RAISE EXCEPTION 'Can only open elections in DRAFT or SCHEDULED status'
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

-- 5. Create function to automatically open/close scheduled elections (called by cron)
CREATE OR REPLACE FUNCTION sp_process_scheduled_elections()
RETURNS TABLE (
  action TEXT,
  election_id BIGINT,
  election_name VARCHAR(200)
)
LANGUAGE plpgsql
AS $$
BEGIN
  -- Open elections that should start
  UPDATE elections e
  SET status = 'OPEN'
  WHERE status = 'SCHEDULED'
    AND start_datetime <= NOW()
    AND start_datetime IS NOT NULL
  RETURNING 'OPENED' as action, e.election_id, e.election_name
  INTO action, election_id, election_name;

  IF FOUND THEN
    RETURN NEXT;
  END IF;

  -- Close elections that should end
  UPDATE elections e
  SET status = 'CLOSED'
  WHERE status = 'OPEN'
    AND end_datetime <= NOW()
    AND end_datetime IS NOT NULL
  RETURNING 'CLOSED' as action, e.election_id, e.election_name
  INTO action, election_id, election_name;

  IF FOUND THEN
    RETURN NEXT;
  END IF;

  RETURN;
END;
$$;

COMMIT;
