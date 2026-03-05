CREATE UNIQUE INDEX idx_one_pending_request_per_user ON public.organization_join_requests USING btree (organization_id, user_id) WHERE ((status)::text = 'PENDING'::text);
