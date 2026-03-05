CREATE TABLE org_members (
  organization_id  BIGINT  NOT NULL,
  user_id  BIGINT  NOT NULL,
  role_name  TEXT  NOT NULL,
  is_active  BOOLEAN  DEFAULT true  NOT NULL,
  created_at  TIMESTAMPTZ  DEFAULT now()  NOT NULL
);
