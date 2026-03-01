BEGIN;

-- ============================================================
-- Organization Creation Request System
-- Users submit requests with proof documents.
-- Super admin reviews and approves/rejects.
-- ============================================================

-- 1) Enum for request status
DO $$ BEGIN
  CREATE TYPE org_request_status AS ENUM ('PENDING', 'APPROVED', 'REJECTED');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- 2) Organization creation requests table
CREATE TABLE IF NOT EXISTS organization_requests (
  request_id        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  requested_by      BIGINT        NOT NULL REFERENCES user_accounts(user_id) ON DELETE CASCADE,
  organization_name VARCHAR(200)  NOT NULL,
  organization_type VARCHAR(50)   NOT NULL,
  organization_code VARCHAR(50)   NOT NULL,
  purpose           TEXT,                          -- Why they need this org
  expected_members  INT,                           -- Expected member count
  proof_document_url TEXT,                         -- Uploaded proof image (transcript, visiting card, etc.)
  status            org_request_status NOT NULL DEFAULT 'PENDING',
  admin_notes       TEXT,                          -- Super admin's approval/rejection reason
  reviewed_by       BIGINT        REFERENCES user_accounts(user_id),
  reviewed_at       TIMESTAMPTZ,
  created_at        TIMESTAMPTZ   NOT NULL DEFAULT now(),
  updated_at        TIMESTAMPTZ   NOT NULL DEFAULT now()
);

-- Index for quick lookups
CREATE INDEX IF NOT EXISTS idx_org_requests_status ON organization_requests(status);
CREATE INDEX IF NOT EXISTS idx_org_requests_requested_by ON organization_requests(requested_by);

-- ============================================================
-- Stored Procedures using CURSOR where appropriate
-- ============================================================

-- 3) Submit organization request
CREATE OR REPLACE FUNCTION sp_submit_org_request(
  p_user_id          BIGINT,
  p_org_name         TEXT,
  p_org_type         TEXT,
  p_org_code         TEXT,
  p_purpose          TEXT DEFAULT NULL,
  p_expected_members INT DEFAULT NULL,
  p_proof_url        TEXT DEFAULT NULL
)
RETURNS BIGINT
LANGUAGE plpgsql
AS $$
DECLARE
  v_request_id BIGINT;
  v_existing_code BIGINT;
  v_pending_count INT;
BEGIN
  -- Check if org code already exists in organizations
  SELECT organization_id INTO v_existing_code
  FROM organizations
  WHERE organization_code = p_org_code;

  IF FOUND THEN
    RAISE EXCEPTION 'Organization code already exists'
      USING ERRCODE = '23505';
  END IF;

  -- Check if user already has a pending request for this code
  SELECT COUNT(*) INTO v_pending_count
  FROM organization_requests
  WHERE requested_by = p_user_id
    AND organization_code = p_org_code
    AND status = 'PENDING';

  IF v_pending_count > 0 THEN
    RAISE EXCEPTION 'You already have a pending request for this organization code'
      USING ERRCODE = '23505';
  END IF;

  INSERT INTO organization_requests (
    requested_by,
    organization_name,
    organization_type,
    organization_code,
    purpose,
    expected_members,
    proof_document_url
  )
  VALUES (
    p_user_id,
    p_org_name,
    p_org_type,
    p_org_code,
    p_purpose,
    p_expected_members,
    p_proof_url
  )
  RETURNING request_id INTO v_request_id;

  RETURN v_request_id;
END;
$$;

-- 4) Get all pending requests (for super admin) - uses CURSOR
CREATE OR REPLACE FUNCTION sp_get_org_requests(
  p_status org_request_status DEFAULT NULL
)
RETURNS TABLE(
  request_id        BIGINT,
  requested_by      BIGINT,
  requester_username VARCHAR,
  requester_email   CITEXT,
  organization_name VARCHAR,
  organization_type VARCHAR,
  organization_code VARCHAR,
  purpose           TEXT,
  expected_members  INT,
  proof_document_url TEXT,
  status            org_request_status,
  admin_notes       TEXT,
  reviewed_at       TIMESTAMPTZ,
  created_at        TIMESTAMPTZ
)
LANGUAGE plpgsql
AS $$
DECLARE
  req_cursor CURSOR FOR
    SELECT
      r.request_id,
      r.requested_by,
      u.username AS requester_username,
      u.email AS requester_email,
      r.organization_name,
      r.organization_type,
      r.organization_code,
      r.purpose,
      r.expected_members,
      r.proof_document_url,
      r.status,
      r.admin_notes,
      r.reviewed_at,
      r.created_at
    FROM organization_requests r
    JOIN user_accounts u ON r.requested_by = u.user_id
    WHERE (p_status IS NULL OR r.status = p_status)
    ORDER BY
      CASE r.status
        WHEN 'PENDING' THEN 0
        WHEN 'APPROVED' THEN 1
        WHEN 'REJECTED' THEN 2
      END,
      r.created_at DESC;
  rec RECORD;
