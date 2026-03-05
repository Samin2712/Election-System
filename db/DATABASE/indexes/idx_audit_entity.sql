CREATE INDEX idx_audit_entity ON public.audit_logs USING btree (entity_name, entity_id);
