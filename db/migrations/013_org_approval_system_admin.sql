-- Migration 013: Organization Status & Multi-Org Support
-- Simplified version without system_admins table

-- Step 1: Add status column to organizations
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'organizations' AND column_name = 'status'
    ) THEN
        ALTER TABLE organizations 
        ADD COLUMN status VARCHAR(20) DEFAULT 'ACTIVE' 
        CHECK (status IN ('PENDING', 'ACTIVE', 'SUSPENDED', 'ARCHIVED'));
        
        RAISE NOTICE 'Added status column to organizations table';
    ELSE
        RAISE NOTICE 'Status column already exists in organizations table';
    END IF;
END $$;

-- Step 2: Set existing organizations to ACTIVE
UPDATE organizations 
SET status = 'ACTIVE' 
WHERE status IS NULL OR status = '';

-- Step 3: Create helper function to get user's organizations with roles
CREATE OR REPLACE FUNCTION sp_get_user_organizations(
    p_user_id BIGINT
)
RETURNS TABLE (
    organization_id BIGINT,
    organization_name VARCHAR(255),
    organization_type VARCHAR(50),
    organization_code VARCHAR(50),
    organization_status VARCHAR(20),
    user_role VARCHAR(50),
    is_member_active BOOLEAN,
    joined_at TIMESTAMPTZ
)
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        o.organization_id,
        o.organization_name,
        o.organization_type,
        o.organization_code,
        COALESCE(o.status, 'ACTIVE') as organization_status,
        r.role_name as user_role,
        om.is_active as is_member_active,
        om.created_at as joined_at
    FROM organizations o
    JOIN org_members om ON o.organization_id = om.organization_id
    JOIN roles r ON om.role_id = r.role_id
    WHERE om.user_id = p_user_id
    AND om.is_active = TRUE
    ORDER BY om.created_at DESC;
END;
$$;

-- Step 4: Create helper function to get user's role in specific organization
CREATE OR REPLACE FUNCTION sp_get_user_org_role(
    p_user_id BIGINT,
    p_organization_id BIGINT
)
RETURNS TABLE (
    role_name VARCHAR(50),
    is_active BOOLEAN
)
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        r.role_name,
        om.is_active
    FROM org_members om
    JOIN roles r ON om.role_id = r.role_id
    WHERE om.user_id = p_user_id
    AND om.organization_id = p_organization_id
    LIMIT 1;
END;
$$;

-- Step 5: Add helpful comment
COMMENT ON COLUMN organizations.status IS 'Organization approval status: PENDING (awaiting approval), ACTIVE (approved and active), SUSPENDED (temporarily blocked), ARCHIVED (soft deleted)';

-- Done!
SELECT 'Migration 013 completed successfully!' as message;
