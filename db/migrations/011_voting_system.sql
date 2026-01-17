BEGIN;

-- =====================================================
-- PHASE 5: VOTERS + VOTING + RESULTS
-- Extends existing voters and votes tables
-- Adds stored procedures for voter registration and voting
-- =====================================================

-- 1) Ensure voters table has approval columns
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'voters' AND column_name = 'is_approved'
  ) THEN
    ALTER TABLE voters ADD COLUMN is_approved BOOLEAN NOT NULL DEFAULT FALSE;
  END IF;
END $$;

DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'voters' AND column_name = 'approved_by'
  ) THEN
    ALTER TABLE voters ADD COLUMN approved_by BIGINT REFERENCES user_accounts(user_id);
  END IF;
END $$;

DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'voters' AND column_name = 'approved_at'
  ) THEN
    ALTER TABLE voters ADD COLUMN approved_at TIMESTAMPTZ;
  END IF;
END $$;

-- 2) Update voters status to approved for existing voters (migration safety)
UPDATE voters 
SET is_approved = TRUE, 
    approved_at = registered_at
WHERE status = 'APPROVED' AND is_approved = FALSE;

-- =====================================================
-- STORED PROCEDURES FOR VOTER MANAGEMENT
-- =====================================================

-- 1) REGISTER VOTER
CREATE OR REPLACE FUNCTION sp_register_voter(
  p_organization_id BIGINT,
  p_user_id BIGINT
)
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
  v_member_id VARCHAR(80);
  v_member_type VARCHAR(50);
  v_voter_id BIGINT;
BEGIN
  -- Check if user is an active member in org_members
  IF NOT EXISTS (
    SELECT 1 FROM org_members
    WHERE organization_id = p_organization_id
      AND user_id = p_user_id
      AND is_active = TRUE
  ) THEN
    RAISE EXCEPTION 'User must be an active member of the organization'
      USING ERRCODE = '22023';
  END IF;

  -- Try to find matching member in org_member_master
  -- (This is optional - if no match, we'll use default values)
  SELECT member_id, member_type 
  INTO v_member_id, v_member_type
  FROM org_member_master
  WHERE organization_id = p_organization_id
    AND is_active = TRUE
  LIMIT 1;

  -- If no member found, use user_id as member_id
  IF v_member_id IS NULL THEN
    v_member_id := p_user_id::VARCHAR;
    v_member_type := 'USER';
  END IF;

  -- Insert voter (pending approval)
  INSERT INTO voters (
    user_id,
    organization_id,
    member_id,
    voter_type,
    status,
    is_approved
  )
  VALUES (
    p_user_id,
    p_organization_id,
    v_member_id,
    v_member_type,
    'PENDING',
    FALSE
  )
  ON CONFLICT (organization_id, user_id) 
  DO NOTHING;

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
    p_user_id,
    'VOTER_REGISTER',
    'voters',
    p_user_id,
    jsonb_build_object('member_id', v_member_id)
  );
END;
$$;

-- 2) APPROVE VOTER
CREATE OR REPLACE FUNCTION sp_approve_voter(
  p_organization_id BIGINT,
  p_user_id BIGINT,
  p_approved_by BIGINT
)
RETURNS VOID
LANGUAGE plpgsql
AS $$
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
$$;

