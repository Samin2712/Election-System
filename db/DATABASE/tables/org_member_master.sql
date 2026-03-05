CREATE TABLE org_member_master (
  organization_id  BIGINT  NOT NULL,
  member_id  VARCHAR(80)  NOT NULL,
  member_type  VARCHAR(50)  NOT NULL,
  full_name  VARCHAR(200)  NOT NULL,
  date_of_birth  DATE,
  email  citext,
  extra_info_json  jsonb,
  is_active  BOOLEAN  DEFAULT true  NOT NULL
);
