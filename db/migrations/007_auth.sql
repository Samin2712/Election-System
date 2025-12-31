BEGIN;

-- Insert default roles if they don't exist
INSERT INTO roles(role_name, description) VALUES
  ('SUPER_ADMIN', 'System administrator'),
  ('ORG_ADMIN', 'Organization administrator'),
  ('OFFICER', 'Election officer'),
  ('USER', 'Regular user')
ON CONFLICT (role_name) DO NOTHING;

-- Register: inserts user (password_hash is computed in Node)
CREATE OR REPLACE FUNCTION sp_register_user(
  p_username varchar,
  p_email citext,
  p_password_hash text,
  p_role_name varchar DEFAULT 'USER'
)
RETURNS bigint
LANGUAGE plpgsql
AS $$
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
$$;

-- Login helper: returns hash + role so Node can verify password and issue JWT
CREATE OR REPLACE FUNCTION sp_get_user_for_login(p_email citext)
RETURNS TABLE(user_id bigint, email citext, password_hash text, role_id bigint, is_active boolean)
LANGUAGE sql
AS $$
  SELECT user_id, email, password_hash, role_id, is_active
  FROM user_accounts
  WHERE email = p_email;
$$;

COMMIT;
