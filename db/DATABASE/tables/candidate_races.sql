CREATE TABLE candidate_races (
  candidate_race_id  BIGINT  NOT NULL,
  race_id  BIGINT  NOT NULL,
  candidate_id  BIGINT  NOT NULL,
  ballot_order  INTEGER,
  display_name  VARCHAR(200),
  affiliation_snapshot  VARCHAR(200)
);
