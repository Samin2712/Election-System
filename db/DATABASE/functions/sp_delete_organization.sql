CREATE OR REPLACE FUNCTION public.sp_delete_organization(p_organization_id integer, p_user_id integer)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
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
            USING ERRCODE = '28000';
    END IF;

    IF v_role <> 'OWNER' THEN
        RAISE EXCEPTION 'Only the OWNER can delete an organization'
            USING ERRCODE = '28000';
    END IF;

    -- Get organization name for logging
    SELECT organization_name INTO v_org_name
    FROM organizations
    WHERE organization_id = p_organization_id;

    IF v_org_name IS NULL THEN
        RAISE EXCEPTION 'Organization not found'
            USING ERRCODE = '02000';
    END IF;

    -- Disable audit triggers on tables that will be cascade-deleted
    -- to prevent FK violations when audit tries to reference the deleted org
    ALTER TABLE votes DISABLE TRIGGER audit_votes;
    ALTER TABLE elections DISABLE TRIGGER audit_elections;
    ALTER TABLE voters DISABLE TRIGGER audit_voters;
    ALTER TABLE candidate_races DISABLE TRIGGER audit_candidate_races;

    -- Delete the organization - CASCADE handles all related records
    DELETE FROM organizations
    WHERE organization_id = p_organization_id;

    -- Re-enable audit triggers
    ALTER TABLE votes ENABLE TRIGGER audit_votes;
    ALTER TABLE elections ENABLE TRIGGER audit_elections;
    ALTER TABLE voters ENABLE TRIGGER audit_voters;
    ALTER TABLE candidate_races ENABLE TRIGGER audit_candidate_races;
END;
$function$
;
