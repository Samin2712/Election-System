CREATE TABLE invitation_batches (
  batch_id  INTEGER  DEFAULT nextval('invitation_batches_batch_id_seq'::regclass)  NOT NULL,
  organization_id  INTEGER  NOT NULL,
  created_by  INTEGER  NOT NULL,
  total_emails  INTEGER  DEFAULT 0  NOT NULL,
  successful_emails  INTEGER  DEFAULT 0  NOT NULL,
  failed_emails  INTEGER  DEFAULT 0  NOT NULL,
  status  VARCHAR(20)  DEFAULT 'PROCESSING'::character varying  NOT NULL,
  created_at  TIMESTAMPTZ  DEFAULT CURRENT_TIMESTAMP,
  completed_at  TIMESTAMPTZ
);
