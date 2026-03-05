CREATE OR REPLACE FUNCTION public.sp_register_user(p_username character varying, p_email citext, p_password_hash text, p_role_name character varying DEFAULT 'USER'::character varying)
 RETURNS bigint
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_role_id bigint;
  v_user_id bigint;
BEGIN
  SELECT role_id INTO v_role_id FROM roles WHERE role_name = p_role_name;
  IF v_role_id IS NULL THEN
    RAISE EXCEPTION 'Invalid role: %', p_role_name;
  END IF;

  INSERT INTO user_accounts(username, email, password_hash, role_id)
  VALUES (p_username, p_email, p_password_hash, v_role_id)
  RETURNING user_id INTO v_user_id;

  RETURN v_user_id;
END;
$function$
;
