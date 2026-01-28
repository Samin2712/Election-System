-- Migration 043: Consolidated Member System Fix
-- Replaces logic from 037-042 to ensure consistent, correct state
-- Objectives:
-- 1. Fix org_member_master structure (full_name, email, composite PK)
-- 2. Fix triggers for auto-voter registration (correct columns, exclude admins)
-- 3. Fix member management functions
-- 4. Clean up legacy functions (sp_get_org_members)

BEGIN;

-- ==========================================
-- 1. CLEANUP OLD/BROKEN OBJECTS
-- ==========================================

DROP TRIGGER IF EXISTS trg_org_members_auto_voter ON org_members CASCADE;
DROP FUNCTION IF EXISTS tg_auto_register_voter() CASCADE;
DROP FUNCTION IF EXISTS sp_get_org_members_detailed(BIGINT);
DROP FUNCTION IF EXISTS sp_remove_org_member(BIGINT, BIGINT, BIGINT);

-- Drop legacy functions that might cause confusion
DROP FUNCTION IF EXISTS sp_get_org_members(INT);
DROP FUNCTION IF EXISTS sp_get_org_members(BIGINT);

-- ==========================================
-- 2. FIX TABLE STRUCTURE: org_member_master
-- ==========================================

-- We use DO block to safely alter columns if they are wrong
DO $$
BEGIN
    -- Rename member_name -> full_name
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='org_member_master' AND column_name='member_name') THEN
        ALTER TABLE org_member_master RENAME COLUMN member_name TO full_name;
    END IF;

    -- Rename member_email -> email
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='org_member_master' AND column_name='member_email') THEN
        ALTER TABLE org_member_master RENAME COLUMN member_email TO email;
    END IF;
END $$;

-- Ensure table exists with correct constraints
CREATE TABLE IF NOT EXISTS org_member_master (
    organization_id BIGINT NOT NULL REFERENCES organizations(organization_id) ON DELETE CASCADE,
    member_id       VARCHAR(80) NOT NULL,
    member_type     VARCHAR(50) NOT NULL DEFAULT 'USER',
    full_name       VARCHAR(200) NOT NULL,
    date_of_birth   DATE,
    email           CITEXT,
    extra_info_json JSONB,
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    
    PRIMARY KEY (organization_id, member_id)
);

-- Ensure voters FK is correct
ALTER TABLE voters DROP CONSTRAINT IF EXISTS fk_voter_member;
ALTER TABLE voters 
    ADD CONSTRAINT fk_voter_member 
    FOREIGN KEY (organization_id, member_id) 
    REFERENCES org_member_master(organization_id, member_id) 
    ON DELETE RESTRICT;

-- ==========================================
-- 3. TRIGGER: Auto-Register Voters
-- ==========================================

CREATE OR REPLACE FUNCTION tg_auto_register_voter()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_user_id BIGINT;
    v_username VARCHAR(100);
    v_email CITEXT;
    v_org_id BIGINT;
    v_role_name VARCHAR(50);
BEGIN
    -- Only active members
    IF NEW.is_active = FALSE THEN
        RETURN NEW;
    END IF;

    v_user_id := NEW.user_id;
    v_org_id := NEW.organization_id;
    v_role_name := NEW.role_name;

    -- EXCLUDE OWNER/ADMIN from being voters
    IF v_role_name IN ('OWNER', 'ADMIN') THEN
        RETURN NEW;
    END IF;

    -- Get user details
    SELECT username, email INTO v_username, v_email
    FROM user_accounts
    WHERE user_id = v_user_id;

    -- 1. Insert into Master (Idempotent)
    INSERT INTO org_member_master (organization_id, member_id, member_type, full_name, email)
    VALUES (v_org_id, v_user_id::VARCHAR, 'USER', v_username, v_email)
    ON CONFLICT (organization_id, member_id) 
    DO UPDATE SET 
        full_name = EXCLUDED.full_name,
        email = EXCLUDED.email;

    -- 2. Register as Voter (Approved)
    INSERT INTO voters (
        organization_id, user_id, member_id, voter_type, status, is_approved, approved_at
    )
    VALUES (
        v_org_id, v_user_id, v_user_id::VARCHAR, 'USER', 'APPROVED', TRUE, NOW()
    )
    ON CONFLICT (organization_id, user_id)
    DO UPDATE SET
        status = 'APPROVED',
        is_approved = TRUE,
        approved_at = NOW()
    WHERE voters.status != 'APPROVED';

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_org_members_auto_voter
AFTER INSERT OR UPDATE OF is_active ON org_members
FOR EACH ROW
EXECUTE FUNCTION tg_auto_register_voter();

-- ==========================================
-- 4. FUNCTIONS: Member Management
-- ==========================================

-- Detailed member list
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
    ORDER BY 
        CASE WHEN om.role_name = 'OWNER' THEN 1 
             WHEN om.role_name = 'ADMIN' THEN 2 
             ELSE 3 END,
        om.created_at ASC;
END;
$$ LANGUAGE plpgsql;

-- Remove member
CREATE OR REPLACE FUNCTION sp_remove_org_member(
    p_organization_id BIGINT,
    p_user_id BIGINT,
    p_removed_by_user_id BIGINT
)
RETURNS VOID AS $$
DECLARE
    v_is_admin BOOLEAN;
BEGIN
    SELECT is_org_admin(p_removed_by_user_id, p_organization_id) INTO v_is_admin;
    
    IF NOT v_is_admin THEN
        RAISE EXCEPTION 'Not authorized to remove members' USING ERRCODE = '28000';
    END IF;

    -- Deactivate member
    UPDATE org_members
    SET is_active = FALSE
    WHERE organization_id = p_organization_id AND user_id = p_user_id;

    -- Suspend voter
    UPDATE voters
    SET status = 'BLOCKED', is_approved = FALSE
    WHERE organization_id = p_organization_id AND user_id = p_user_id;

    -- Log
    INSERT INTO audit_logs (organization_id, user_id, action_type, entity_name, entity_id, details_json)
    VALUES (p_organization_id, p_removed_by_user_id, 'MEMBER_REMOVED', 'org_members', p_user_id, jsonb_build_object('removed_user_id', p_user_id));
END;
$$ LANGUAGE plpgsql;

-- ==========================================
-- 5. DATA SYNC (Retroactive Fix)
-- ==========================================

-- Populate master from existing members
INSERT INTO org_member_master (organization_id, member_id, member_type, full_name, email)
SELECT om.organization_id, om.user_id::VARCHAR, 'USER', u.username, u.email
FROM org_members om
JOIN user_accounts u ON om.user_id = u.user_id
WHERE om.is_active = TRUE
ON CONFLICT (organization_id, member_id) DO NOTHING;

-- Populate voters from existing members (excluding admin/owner)
INSERT INTO voters (organization_id, user_id, member_id, voter_type, status, is_approved, approved_at)
SELECT 
    om.organization_id, om.user_id, om.user_id::VARCHAR, 'USER', 'APPROVED', TRUE, NOW()
FROM org_members om
WHERE om.is_active = TRUE 
  AND om.role_name NOT IN ('OWNER', 'ADMIN')
ON CONFLICT (organization_id, user_id) DO NOTHING;

-- Remove Owner/Admin from voters table
DELETE FROM voters v
WHERE EXISTS (
    SELECT 1 FROM org_members om 
    WHERE om.organization_id = v.organization_id 
      AND om.user_id = v.user_id 
      AND om.role_name IN ('OWNER', 'ADMIN')
);

COMMIT;

SELECT 'Migration 043 complete: Consolidated Member System Fix' AS message;
