CREATE TABLE audit_logs (
  audit_id  BIGINT  NOT NULL,
  organization_id  BIGINT,
  user_id  BIGINT,
  action_type  VARCHAR(50)  NOT NULL,
  entity_name  VARCHAR(50)  NOT NULL,
  entity_id  BIGINT,
  action_timestamp  TIMESTAMPTZ  DEFAULT now()  NOT NULL,
  details_json  jsonb
);
