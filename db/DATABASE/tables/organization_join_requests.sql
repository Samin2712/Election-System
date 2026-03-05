CREATE TABLE organization_join_requests (
  request_id  INTEGER  DEFAULT nextval('organization_join_requests_request_id_seq'::regclass)  NOT NULL,
  organization_id  BIGINT  NOT NULL,
  user_id  BIGINT  NOT NULL,
  request_message  TEXT,
  status  VARCHAR(20)  DEFAULT 'PENDING'::character varying  NOT NULL,
  approval_token  VARCHAR(64),
  approved_by  BIGINT,
  created_at  TIMESTAMP  DEFAULT now(),
  updated_at  TIMESTAMP  DEFAULT now()
);
