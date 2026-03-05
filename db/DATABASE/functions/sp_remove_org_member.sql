CREATE OR REPLACE FUNCTION public.sp_remove_org_member(p_organization_id bigint, p_user_id bigint, p_removed_by_user_id bigint)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
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
$function$
;
