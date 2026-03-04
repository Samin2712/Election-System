BEGIN;

-- =====================================================
-- FIX EXISTING RACES: SET MAX_WINNERS = MAX_VOTES_PER_VOTER
-- For races created before max_winners feature, the value is 1
-- This updates them to match max_votes_per_voter which was the 
-- intended behavior for multi-winner races
-- =====================================================

UPDATE election_races
SET max_winners = max_votes_per_voter
WHERE max_winners = 1 AND max_votes_per_voter > 1;

COMMIT;
