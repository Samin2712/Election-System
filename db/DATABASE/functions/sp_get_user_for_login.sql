CREATE OR REPLACE FUNCTION public.sp_get_user_for_login(p_email citext)
 RETURNS TABLE(user_id bigint, email citext, password_hash text, role_id bigint, is_active boolean)
 LANGUAGE sql
AS $function$
  SELECT user_id, email, password_hash, role_id, is_active
  FROM user_accounts
  WHERE email = p_email;
$function$
;
