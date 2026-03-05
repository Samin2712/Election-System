CREATE TABLE organization_invites (
  invite_id  INTEGER  DEFAULT nextval('organization_invites_invite_id_seq'::regclass)  NOT NULL,
  organization_id  BIGINT  NOT NULL,
  email  VARCHAR(255)  NOT NULL,
  token  VARCHAR(64)  NOT NULL,
  role_name  VARCHAR(50)  DEFAULT 'MEMBER'::character varying  NOT NULL,
  status  VARCHAR(20)  DEFAULT 'PENDING'::character varying  NOT NULL,
  created_by  BIGINT,
  created_at  TIMESTAMPTZ  DEFAULT CURRENT_TIMESTAMP,
  expires_at  TIMESTAMPTZ  NOT NULL,
  batch_id  INTEGER,
  invited_at  TIMESTAMPTZ  DEFAULT CURRENT_TIMESTAMP,
  email_sent  BOOLEAN  DEFAULT false,
  email_sent_at  TIMESTAMPTZ
);
