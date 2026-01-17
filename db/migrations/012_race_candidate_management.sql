BEGIN;

-- =====================================================
-- RACE AND CANDIDATE MANAGEMENT PROCEDURES
-- Allows organizers to manage races and candidates via API
-- =====================================================

-- 1) CREATE RACE
CREATE OR REPLACE FUNCTION sp_create_race(
  p_election_id BIGINT,
  p_race_name TEXT,
  p_description TEXT,
  p_max_votes_per_voter INT,
  p_created_by BIGINT
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

  -- Check if user is OWNER/ADMIN
  v_can_manage := is_org_admin(p_created_by, v_org_id);
  
  IF NOT v_can_manage THEN
    RAISE EXCEPTION 'Not authorized to manage races'
      USING ERRCODE = '28000';
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

  -- Insert race
  INSERT INTO election_races (
    election_id,
    race_name,
    description,
    max_votes_per_voter
  )
  VALUES (
    p_election_id,
    p_race_name,
    p_description,
    p_max_votes_per_voter
  )
  RETURNING race_id INTO v_race_id;

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
    p_created_by,
    'RACE_CREATE',
    'election_races',
    v_race_id,
    jsonb_build_object(
      'election_id', p_election_id,
      'race_name', p_race_name
    )
  );

  RETURN v_race_id;
END;
$$;

-- 2) UPDATE RACE
CREATE OR REPLACE FUNCTION sp_update_race(
  p_race_id BIGINT,
  p_race_name TEXT,
  p_description TEXT,
  p_max_votes_per_voter INT,
  p_updated_by BIGINT
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

  -- Check if user is OWNER/ADMIN
  v_can_manage := is_org_admin(p_updated_by, v_org_id);
  
  IF NOT v_can_manage THEN
    RAISE EXCEPTION 'Not authorized to update race'
      USING ERRCODE = '28000';
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

  -- Update race
  UPDATE election_races
  SET
    race_name = p_race_name,
    description = p_description,
    max_votes_per_voter = p_max_votes_per_voter
  WHERE race_id = p_race_id;

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
    'RACE_UPDATE',
    'election_races',
    p_race_id,
    jsonb_build_object('race_name', p_race_name)
  );
END;
$$;

-- 3) DELETE RACE
CREATE OR REPLACE FUNCTION sp_delete_race(
  p_race_id BIGINT,
  p_deleted_by BIGINT
)
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
  v_org_id BIGINT;
  v_election_status election_status;
  v_can_manage BOOLEAN;
BEGIN
  -- Get election details
  SELECT e.organization_id, e.status
  INTO v_org_id, v_election_status
  FROM election_races er
  JOIN elections e ON er.election_id = e.election_id
  WHERE er.race_id = p_race_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Race not found'
      USING ERRCODE = '22023';
  END IF;

  -- Check if user is OWNER/ADMIN
  v_can_manage := is_org_admin(p_deleted_by, v_org_id);
  
  IF NOT v_can_manage THEN
    RAISE EXCEPTION 'Not authorized to delete race'
      USING ERRCODE = '28000';
  END IF;

  -- Can only delete races in DRAFT elections
  IF v_election_status != 'DRAFT' THEN
    RAISE EXCEPTION 'Can only delete races in DRAFT elections'
      USING ERRCODE = '22023';
  END IF;

  -- Delete race (cascades to candidate_races and votes)
  DELETE FROM election_races WHERE race_id = p_race_id;

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
    p_deleted_by,
    'RACE_DELETE',
    'election_races',
    p_race_id
  );
END;
$$;

-- 4) ADD CANDIDATE TO RACE
CREATE OR REPLACE FUNCTION sp_add_candidate_to_race(
  p_race_id BIGINT,
  p_full_name TEXT,
  p_affiliation_name TEXT,
  p_bio TEXT,
  p_manifesto TEXT,
  p_ballot_order INT,
  p_added_by BIGINT
)
RETURNS BIGINT
LANGUAGE plpgsql
AS $$
DECLARE
  v_candidate_id BIGINT;
  v_candidate_race_id BIGINT;
  v_org_id BIGINT;
  v_election_id BIGINT;
  v_election_status election_status;
  v_can_manage BOOLEAN;
BEGIN
  -- Get election details via race
  SELECT e.organization_id, e.election_id, e.status
  INTO v_org_id, v_election_id, v_election_status
  FROM election_races er
  JOIN elections e ON er.election_id = e.election_id
  WHERE er.race_id = p_race_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Race not found'
      USING ERRCODE = '22023';
  END IF;

  -- Check if user is OWNER/ADMIN
  v_can_manage := is_org_admin(p_added_by, v_org_id);
  
  IF NOT v_can_manage THEN
    RAISE EXCEPTION 'Not authorized to add candidates'
      USING ERRCODE = '28000';
  END IF;

  -- Can only add candidates to DRAFT elections
  IF v_election_status != 'DRAFT' THEN
    RAISE EXCEPTION 'Can only add candidates to DRAFT elections'
      USING ERRCODE = '22023';
  END IF;

  -- Create candidate
  INSERT INTO candidates (
    full_name,
    affiliation_name,
    bio,
    manifesto,
    is_approved,
    organization_id
  )
  VALUES (
    p_full_name,
    p_affiliation_name,
    p_bio,
    p_manifesto,
    TRUE,  -- Auto-approve when added by admin
    v_org_id
  )
  RETURNING candidate_id INTO v_candidate_id;

  -- Link candidate to race
  INSERT INTO candidate_races (
    race_id,
    candidate_id,
    ballot_order,
    display_name
  )
  VALUES (
    p_race_id,
    v_candidate_id,
    p_ballot_order,
    p_full_name
  )
  RETURNING candidate_race_id INTO v_candidate_race_id;

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
    p_added_by,
    'CANDIDATE_ADD',
    'candidates',
    v_candidate_id,
    jsonb_build_object(
      'race_id', p_race_id,
      'full_name', p_full_name
    )
  );

  RETURN v_candidate_id;
