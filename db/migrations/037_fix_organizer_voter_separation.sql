-- Migration 037: Fix Multiple Issues
-- 1. Remove duplicate sp_create_organization function
-- 2. Prevent organizers from being auto-registered as voters
-- 3. Ensure proper type casting

BEGIN;

-- 1. Drop the old INT version of sp_create_organization
DROP FUNCTION IF EXISTS sp_create_organization(TEXT, TEXT, TEXT, INT);

-- The BIGINT version from migration 021 is the correct one and will remain

-- 2. Update auto voter registration trigger to exclude OWNER and ADMIN roles
CREATE OR REPLACE FUNCTION tg_auto_register_voter()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_user_id BIGINT;
    v_username VARCHAR(100);
    v_email VARCHAR(255);
    v_org_id BIGINT;
    v_role_name VARCHAR(50);
BEGIN
    -- Only proceed if member is active
    IF NEW.is_active = FALSE THEN
        RETURN NEW;
    END IF;

    v_user_id := NEW.user_id;
    v_org_id := NEW.organization_id;
    v_role_name := NEW.role_name;

    -- IMPORTANT: Do NOT auto-register OWNER or ADMIN as voters
    -- They manage elections, they don't vote
    IF v_role_name IN ('OWNER', 'ADMIN') THEN
        RETURN NEW;
    END IF;

    -- Get user details
    SELECT username, email INTO v_username, v_email
    FROM user_accounts
    WHERE user_id = v_user_id;

    -- Ensure user exists in org_member_master
    INSERT INTO org_member_master (member_id, member_name, member_email)
    VALUES (v_user_id::VARCHAR, v_username, v_email)
    ON CONFLICT (member_id) DO NOTHING;

    -- Register as voter with APPROVED status
    INSERT INTO voters (
        organization_id,
        user_id,
        member_id,
        voter_type,
        status,
        is_approved
    )
    VALUES (
        v_org_id,
        v_user_id,
        v_user_id::VARCHAR,
        'USER',
        'APPROVED',
        TRUE
    )
    ON CONFLICT (organization_id, user_id)
    DO UPDATE SET
        status = 'APPROVED',
        is_approved = TRUE
    WHERE voters.status != 'APPROVED';

    RETURN NEW;
END;
$$;

-- 3. Remove existing OWNER/ADMIN users from voters table
-- They should not be voters in organizations where they are organizers
DELETE FROM voters v
WHERE EXISTS (
    SELECT 1
    FROM org_members om
    WHERE om.organization_id = v.organization_id
    AND om.user_id = v.user_id
    AND om.role_name IN ('OWNER', 'ADMIN')
    AND om.is_active = TRUE
);

COMMIT;
