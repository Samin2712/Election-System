CREATE INDEX idx_join_requests_status ON public.organization_join_requests USING btree (status);
