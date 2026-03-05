CREATE OR REPLACE FUNCTION public.sp_request_to_join_organization(p_organization_id bigint, p_user_id bigint, p_message text DEFAULT NULL::text)
 RETURNS bigint
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_request_id BIGINT;
    v_already_member BOOLEAN;
    v_pending_request BOOLEAN;
BEGIN
    -- Check if user is already a member
    SELECT EXISTS(
        SELECT 1 FROM org_members 
        WHERE organization_id = p_organization_id 
        AND user_id = p_user_id 
        AND is_active = TRUE
    ) INTO v_already_member;

    IF v_already_member THEN
        RAISE EXCEPTION 'You are already a member of this organization'
            USING ERRCODE = '23505';
    END IF;

    -- Check if there's already a pending request
    SELECT EXISTS(
        SELECT 1 FROM organization_join_requests 
        WHERE organization_id = p_organization_id 
        AND user_id = p_user_id 
        AND status = 'PENDING'
    ) INTO v_pending_request;

    IF v_pending_request THEN
        RAISE EXCEPTION 'You already have a pending request for this organization'
            USING ERRCODE = '23505';
    END IF;

    -- Create join request
    INSERT INTO organization_join_requests (
        organization_id,
        user_id,
        request_message,
        status
    )
    VALUES (
        p_organization_id,
        p_user_id,
        p_message,
        'PENDING'
    )
    RETURNING request_id INTO v_request_id;

    RETURN v_request_id;
END;
$function$
;
