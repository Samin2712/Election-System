CREATE TABLE schema_migrations (
  filename  TEXT  NOT NULL,
  applied_at  TIMESTAMPTZ  DEFAULT now()  NOT NULL
);
