BEGIN;

-- =====================================================
-- UPDATE RACE MANAGEMENT PROCEDURES TO SUPPORT MAX_WINNERS
-- Add max_winners parameter to sp_create_race and sp_update_race
-- =====================================================

-- 1) UPDATE sp_create_race to include max_winners
CREATE OR REPLACE FUNCTION sp_create_race(
  p_election_id BIGINT,
  p_race_name TEXT,
  p_description TEXT,
  p_max_votes_per_voter INT,
  p_max_winners INT DEFAULT 1,
  p_created_by BIGINT DEFAULT NULL
)
RETURNS BIGINT
LANGUAGE plpgsql
AS $$
DECLARE
  v_race_id BIGINT;
  v_org_id BIGINT;
  v_election_status election_status;
  v_can_manage BOOLEAN;
BEGIN
  -- Get election details
  SELECT organization_id, status
  INTO v_org_id, v_election_status
  FROM elections
  WHERE election_id = p_election_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Election not found'
      USING ERRCODE = '22023';
  END IF;

  -- Check if user is OWNER/ADMIN (if p_created_by is provided)
  IF p_created_by IS NOT NULL THEN
    v_can_manage := is_org_admin(p_created_by, v_org_id);
    
    IF NOT v_can_manage THEN
      RAISE EXCEPTION 'Not authorized to manage races'
        USING ERRCODE = '28000';
    END IF;
  END IF;

  -- Can only add races to DRAFT elections
  IF v_election_status != 'DRAFT' THEN
    RAISE EXCEPTION 'Can only add races to DRAFT elections'
      USING ERRCODE = '22023';
  END IF;

  -- Validate max_votes_per_voter
  IF p_max_votes_per_voter < 1 THEN
    RAISE EXCEPTION 'max_votes_per_voter must be at least 1'
      USING ERRCODE = '22023';
  END IF;

  -- Validate max_winners
  IF p_max_winners < 1 THEN
    RAISE EXCEPTION 'max_winners must be at least 1'
      USING ERRCODE = '22023';
  END IF;

  -- Insert race
  INSERT INTO election_races (
    election_id,
    race_name,
    description,
    max_votes_per_voter,
    max_winners
  )
  VALUES (
    p_election_id,
    p_race_name,
    p_description,
    p_max_votes_per_voter,
    p_max_winners
  )
  RETURNING race_id INTO v_race_id;

  -- Audit log (if user provided)
  IF p_created_by IS NOT NULL THEN
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
      p_created_by,
      'RACE_CREATE',
      'election_races',
      v_race_id,
      jsonb_build_object(
        'election_id', p_election_id,
        'race_name', p_race_name,
        'max_winners', p_max_winners
      )
    );
  END IF;

  RETURN v_race_id;
END;
$$;

-- 2) UPDATE sp_update_race to include max_winners
CREATE OR REPLACE FUNCTION sp_update_race(
  p_race_id BIGINT,
  p_race_name TEXT,
  p_description TEXT,
  p_max_votes_per_voter INT,
  p_max_winners INT DEFAULT 1,
  p_updated_by BIGINT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
  v_org_id BIGINT;
  v_election_status election_status;
  v_can_manage BOOLEAN;
BEGIN
  -- Get election details via race
  SELECT e.organization_id, e.status
  INTO v_org_id, v_election_status
  FROM election_races er
  JOIN elections e ON er.election_id = e.election_id
  WHERE er.race_id = p_race_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Race not found'
      USING ERRCODE = '22023';
  END IF;

  -- Check if user is OWNER/ADMIN (if p_updated_by is provided)
  IF p_updated_by IS NOT NULL THEN
    v_can_manage := is_org_admin(p_updated_by, v_org_id);
    
    IF NOT v_can_manage THEN
      RAISE EXCEPTION 'Not authorized to update race'
        USING ERRCODE = '28000';
    END IF;
  END IF;

  -- Can only update races in DRAFT elections
  IF v_election_status != 'DRAFT' THEN
    RAISE EXCEPTION 'Can only update races in DRAFT elections'
      USING ERRCODE = '22023';
  END IF;

  -- Validate max_votes_per_voter
  IF p_max_votes_per_voter < 1 THEN
    RAISE EXCEPTION 'max_votes_per_voter must be at least 1'
      USING ERRCODE = '22023';
  END IF;

  -- Validate max_winners
  IF p_max_winners < 1 THEN
    RAISE EXCEPTION 'max_winners must be at least 1'
      USING ERRCODE = '22023';
  END IF;

  -- Update race
  UPDATE election_races
  SET
    race_name = p_race_name,
    description = p_description,
    max_votes_per_voter = p_max_votes_per_voter,
    max_winners = p_max_winners
  WHERE race_id = p_race_id;

  -- Audit log (if user provided)
  IF p_updated_by IS NOT NULL THEN
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
      'RACE_UPDATE',
      'election_races',
      p_race_id,
      jsonb_build_object(
        'race_name', p_race_name,
        'max_winners', p_max_winners
      )
    );
  END IF;
END;
$$;

COMMIT;
