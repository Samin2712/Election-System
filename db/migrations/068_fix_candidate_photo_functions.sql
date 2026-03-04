BEGIN;

-- ============================================================
-- Fix 1: Drop OLD overloads of sp_add_candidate_to_race and sp_update_candidate
-- The migration 067 created new overloads (with photo_url) alongside old ones.
-- Having both causes "ambiguous function call" for 7/6-arg calls.
-- ============================================================

-- Drop old 7-arg sp_add_candidate_to_race (without photo_url)
DROP FUNCTION IF EXISTS sp_add_candidate_to_race(
  BIGINT, TEXT, TEXT, TEXT, TEXT, INT, BIGINT
);

-- Drop old 6-arg sp_update_candidate (without photo_url)
DROP FUNCTION IF EXISTS sp_update_candidate(
  BIGINT, TEXT, TEXT, TEXT, TEXT, BIGINT
);


-- ============================================================
-- Fix 2: Update sp_get_candidates_for_race to return photo_url
-- Must DROP first because return type (OUT params) changed.
-- ============================================================

DROP FUNCTION IF EXISTS sp_get_candidates_for_race(BIGINT);

CREATE FUNCTION sp_get_candidates_for_race(p_race_id BIGINT)
RETURNS TABLE(
  candidate_id BIGINT,
  full_name VARCHAR,
  affiliation_name VARCHAR,
  bio TEXT,
  manifesto TEXT,
  photo_url TEXT,
  is_approved BOOLEAN,
  ballot_order INT,
  display_name VARCHAR
)
LANGUAGE sql
STABLE
AS $$
  SELECT
    c.candidate_id,
    c.full_name,
    c.affiliation_name,
    c.bio,
    c.manifesto,
    c.photo_url,
    c.is_approved,
    cr.ballot_order,
    cr.display_name
  FROM candidate_races cr
  JOIN candidates c ON cr.candidate_id = c.candidate_id
  WHERE cr.race_id = p_race_id
  ORDER BY cr.ballot_order NULLS LAST, c.full_name;
$$;

COMMIT;
