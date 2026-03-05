CREATE TABLE election_races (
  race_id  BIGINT  NOT NULL,
  election_id  BIGINT  NOT NULL,
  race_name  VARCHAR(200)  NOT NULL,
  description  TEXT,
  max_votes_per_voter  INTEGER  DEFAULT 1  NOT NULL,
  max_winners  INTEGER  DEFAULT 1  NOT NULL
);
