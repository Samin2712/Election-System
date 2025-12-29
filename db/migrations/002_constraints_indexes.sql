BEGIN;

-- Helpful indexes for FK joins / common lookups
CREATE INDEX IF NOT EXISTS idx_voters_org          ON voters(organization_id);
CREATE INDEX IF NOT EXISTS idx_voters_user         ON voters(user_id);

CREATE INDEX IF NOT EXISTS idx_elections_org       ON elections(organization_id);
CREATE INDEX IF NOT EXISTS idx_races_election      ON election_races(election_id);

CREATE INDEX IF NOT EXISTS idx_candidate_races_race   ON candidate_races(race_id);
CREATE INDEX IF NOT EXISTS idx_votes_voter            ON votes(voter_id);
CREATE INDEX IF NOT EXISTS idx_votes_race             ON votes(race_id);
CREATE INDEX IF NOT EXISTS idx_votes_candidate_race   ON votes(candidate_race_id);

CREATE INDEX IF NOT EXISTS idx_audit_org_time      ON audit_logs(organization_id, action_timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_audit_entity        ON audit_logs(entity_name, entity_id);

-- Sanity: disallow invalid_reason if is_valid = true (optional but nice)
ALTER TABLE votes
  DROP CONSTRAINT IF EXISTS chk_invalid_reason_consistency;

ALTER TABLE votes
  ADD CONSTRAINT chk_invalid_reason_consistency
  CHECK (
    (is_valid = TRUE  AND invalid_reason IS NULL)
    OR
    (is_valid = FALSE AND invalid_reason IS NOT NULL)
  );

COMMIT;
