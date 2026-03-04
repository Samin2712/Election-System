BEGIN;

-- =====================================================
-- FIX DELETE ELECTION FUNCTION
-- votes table doesn't have election_id column
-- Join through election_races to delete votes
-- =====================================================

CREATE OR REPLACE FUNCTION sp_delete_election(
    p_election_id BIGINT,
    p_user_id BIGINT
)
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
    v_org_id BIGINT;
    v_is_admin BOOLEAN;
    v_status election_status;
BEGIN
    -- Get election org and status
    SELECT organization_id, status 
    INTO v_org_id, v_status
    FROM elections 
    WHERE election_id = p_election_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Election not found'
            USING ERRCODE = '22023';
    END IF;

    -- Check if user is admin
    SELECT is_org_admin(p_user_id, v_org_id) INTO v_is_admin;
    
    IF NOT v_is_admin THEN
        RAISE EXCEPTION 'Not authorized to delete election'
            USING ERRCODE = '28000';
    END IF;

    -- Can only delete DRAFT, SCHEDULED, or CLOSED elections (not OPEN)
    IF v_status = 'OPEN' THEN
        RAISE EXCEPTION 'Cannot delete an election that is currently OPEN. Close it first.'
            USING ERRCODE = '22023';
    END IF;

    -- Explicitly delete race_results for all races in this election
    DELETE FROM race_results 
    WHERE race_id IN (
        SELECT race_id FROM election_races WHERE election_id = p_election_id
    );

    -- Delete votes - join through election_races since votes doesn't have election_id
    DELETE FROM votes 
    WHERE race_id IN (
        SELECT race_id FROM election_races WHERE election_id = p_election_id
    );

    -- Delete election (cascades to races, candidates due to FK constraints)
    DELETE FROM elections WHERE election_id = p_election_id;

    -- Audit log
    INSERT INTO audit_logs (
        organization_id,
        user_id,
        action_type,
        entity_name,
        entity_id,
        details_json
    )
    VALUES (
        v_org_id,
        p_user_id,
        'ELECTION_DELETE',
        'elections',
        p_election_id,
        jsonb_build_object(
            'deleted_election_id', p_election_id,
            'previous_status', v_status::TEXT
        )
    );
END;
$$;

COMMIT;
