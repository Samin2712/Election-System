CREATE OR REPLACE FUNCTION public.is_system_admin(p_user_id bigint)
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE
AS $function$
DECLARE
    v_is_admin BOOLEAN;
BEGIN
    SELECT is_system_admin INTO v_is_admin
    FROM user_accounts
    WHERE user_id = p_user_id;
    
    RETURN COALESCE(v_is_admin, FALSE);
END;
$function$
;
