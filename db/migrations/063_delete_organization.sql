BEGIN;

-- Delete organization (OWNER only)
-- This will cascade delete:
--   - All elections (and their races, candidates, votes, results)
--   - All organization members
--   - All invites and join requests
--   - Related audit logs
CREATE OR REPLACE FUNCTION sp_delete_organization(
    p_organization_id INT,
    p_user_id INT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_role TEXT;
    v_org_name TEXT;
BEGIN
    -- Check if user is OWNER of the organization
    SELECT role_name INTO v_role
    FROM org_members
    WHERE organization_id = p_organization_id
      AND user_id = p_user_id
      AND is_active = TRUE;

    IF v_role IS NULL THEN
        RAISE EXCEPTION 'User is not a member of this organization'
            USING ERRCODE = '28000'; -- invalid_authorization_specification
    END IF;

    IF v_role <> 'OWNER' THEN
        RAISE EXCEPTION 'Only the OWNER can delete an organization'
            USING ERRCODE = '28000';
    END IF;

    -- Get organization name for audit log
    SELECT organization_name INTO v_org_name
    FROM organizations
    WHERE organization_id = p_organization_id;

    IF v_org_name IS NULL THEN
        RAISE EXCEPTION 'Organization not found'
            USING ERRCODE = '02000'; -- no_data
    END IF;

    -- Log the deletion before deleting (since cascade will delete audit_logs too)
    -- We insert into a different way - just print to notice for debugging
    RAISE NOTICE 'Deleting organization: % (ID: %)', v_org_name, p_organization_id;

    -- Delete the organization - CASCADE will handle all related records
    DELETE FROM organizations
    WHERE organization_id = p_organization_id;

    -- If we reach here, deletion was successful
END;
$$;

COMMENT ON FUNCTION sp_delete_organization(INT, INT) IS 
    'Deletes an organization and all related data. Only OWNER can perform this action.';

COMMIT;
