-- Fix for sp_get_user_organizations type mismatch
-- Run this manually to fix the function

-- Drop the old function
DROP FUNCTION IF EXISTS sp_get_user_organizations(BIGINT);

-- Recreate with correct types (TEXT instead of VARCHAR)
CREATE OR REPLACE FUNCTION sp_get_user_organizations(
    p_user_id BIGINT
)
RETURNS TABLE (
    organization_id BIGINT,
    organization_name VARCHAR(255),
    organization_type VARCHAR(50),
    organization_code VARCHAR(50),
    organization_status VARCHAR(20),
    user_role TEXT,  -- Changed to TEXT to match om.role_name
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
        om.role_name as user_role,
        om.is_active as is_member_active,
        om.created_at as joined_at
    FROM organizations o
    JOIN org_members om ON o.organization_id = om.organization_id
    WHERE om.user_id = p_user_id
    AND om.is_active = TRUE
    ORDER BY om.created_at DESC;
END;
$$;

-- Also fix sp_get_user_org_role
DROP FUNCTION IF EXISTS sp_get_user_org_role(BIGINT, BIGINT);

CREATE OR REPLACE FUNCTION sp_get_user_org_role(
    p_user_id BIGINT,
    p_organization_id BIGINT
)
RETURNS TABLE (
    role_name TEXT,  -- Changed to TEXT
    is_active BOOLEAN
)
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        om.role_name,
        om.is_active
    FROM org_members om
    WHERE om.user_id = p_user_id
    AND om.organization_id = p_organization_id
    LIMIT 1;
END;
$$;

SELECT 'Functions fixed successfully!' as message;
