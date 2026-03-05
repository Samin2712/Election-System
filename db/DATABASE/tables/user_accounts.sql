CREATE TABLE user_accounts (
  user_id  BIGINT  NOT NULL,
  username  VARCHAR(50)  NOT NULL,
  email  citext  NOT NULL,
  password_hash  TEXT  NOT NULL,
  role_id  BIGINT  NOT NULL,
  is_active  BOOLEAN  DEFAULT true  NOT NULL,
  created_at  TIMESTAMPTZ  DEFAULT now()  NOT NULL,
  is_system_admin  BOOLEAN  DEFAULT false
);
