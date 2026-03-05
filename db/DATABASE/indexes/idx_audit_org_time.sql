CREATE INDEX idx_audit_org_time ON public.audit_logs USING btree (organization_id, action_timestamp DESC);
