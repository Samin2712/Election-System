

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
