CREATE INDEX idx_join_requests_user ON public.organization_join_requests USING btree (user_id);
