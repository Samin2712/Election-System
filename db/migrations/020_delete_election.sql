BEGIN;

-- Function to delete election (Admin/Owner only)
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

    -- Delete election (cascades to races, candidates, votes due to FK constraints)
    DELETE FROM elections WHERE election_id = p_election_id;

    -- Audit log
    INSERT INTO audit_logs (
        organization_id,
        user_id,
        action_type,
        entity_name,
        entity_id
    )
    VALUES (
        v_org_id,
        p_user_id,
        'ELECTION_DELETE',
        'elections',
        p_election_id
    );
END;
$$;

COMMIT;
