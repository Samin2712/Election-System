-- Migration 034: Auto Voter Registration and Member Management (Fixed)
-- 1. Automate voter registration for all organization members
-- 2. Add member removal and detailed listing functions

BEGIN;

-- 1) Create Trigger Function for Auto-Voter Registration
CREATE OR REPLACE FUNCTION tg_auto_register_voter()
RETURNS TRIGGER AS $$
DECLARE
    v_username VARCHAR(50);
    v_email CITEXT;
BEGIN
    -- Only register if the member is active
    IF NEW.is_active = TRUE THEN
        -- Get user details for member_master
        SELECT username, email INTO v_username, v_email
        FROM user_accounts WHERE user_id = NEW.user_id;

        -- Ensure they exist in org_member_master (FK requirement for voters)
        INSERT INTO org_member_master (organization_id, member_id, member_type, full_name, email)
        VALUES (NEW.organization_id, NEW.user_id::VARCHAR, 'USER', v_username, v_email)
        ON CONFLICT (organization_id, member_id) DO NOTHING;

        -- Insert into voters as APPROVED
        INSERT INTO voters (
            user_id,
            organization_id,
            member_id,
            voter_type,
            status,
            is_approved,
            approved_by,
            approved_at
        )
        VALUES (
            NEW.user_id,
            NEW.organization_id,
            NEW.user_id::VARCHAR,
            'USER',
            'APPROVED',
            TRUE,
            NEW.user_id, -- Self-approved in this simple context
            NOW()
        )
        ON CONFLICT (organization_id, user_id) 
        DO UPDATE SET 
            status = 'APPROVED', 
            is_approved = TRUE,
            approved_at = NOW();
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 2) Attach Trigger to org_members
DROP TRIGGER IF EXISTS trg_org_members_auto_voter ON org_members;
CREATE TRIGGER trg_org_members_auto_voter
AFTER INSERT OR UPDATE OF is_active ON org_members
FOR EACH ROW
EXECUTE FUNCTION tg_auto_register_voter();

-- 3) Detailed Member Listing Function
CREATE OR REPLACE FUNCTION sp_get_org_members_detailed(
    p_organization_id BIGINT
)
RETURNS TABLE (
    user_id BIGINT,
    username VARCHAR(50),
    email CITEXT,
    role_name TEXT,
    is_active BOOLEAN,
    joined_at TIMESTAMPTZ
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        u.user_id,
        u.username,
        u.email,
        om.role_name,
        om.is_active,
        om.created_at
    FROM org_members om
    JOIN user_accounts u ON om.user_id = u.user_id
    WHERE om.organization_id = p_organization_id
    ORDER BY om.role_name DESC, om.created_at ASC;
END;
$$ LANGUAGE plpgsql;

-- 4) Member Removal Function
CREATE OR REPLACE FUNCTION sp_remove_org_member(
    p_organization_id BIGINT,
    p_user_id BIGINT,
    p_removed_by_user_id BIGINT
)
RETURNS VOID AS $$
DECLARE
    v_is_admin BOOLEAN;
BEGIN
    -- Check if remover is admin
    SELECT is_org_admin(p_removed_by_user_id, p_organization_id) INTO v_is_admin;
    
    IF NOT v_is_admin THEN
        RAISE EXCEPTION 'Not authorized to remove members'
            USING ERRCODE = '28000';
    END IF;

    -- Deactivate member
    UPDATE org_members
    SET is_active = FALSE
    WHERE organization_id = p_organization_id AND user_id = p_user_id;

    -- Deactivate voter registration too
    UPDATE voters
    SET status = 'SUSPENDED', is_approved = FALSE
    WHERE organization_id = p_organization_id AND user_id = p_user_id;

    -- Audit Log
    INSERT INTO audit_logs (organization_id, user_id, action_type, entity_name, entity_id, details_json)
    VALUES (
        p_organization_id,
        p_removed_by_user_id,
        'MEMBER_REMOVED',
        'org_members',
        p_user_id,
        jsonb_build_object('removed_user_id', p_user_id)
    );
END;
$$ LANGUAGE plpgsql;

-- 5) Retroactively register existing members
-- First populate member_master
INSERT INTO org_member_master (organization_id, member_id, member_type, full_name, email)
SELECT om.organization_id, om.user_id::VARCHAR, 'USER', u.username, u.email
FROM org_members om
JOIN user_accounts u ON om.user_id = u.user_id
WHERE om.is_active = TRUE
ON CONFLICT (organization_id, member_id) DO NOTHING;

-- Then populate voters
INSERT INTO voters (
    user_id,
    organization_id,
    member_id,
    voter_type,
    status,
    is_approved,
    approved_by,
    approved_at
)
SELECT 
    om.user_id,
    om.organization_id,
    om.user_id::VARCHAR,
    'USER',
    'APPROVED',
    TRUE,
    om.user_id,
    NOW()
FROM org_members om
WHERE om.is_active = TRUE
ON CONFLICT (organization_id, user_id) 
DO UPDATE SET status = 'APPROVED', is_approved = TRUE, approved_at = NOW();

COMMIT;
