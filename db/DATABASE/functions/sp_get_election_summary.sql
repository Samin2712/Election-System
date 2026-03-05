CREATE OR REPLACE FUNCTION public.sp_get_election_summary(p_election_id bigint)
 RETURNS TABLE(election_id bigint, election_name character varying, election_status character varying, total_races bigint, total_candidates bigint, total_votes_cast bigint, total_voters_participated bigint)
 LANGUAGE plpgsql
AS $function$
BEGIN
    RETURN QUERY
    SELECT 
        e.election_id,
        e.election_name::VARCHAR,
        e.status::VARCHAR,
        (SELECT COUNT(*) FROM election_races WHERE election_races.election_id = e.election_id)::BIGINT,
        (SELECT COUNT(DISTINCT cr.candidate_id) 
         FROM candidate_races cr 
         JOIN election_races er ON cr.race_id = er.race_id 
         WHERE er.election_id = e.election_id)::BIGINT,
        (SELECT COUNT(*) 
         FROM votes v 
         JOIN election_races er ON er.race_id = v.race_id 
         WHERE er.election_id = e.election_id)::BIGINT,
        (SELECT COUNT(DISTINCT v.voter_id) 
         FROM votes v 
         JOIN election_races er ON er.race_id = v.race_id 
         WHERE er.election_id = e.election_id)::BIGINT
    FROM elections e
    WHERE e.election_id = p_election_id;
END;
$function$
;
