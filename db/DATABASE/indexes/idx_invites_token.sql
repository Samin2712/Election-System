CREATE INDEX idx_invites_token ON public.organization_invites USING btree (token) WHERE ((status)::text = 'PENDING'::text);
