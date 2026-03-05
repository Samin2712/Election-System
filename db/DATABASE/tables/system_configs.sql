CREATE TABLE system_configs (
  config_id  BIGINT  NOT NULL,
  organization_id  BIGINT,
  config_key  VARCHAR(100)  NOT NULL,
  config_json  jsonb  NOT NULL,
  updated_at  TIMESTAMPTZ  DEFAULT now()  NOT NULL
);
