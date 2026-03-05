CREATE INDEX idx_user_accounts_system_admin ON public.user_accounts USING btree (is_system_admin) WHERE (is_system_admin = true);
