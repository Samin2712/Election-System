-- Migration 056: Add support for multiple winners per race
-- Adds max_winners column to election_races to support races with multiple winners
-- (e.g., "Top 5 Executive Members" where 5 out of 10 candidates win)

-- Add max_winners column to election_races
ALTER TABLE election_races 
ADD COLUMN IF NOT EXISTS max_winners INT NOT NULL DEFAULT 1;

-- Add constraint: max_winners must be at least 1
ALTER TABLE election_races 
ADD CONSTRAINT chk_max_winners CHECK (max_winners >= 1);

-- Comment for documentation
COMMENT ON COLUMN election_races.max_winners IS 'Number of winners for this race (e.g., 5 for "Top 5 Executive Members")';
