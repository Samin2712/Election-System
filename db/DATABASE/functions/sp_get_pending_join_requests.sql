CREATE OR REPLACE FUNCTION public.sp_get_pending_join_requests(p_organization_id bigint, p_admin_user_id bigint)
 RETURNS TABLE(request_id integer, user_id bigint, username character varying, email citext, request_message text, created_at timestamp without time zone)
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_is_admin BOOLEAN;
BEGIN
    -- Check if requesting user is admin/owner
    SELECT is_org_admin(p_admin_user_id, p_organization_id) INTO v_is_admin;
    
    IF NOT v_is_admin THEN
        RAISE EXCEPTION 'Not authorized to view join requests'
            USING ERRCODE = '28000';
    END IF;

    RETURN QUERY
    SELECT 
        r.request_id,
        r.user_id,
        u.username,
        u.email,
        r.request_message,
        r.created_at
    FROM organization_join_requests r
    JOIN user_accounts u ON r.user_id = u.user_id
    WHERE r.organization_id = p_organization_id
    AND r.status = 'PENDING'
    ORDER BY r.created_at DESC;
END;
$function$
;
