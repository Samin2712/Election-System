CREATE OR REPLACE FUNCTION public.sp_generate_election_report(p_election_id bigint)
 RETURNS TABLE(race_id bigint, race_name character varying, total_votes_cast bigint, max_winners integer, candidate_race_id bigint, candidate_name character varying, votes_received integer, vote_percentage numeric, rank integer, is_winner boolean, margin_from_next integer)
 LANGUAGE plpgsql
AS $function$
BEGIN
    RETURN QUERY
    WITH race_stats AS (
        -- Get total votes cast per race (join through election_races to filter by election)
        SELECT 
            v.race_id,
            COUNT(*) as total_votes
        FROM votes v
        JOIN election_races er ON er.race_id = v.race_id
        WHERE er.election_id = p_election_id
        GROUP BY v.race_id
    ),
    ranked_candidates AS (
        -- Rank candidates by votes within each race
        SELECT 
            er.race_id,
            er.race_name,
            er.max_winners,
            cr.candidate_race_id,
            c.full_name,
            COALESCE(rr.total_votes, 0) as votes,
            COALESCE(rs.total_votes, 0) as race_total_votes,
            ROW_NUMBER() OVER (
                PARTITION BY er.race_id 
                ORDER BY COALESCE(rr.total_votes, 0) DESC, cr.ballot_order ASC
            ) as candidate_rank
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
        rc.candidate_rank::INT,
        (rc.candidate_rank <= rc.max_winners) as is_winner,
        COALESCE(
            rc.votes - LEAD(rc.votes) OVER (PARTITION BY rc.race_id ORDER BY rc.candidate_rank),
            0
        ) as margin_from_next
    FROM ranked_candidates rc
    ORDER BY rc.race_id, rc.candidate_rank;
END;
$function$
;