END;
$$;

-- 5) UPDATE CANDIDATE
CREATE OR REPLACE FUNCTION sp_update_candidate(
  p_candidate_id BIGINT,
  p_full_name TEXT,
  p_affiliation_name TEXT,
  p_bio TEXT,
  p_manifesto TEXT,
  p_updated_by BIGINT
)
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
  v_org_id BIGINT;
  v_can_manage BOOLEAN;
BEGIN
  -- Get organization from candidate
  SELECT organization_id INTO v_org_id
  FROM candidates
  WHERE candidate_id = p_candidate_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Candidate not found'
      USING ERRCODE = '22023';
  END IF;

  -- Check if user is OWNER/ADMIN
  v_can_manage := is_org_admin(p_updated_by, v_org_id);
  
  IF NOT v_can_manage THEN
    RAISE EXCEPTION 'Not authorized to update candidate'
      USING ERRCODE = '28000';
  END IF;

  -- Update candidate
  UPDATE candidates
  SET
    full_name = p_full_name,
    affiliation_name = p_affiliation_name,
    bio = p_bio,
    manifesto = p_manifesto
  WHERE candidate_id = p_candidate_id;

  -- Update display name in candidate_races
  UPDATE candidate_races
  SET display_name = p_full_name
  WHERE candidate_id = p_candidate_id;

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
    'CANDIDATE_UPDATE',
    'candidates',
    p_candidate_id,
    jsonb_build_object('full_name', p_full_name)
  );
END;
$$;

-- 6) REMOVE CANDIDATE FROM RACE
CREATE OR REPLACE FUNCTION sp_remove_candidate_from_race(
  p_race_id BIGINT,
  p_candidate_id BIGINT,
  p_removed_by BIGINT
)
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
  v_org_id BIGINT;
  v_election_status election_status;
  v_can_manage BOOLEAN;
BEGIN
  -- Get election details
  SELECT e.organization_id, e.status
  INTO v_org_id, v_election_status
  FROM election_races er
  JOIN elections e ON er.election_id = e.election_id
  WHERE er.race_id = p_race_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Race not found'
      USING ERRCODE = '22023';
  END IF;

  -- Check if user is OWNER/ADMIN
  v_can_manage := is_org_admin(p_removed_by, v_org_id);
  
  IF NOT v_can_manage THEN
    RAISE EXCEPTION 'Not authorized to remove candidates'
      USING ERRCODE = '28000';
  END IF;

  -- Can only remove candidates from DRAFT elections
  IF v_election_status != 'DRAFT' THEN
    RAISE EXCEPTION 'Can only remove candidates from DRAFT elections'
      USING ERRCODE = '22023';
  END IF;

  -- Remove candidate from race
  DELETE FROM candidate_races
  WHERE race_id = p_race_id AND candidate_id = p_candidate_id;

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
    p_removed_by,
    'CANDIDATE_REMOVE',
    'candidate_races',
    p_candidate_id,
    jsonb_build_object('race_id', p_race_id)
  );
END;
$$;

-- 7) GET RACES FOR ELECTION
CREATE OR REPLACE FUNCTION sp_get_races_for_election(p_election_id BIGINT)
RETURNS TABLE (
  race_id BIGINT,
  race_name VARCHAR(200),
  description TEXT,
  max_votes_per_voter INT,
  candidate_count BIGINT
)
LANGUAGE sql
STABLE
AS $$
  SELECT 
    er.race_id,
    er.race_name,
    er.description,
    er.max_votes_per_voter,
    COUNT(cr.candidate_race_id) AS candidate_count
  FROM election_races er
  LEFT JOIN candidate_races cr ON er.race_id = cr.race_id
  WHERE er.election_id = p_election_id
  GROUP BY er.race_id, er.race_name, er.description, er.max_votes_per_voter
  ORDER BY er.race_id;
$$;

-- 8) GET CANDIDATES FOR RACE
CREATE OR REPLACE FUNCTION sp_get_candidates_for_race(p_race_id BIGINT)
RETURNS TABLE (
  candidate_id BIGINT,
  full_name VARCHAR(200),
  affiliation_name VARCHAR(200),
  bio TEXT,
  manifesto TEXT,
  is_approved BOOLEAN,
  ballot_order INT,
  display_name VARCHAR(200)
)
LANGUAGE sql
STABLE
AS $$
  SELECT 
    c.candidate_id,
    c.full_name,
    c.affiliation_name,
    c.bio,
    c.manifesto,
    c.is_approved,
    cr.ballot_order,
    cr.display_name
  FROM candidate_races cr
  JOIN candidates c ON cr.candidate_id = c.candidate_id
  WHERE cr.race_id = p_race_id
  ORDER BY cr.ballot_order NULLS LAST, c.full_name;
$$;

COMMIT;
