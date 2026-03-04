BEGIN;

-- =====================================================
-- UPDATE sp_get_races_for_election TO INCLUDE MAX_WINNERS
-- Drop and recreate function to add max_winners column
-- =====================================================

DROP FUNCTION IF EXISTS sp_get_races_for_election(BIGINT);

CREATE OR REPLACE FUNCTION sp_get_races_for_election(p_election_id BIGINT)
RETURNS TABLE (
  race_id BIGINT,
  race_name VARCHAR(200),
  description TEXT,
  max_votes_per_voter INT,
  max_winners INT,
  candidate_count BIGINT
)
LANGUAGE sql
STABLE
AS $$
  SELECT 
    er.race_id,
    er.race_name,
    er.description,
    er.max_votes_per_voter,
    er.max_winners,
    COUNT(cr.candidate_race_id) AS candidate_count
  FROM election_races er
  LEFT JOIN candidate_races cr ON er.race_id = cr.race_id
  WHERE er.election_id = p_election_id
  GROUP BY er.race_id, er.race_name, er.description, er.max_votes_per_voter, er.max_winners
  ORDER BY er.race_id;
$$;

COMMIT;