-- 3) CAST VOTE (Updated version with proper validation)
CREATE OR REPLACE FUNCTION sp_cast_vote(
  p_election_id BIGINT,
  p_race_id BIGINT,
  p_candidate_id BIGINT,
  p_voter_user_id BIGINT
)
RETURNS BIGINT
LANGUAGE plpgsql
AS $$
DECLARE
  v_vote_id BIGINT;
  v_voter_id BIGINT;
  v_org_id BIGINT;
  v_election_status election_status;
  v_candidate_race_id BIGINT;
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

  -- Election must be OPEN
  IF v_election_status != 'OPEN' THEN
    RAISE EXCEPTION 'Election is not open for voting'
      USING ERRCODE = '22023';
  END IF;

  -- Verify race belongs to election
  IF NOT EXISTS (
    SELECT 1 FROM election_races
    WHERE race_id = p_race_id
      AND election_id = p_election_id
  ) THEN
    RAISE EXCEPTION 'Race does not belong to this election'
      USING ERRCODE = '22023';
  END IF;

  -- Get voter_id and check if approved
  SELECT voter_id INTO v_voter_id
  FROM voters
  WHERE user_id = p_voter_user_id
    AND organization_id = v_org_id
    AND is_approved = TRUE
    AND status = 'APPROVED';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Voter not approved for this organization'
      USING ERRCODE = '28000';
  END IF;

  -- Get candidate_race_id and verify candidate is approved
  SELECT cr.candidate_race_id INTO v_candidate_race_id
  FROM candidate_races cr
  JOIN candidates c ON cr.candidate_id = c.candidate_id
  WHERE cr.race_id = p_race_id
    AND cr.candidate_id = p_candidate_id
    AND c.is_approved = TRUE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Candidate not found or not approved for this race'
      USING ERRCODE = '22023';
  END IF;

  -- Check if already voted (will fail on unique constraint if duplicate)
  IF EXISTS (
    SELECT 1 FROM votes
    WHERE voter_id = v_voter_id
      AND race_id = p_race_id
  ) THEN
    RAISE EXCEPTION 'Already voted in this race'
      USING ERRCODE = '23505';
  END IF;

  -- Cast vote
  INSERT INTO votes (
    voter_id,
    race_id,
    candidate_race_id,
    cast_channel
  )
  VALUES (
    v_voter_id,
    p_race_id,
    v_candidate_race_id,
    'WEB'
  )
  RETURNING vote_id INTO v_vote_id;

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
    p_voter_user_id,
    'VOTE_CAST',
    'votes',
    v_vote_id,
    jsonb_build_object(
      'election_id', p_election_id,
      'race_id', p_race_id,
      'candidate_id', p_candidate_id
    )
  );

  RETURN v_vote_id;
END;
$$;

-- 4) GET RACE RESULTS
CREATE OR REPLACE FUNCTION sp_get_race_results(
  p_election_id BIGINT,
  p_race_id BIGINT
)
RETURNS TABLE (
  candidate_id BIGINT,
  display_name VARCHAR(200),
  vote_count BIGINT
)
LANGUAGE sql
STABLE
AS $$
  SELECT 
    c.candidate_id,
    COALESCE(cr.display_name, c.full_name) AS display_name,
    COUNT(v.vote_id) AS vote_count
  FROM candidate_races cr
  JOIN candidates c ON cr.candidate_id = c.candidate_id
  LEFT JOIN votes v ON v.candidate_race_id = cr.candidate_race_id
  WHERE cr.race_id = p_race_id
  GROUP BY c.candidate_id, cr.display_name, c.full_name
  ORDER BY vote_count DESC, display_name ASC;
$$;

-- 5) GET VOTER STATUS
CREATE OR REPLACE FUNCTION sp_get_voter_status(
  p_organization_id BIGINT,
  p_user_id BIGINT
)
RETURNS TABLE (
  voter_id BIGINT,
  is_approved BOOLEAN,
  status voter_status,
  approved_by BIGINT,
  approved_at TIMESTAMPTZ,
  registered_at TIMESTAMPTZ
)
LANGUAGE sql
STABLE
AS $$
  SELECT 
    voter_id,
    is_approved,
    status,
    approved_by,
    approved_at,
    registered_at
  FROM voters
  WHERE organization_id = p_organization_id
    AND user_id = p_user_id;
$$;

-- 6) LIST PENDING VOTERS (for admins)
CREATE OR REPLACE FUNCTION sp_list_pending_voters(p_organization_id BIGINT)
RETURNS TABLE (
  voter_id BIGINT,
  user_id BIGINT,
  member_id VARCHAR(80),
  voter_type VARCHAR(50),
  registered_at TIMESTAMPTZ
)
LANGUAGE sql
STABLE
AS $$
  SELECT 
    voter_id,
    user_id,
    member_id,
    voter_type,
    registered_at
  FROM voters
  WHERE organization_id = p_organization_id
    AND is_approved = FALSE
    AND status = 'PENDING'
  ORDER BY registered_at ASC;
$$;

COMMIT;
