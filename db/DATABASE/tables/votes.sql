CREATE TABLE votes (
  vote_id  BIGINT  NOT NULL,
  voter_id  BIGINT  NOT NULL,
  race_id  BIGINT  NOT NULL,
  candidate_race_id  BIGINT  NOT NULL,
  cast_at  TIMESTAMPTZ  DEFAULT now()  NOT NULL,
  cast_channel  vote_channel  DEFAULT 'WEB'::vote_channel  NOT NULL,
  is_valid  BOOLEAN  DEFAULT true  NOT NULL,
  invalid_reason  VARCHAR(255)
);
