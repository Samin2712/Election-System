CREATE OR REPLACE FUNCTION public.sp_reject_join_request(p_request_id bigint, p_admin_user_id bigint)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_org_id BIGINT;
    v_is_admin BOOLEAN;
BEGIN
    -- Get organization from request
    SELECT organization_id
    INTO v_org_id
    FROM organization_join_requests
    WHERE request_id = p_request_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Join request not found'
            USING ERRCODE = '22023';
    END IF;

    -- Check if requesting user is admin/owner
    SELECT is_org_admin(p_admin_user_id, v_org_id) INTO v_is_admin;
    
    IF NOT v_is_admin THEN
        RAISE EXCEPTION 'Not authorized to reject join requests'
            USING ERRCODE = '28000';
    END IF;

    -- Update request status
    UPDATE organization_join_requests
    SET 
        status = 'REJECTED',
        updated_at = NOW()
    WHERE request_id = p_request_id;
END;
$function$
;