BEGIN
  OPEN req_cursor;
  LOOP
    FETCH req_cursor INTO rec;
    EXIT WHEN NOT FOUND;

    request_id        := rec.request_id;
    requested_by      := rec.requested_by;
    requester_username := rec.requester_username;
    requester_email   := rec.requester_email;
    organization_name := rec.organization_name;
    organization_type := rec.organization_type;
    organization_code := rec.organization_code;
    purpose           := rec.purpose;
    expected_members  := rec.expected_members;
    proof_document_url := rec.proof_document_url;
    status            := rec.status;
    admin_notes       := rec.admin_notes;
    reviewed_at       := rec.reviewed_at;
    created_at        := rec.created_at;

    RETURN NEXT;
  END LOOP;
  CLOSE req_cursor;
END;
$$;

-- 5) Approve organization request
--    Creates the org + makes requester the OWNER
CREATE OR REPLACE FUNCTION sp_approve_org_request(
  p_request_id   BIGINT,
  p_admin_user_id BIGINT,
  p_admin_notes  TEXT DEFAULT NULL
)
RETURNS BIGINT
LANGUAGE plpgsql
AS $$
DECLARE
  v_req RECORD;
  v_org_id BIGINT;
BEGIN
  -- Get and lock the request
  SELECT * INTO v_req
  FROM organization_requests
  WHERE request_id = p_request_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Request not found'
      USING ERRCODE = '22023';
  END IF;

  IF v_req.status != 'PENDING' THEN
    RAISE EXCEPTION 'Request has already been %', v_req.status
      USING ERRCODE = '22023';
  END IF;

  -- Create the organization using existing sp
  v_org_id := sp_create_organization(
    v_req.organization_name,
    v_req.organization_type,
    v_req.organization_code,
    v_req.requested_by
  );

  -- Mark request as approved
  UPDATE organization_requests
  SET
    status = 'APPROVED',
    admin_notes = p_admin_notes,
    reviewed_by = p_admin_user_id,
    reviewed_at = now(),
    updated_at = now()
  WHERE request_id = p_request_id;

  RETURN v_org_id;
END;
$$;

-- 6) Reject organization request
CREATE OR REPLACE FUNCTION sp_reject_org_request(
  p_request_id   BIGINT,
  p_admin_user_id BIGINT,
  p_admin_notes  TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
  v_status org_request_status;
BEGIN
  SELECT status INTO v_status
  FROM organization_requests
  WHERE request_id = p_request_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Request not found'
      USING ERRCODE = '22023';
  END IF;

  IF v_status != 'PENDING' THEN
    RAISE EXCEPTION 'Request has already been %', v_status
      USING ERRCODE = '22023';
  END IF;

  UPDATE organization_requests
  SET
    status = 'REJECTED',
    admin_notes = p_admin_notes,
    reviewed_by = p_admin_user_id,
    reviewed_at = now(),
    updated_at = now()
  WHERE request_id = p_request_id;
END;
$$;

-- 7) Get user's own requests
CREATE OR REPLACE FUNCTION sp_get_my_org_requests(
  p_user_id BIGINT
)
RETURNS TABLE(
  request_id        BIGINT,
  organization_name VARCHAR,
  organization_type VARCHAR,
  organization_code VARCHAR,
  purpose           TEXT,
  expected_members  INT,
  proof_document_url TEXT,
  status            org_request_status,
  admin_notes       TEXT,
  reviewed_at       TIMESTAMPTZ,
  created_at        TIMESTAMPTZ
)
LANGUAGE plpgsql
AS $$
DECLARE
  my_cursor CURSOR FOR
    SELECT
      r.request_id,
      r.organization_name,
      r.organization_type,
      r.organization_code,
      r.purpose,
      r.expected_members,
      r.proof_document_url,
      r.status,
      r.admin_notes,
      r.reviewed_at,
      r.created_at
    FROM organization_requests r
    WHERE r.requested_by = p_user_id
    ORDER BY r.created_at DESC;
  rec RECORD;
BEGIN
  OPEN my_cursor;
  LOOP
    FETCH my_cursor INTO rec;
    EXIT WHEN NOT FOUND;

    request_id        := rec.request_id;
    organization_name := rec.organization_name;
    organization_type := rec.organization_type;
    organization_code := rec.organization_code;
    purpose           := rec.purpose;
    expected_members  := rec.expected_members;
    proof_document_url := rec.proof_document_url;
    status            := rec.status;
    admin_notes       := rec.admin_notes;
    reviewed_at       := rec.reviewed_at;
    created_at        := rec.created_at;

    RETURN NEXT;
  END LOOP;
  CLOSE my_cursor;
END;
$$;

COMMIT;
