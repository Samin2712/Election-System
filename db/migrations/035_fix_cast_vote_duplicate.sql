-- Migration 035: Fix Duplicate sp_cast_vote and Add Results Support
-- Removes the old sp_cast_vote signature and ensures only the correct version exists

BEGIN;

-- Drop the old sp_cast_vote function with the old signature
DROP FUNCTION IF EXISTS sp_cast_vote(bigint, bigint, bigint, vote_channel);

-- The correct sp_cast_vote is defined in migration 011_voting_system.sql
-- It has signature: sp_cast_vote(p_election_id BIGINT, p_race_id BIGINT, p_candidate_id BIGINT, p_voter_user_id BIGINT)
-- No need to recreate it here, just ensure the old one is gone

COMMIT;
