CREATE TABLE organizations (
  organization_id  BIGINT  NOT NULL,
  organization_name  VARCHAR(200)  NOT NULL,
  organization_type  VARCHAR(50)  NOT NULL,
  organization_code  VARCHAR(50)  NOT NULL,
  created_at  TIMESTAMPTZ  DEFAULT now()  NOT NULL,
  status  VARCHAR(20)  DEFAULT 'ACTIVE'::character varying
);
