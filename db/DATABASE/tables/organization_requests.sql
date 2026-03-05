CREATE TABLE organization_requests (
  request_id  BIGINT  NOT NULL,
  requested_by  BIGINT  NOT NULL,
  organization_name  VARCHAR(200)  NOT NULL,
  organization_type  VARCHAR(50)  NOT NULL,
  organization_code  VARCHAR(50)  NOT NULL,
  purpose  TEXT,
  expected_members  INTEGER,
  proof_document_url  TEXT,
  status  org_request_status  DEFAULT 'PENDING'::org_request_status  NOT NULL,
  admin_notes  TEXT,
  reviewed_by  BIGINT,
  reviewed_at  TIMESTAMPTZ,
  created_at  TIMESTAMPTZ  DEFAULT now()  NOT NULL,
  updated_at  TIMESTAMPTZ  DEFAULT now()  NOT NULL
);
