-- Migration 057: Add election report generation function
-- Creates function to generate comprehensive election reports with winners, margins, and statistics

CREATE OR REPLACE FUNCTION sp_generate_election_report(
    p_election_id BIGINT
) RETURNS TABLE (
    race_id BIGINT,
    race_name VARCHAR,
    total_votes_cast BIGINT,
    max_winners INT,
    candidate_race_id BIGINT,
    candidate_name VARCHAR,
    votes_received INT,
    vote_percentage NUMERIC(5,2),
    rank INT,
    is_winner BOOLEAN,
    margin_from_next INT
) AS $$
BEGIN
    RETURN QUERY
    WITH race_stats AS (
        -- Get total votes cast per race
        SELECT 
            v.race_id,
            COUNT(*) as total_votes
        FROM votes v
        WHERE v.election_id = p_election_id
        GROUP BY v.race_id
    ),
    ranked_candidates AS (
        -- Rank candidates by votes within each race
        SELECT 
            er.race_id,
            er.race_name,
            er.max_winners,
            rr.candidate_race_id,
            c.full_name,
            COALESCE(rr.total_votes, 0) as votes,
            COALESCE(rs.total_votes, 0) as race_total_votes,
            ROW_NUMBER() OVER (
                PARTITION BY er.race_id 
                ORDER BY COALESCE(rr.total_votes, 0) DESC, cr.ballot_order ASC
            ) as rank
        FROM election_races er
        JOIN candidate_races cr ON cr.race_id = er.race_id
        JOIN candidates c ON c.candidate_id = cr.candidate_id
        LEFT JOIN race_results rr ON rr.candidate_race_id = cr.candidate_race_id
        LEFT JOIN race_stats rs ON rs.race_id = er.race_id
        WHERE er.election_id = p_election_id
    )
    SELECT 
        rc.race_id,
        rc.race_name,
        rc.race_total_votes::BIGINT,
        rc.max_winners,
        rc.candidate_race_id,
        rc.full_name,
        rc.votes,
        CASE 
            WHEN rc.race_total_votes > 0 THEN 
                ROUND((rc.votes::NUMERIC / rc.race_total_votes::NUMERIC * 100), 2)
            ELSE 0.0
        END as vote_percentage,
        rc.rank::INT,
        (rc.rank <= rc.max_winners) as is_winner,
        COALESCE(
            rc.votes - LEAD(rc.votes) OVER (PARTITION BY rc.race_id ORDER BY rc.rank),
            0
        ) as margin_from_next
    FROM ranked_candidates rc
    ORDER BY rc.race_id, rc.rank;
END;
$$ LANGUAGE plpgsql;

-- Create a summary function for quick election stats
CREATE OR REPLACE FUNCTION sp_get_election_summary(
    p_election_id BIGINT
) RETURNS TABLE (
    total_races BIGINT,
    total_candidates BIGINT,
    total_votes_cast BIGINT,
    total_voters_participated BIGINT,
    election_status VARCHAR
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        (SELECT COUNT(*) FROM election_races WHERE election_id = p_election_id)::BIGINT,
        (SELECT COUNT(DISTINCT cr.candidate_id) 
         FROM candidate_races cr 
         JOIN election_races er ON cr.race_id = er.race_id 
         WHERE er.election_id = p_election_id)::BIGINT,
        (SELECT COUNT(*) FROM votes WHERE election_id = p_election_id)::BIGINT,
        (SELECT COUNT(DISTINCT voter_id) FROM votes WHERE election_id = p_election_id)::BIGINT,
        (SELECT e.status::VARCHAR FROM elections e WHERE e.election_id = p_election_id);
END;
$$ LANGUAGE plpgsql;
