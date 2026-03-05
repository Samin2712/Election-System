CREATE TABLE elections (
  election_id  BIGINT  NOT NULL,
  organization_id  BIGINT  NOT NULL,
  election_name  VARCHAR(200)  NOT NULL,
  description  TEXT,
  start_datetime  TIMESTAMPTZ,
  end_datetime  TIMESTAMPTZ,
  status  election_status  DEFAULT 'DRAFT'::election_status  NOT NULL,
  created_at  TIMESTAMPTZ  DEFAULT now()  NOT NULL,
  created_by  BIGINT
);
