CREATE TABLE race_results (
  race_id  BIGINT  NOT NULL,
  candidate_race_id  BIGINT  NOT NULL,
  total_votes  INTEGER  DEFAULT 0  NOT NULL,
  last_updated  TIMESTAMPTZ  DEFAULT now()  NOT NULL
);
