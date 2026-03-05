CREATE OR REPLACE FUNCTION public.sp_complete_registration_with_token(p_token character varying, p_user_id bigint)
 RETURNS TABLE(organization_id bigint, organization_name character varying)
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_request_id BIGINT;
    v_org_id BIGINT;
    v_request_user_id BIGINT;
BEGIN
    -- Find the request by token
    SELECT r.request_id, r.organization_id, r.user_id
    INTO v_request_id, v_org_id, v_request_user_id
    FROM organization_join_requests r
    WHERE r.approval_token = p_token
    AND r.status = 'APPROVED';

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Invalid or expired registration token'
            USING ERRCODE = '22023';
    END IF;

    -- Verify the token belongs to this user
    IF v_request_user_id != p_user_id THEN
        RAISE EXCEPTION 'This token does not belong to you'
            USING ERRCODE = '28000';
    END IF;

    -- Add user to organization as MEMBER
    INSERT INTO org_members (
        organization_id,
        user_id,
        role_name,
        is_active
    )
    VALUES (
        v_org_id,
        p_user_id,
        'MEMBER',
        TRUE
    )
    ON CONFLICT (organization_id, user_id) 
    DO UPDATE SET is_active = TRUE, role_name = 'MEMBER';

    -- Invalidate the token by updating status
    UPDATE organization_join_requests
    SET approval_token = NULL  -- Clear token after use
    WHERE request_id = v_request_id;

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
        'USER_JOINED_ORG',
        'org_members',
        v_org_id
    );

    -- Return org details
    RETURN QUERY
    SELECT o.organization_id, o.organization_name
    FROM organizations o
    WHERE o.organization_id = v_org_id;
END;
$function$
;
