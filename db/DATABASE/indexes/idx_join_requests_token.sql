CREATE INDEX idx_join_requests_token ON public.organization_join_requests USING btree (approval_token);
