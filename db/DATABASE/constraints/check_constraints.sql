ALTER TABLE audit_logs ADD CONSTRAINT audit_logs_action_timestamp_not_null
  CHECK (action_timestamp IS NOT NULL);

ALTER TABLE audit_logs ADD CONSTRAINT audit_logs_action_type_not_null
  CHECK (action_type IS NOT NULL);

ALTER TABLE audit_logs ADD CONSTRAINT audit_logs_audit_id_not_null
  CHECK (audit_id IS NOT NULL);

ALTER TABLE audit_logs ADD CONSTRAINT audit_logs_entity_name_not_null
  CHECK (entity_name IS NOT NULL);

ALTER TABLE candidate_races ADD CONSTRAINT candidate_races_candidate_id_not_null
  CHECK (candidate_id IS NOT NULL);

ALTER TABLE candidate_races ADD CONSTRAINT candidate_races_candidate_race_id_not_null
  CHECK (candidate_race_id IS NOT NULL);

ALTER TABLE candidate_races ADD CONSTRAINT candidate_races_race_id_not_null
  CHECK (race_id IS NOT NULL);

ALTER TABLE candidates ADD CONSTRAINT candidates_candidate_id_not_null
  CHECK (candidate_id IS NOT NULL);

ALTER TABLE candidates ADD CONSTRAINT candidates_full_name_not_null
  CHECK (full_name IS NOT NULL);

ALTER TABLE candidates ADD CONSTRAINT candidates_is_approved_not_null
  CHECK (is_approved IS NOT NULL);

ALTER TABLE election_eligible_member_types ADD CONSTRAINT election_eligible_member_types_election_id_not_null
  CHECK (election_id IS NOT NULL);

ALTER TABLE election_eligible_member_types ADD CONSTRAINT election_eligible_member_types_member_type_not_null
  CHECK (member_type IS NOT NULL);

ALTER TABLE election_races ADD CONSTRAINT chk_max_winners
  CHECK ((max_winners >= 1));

ALTER TABLE election_races ADD CONSTRAINT chk_race_max_votes
  CHECK ((max_votes_per_voter >= 1));

ALTER TABLE election_races ADD CONSTRAINT election_races_election_id_not_null
  CHECK (election_id IS NOT NULL);

ALTER TABLE election_races ADD CONSTRAINT election_races_max_votes_per_voter_not_null
  CHECK (max_votes_per_voter IS NOT NULL);

ALTER TABLE election_races ADD CONSTRAINT election_races_max_winners_not_null
  CHECK (max_winners IS NOT NULL);

ALTER TABLE election_races ADD CONSTRAINT election_races_race_id_not_null
  CHECK (race_id IS NOT NULL);

ALTER TABLE election_races ADD CONSTRAINT election_races_race_name_not_null
  CHECK (race_name IS NOT NULL);

ALTER TABLE elections ADD CONSTRAINT chk_election_time
  CHECK (((start_datetime IS NULL) OR (end_datetime IS NULL) OR (end_datetime > start_datetime)));

ALTER TABLE elections ADD CONSTRAINT elections_created_at_not_null
  CHECK (created_at IS NOT NULL);

ALTER TABLE elections ADD CONSTRAINT elections_election_id_not_null
  CHECK (election_id IS NOT NULL);

ALTER TABLE elections ADD CONSTRAINT elections_election_name_not_null
  CHECK (election_name IS NOT NULL);

ALTER TABLE elections ADD CONSTRAINT elections_organization_id_not_null
  CHECK (organization_id IS NOT NULL);

ALTER TABLE elections ADD CONSTRAINT elections_status_not_null
  CHECK (status IS NOT NULL);

ALTER TABLE invitation_batches ADD CONSTRAINT invitation_batches_batch_id_not_null
  CHECK (batch_id IS NOT NULL);

ALTER TABLE invitation_batches ADD CONSTRAINT invitation_batches_created_by_not_null
  CHECK (created_by IS NOT NULL);

ALTER TABLE invitation_batches ADD CONSTRAINT invitation_batches_failed_emails_not_null
  CHECK (failed_emails IS NOT NULL);

ALTER TABLE invitation_batches ADD CONSTRAINT invitation_batches_organization_id_not_null
  CHECK (organization_id IS NOT NULL);

ALTER TABLE invitation_batches ADD CONSTRAINT invitation_batches_status_check
  CHECK (((status)::text = ANY ((ARRAY['PROCESSING'::character varying, 'COMPLETED'::character varying, 'FAILED'::character varying])::text[])));

ALTER TABLE invitation_batches ADD CONSTRAINT invitation_batches_status_not_null
  CHECK (status IS NOT NULL);

ALTER TABLE invitation_batches ADD CONSTRAINT invitation_batches_successful_emails_not_null
  CHECK (successful_emails IS NOT NULL);

ALTER TABLE invitation_batches ADD CONSTRAINT invitation_batches_total_emails_not_null
  CHECK (total_emails IS NOT NULL);

ALTER TABLE org_member_master ADD CONSTRAINT org_member_master_full_name_not_null
  CHECK (full_name IS NOT NULL);

ALTER TABLE org_member_master ADD CONSTRAINT org_member_master_is_active_not_null
  CHECK (is_active IS NOT NULL);

ALTER TABLE org_member_master ADD CONSTRAINT org_member_master_member_id_not_null
  CHECK (member_id IS NOT NULL);

ALTER TABLE org_member_master ADD CONSTRAINT org_member_master_member_type_not_null
  CHECK (member_type IS NOT NULL);

ALTER TABLE org_member_master ADD CONSTRAINT org_member_master_organization_id_not_null
  CHECK (organization_id IS NOT NULL);

ALTER TABLE org_members ADD CONSTRAINT org_members_created_at_not_null
  CHECK (created_at IS NOT NULL);

ALTER TABLE org_members ADD CONSTRAINT org_members_is_active_not_null
  CHECK (is_active IS NOT NULL);

ALTER TABLE org_members ADD CONSTRAINT org_members_organization_id_not_null
  CHECK (organization_id IS NOT NULL);

ALTER TABLE org_members ADD CONSTRAINT org_members_role_name_check
  CHECK ((role_name = ANY (ARRAY['OWNER'::text, 'ADMIN'::text, 'MEMBER'::text])));

ALTER TABLE org_members ADD CONSTRAINT org_members_role_name_not_null
  CHECK (role_name IS NOT NULL);

ALTER TABLE org_members ADD CONSTRAINT org_members_user_id_not_null
  CHECK (user_id IS NOT NULL);

ALTER TABLE organization_invites ADD CONSTRAINT organization_invites_email_not_null
  CHECK (email IS NOT NULL);

ALTER TABLE organization_invites ADD CONSTRAINT organization_invites_expires_at_not_null
  CHECK (expires_at IS NOT NULL);

ALTER TABLE organization_invites ADD CONSTRAINT organization_invites_invite_id_not_null
  CHECK (invite_id IS NOT NULL);

ALTER TABLE organization_invites ADD CONSTRAINT organization_invites_organization_id_not_null
  CHECK (organization_id IS NOT NULL);

ALTER TABLE organization_invites ADD CONSTRAINT organization_invites_role_name_not_null
  CHECK (role_name IS NOT NULL);

ALTER TABLE organization_invites ADD CONSTRAINT organization_invites_status_check
  CHECK (((status)::text = ANY ((ARRAY['PENDING'::character varying, 'ACCEPTED'::character varying, 'EXPIRED'::character varying, 'REVOKED'::character varying])::text[])));

ALTER TABLE organization_invites ADD CONSTRAINT organization_invites_status_not_null
  CHECK (status IS NOT NULL);

ALTER TABLE organization_invites ADD CONSTRAINT organization_invites_token_not_null
  CHECK (token IS NOT NULL);

ALTER TABLE organization_join_requests ADD CONSTRAINT organization_join_requests_organization_id_not_null
  CHECK (organization_id IS NOT NULL);

ALTER TABLE organization_join_requests ADD CONSTRAINT organization_join_requests_request_id_not_null
  CHECK (request_id IS NOT NULL);

ALTER TABLE organization_join_requests ADD CONSTRAINT organization_join_requests_status_check
  CHECK (((status)::text = ANY ((ARRAY['PENDING'::character varying, 'APPROVED'::character varying, 'REJECTED'::character varying])::text[])));

ALTER TABLE organization_join_requests ADD CONSTRAINT organization_join_requests_status_not_null
  CHECK (status IS NOT NULL);

ALTER TABLE organization_join_requests ADD CONSTRAINT organization_join_requests_user_id_not_null
  CHECK (user_id IS NOT NULL);

ALTER TABLE organization_requests ADD CONSTRAINT organization_requests_created_at_not_null
  CHECK (created_at IS NOT NULL);

ALTER TABLE organization_requests ADD CONSTRAINT organization_requests_organization_code_not_null
  CHECK (organization_code IS NOT NULL);

ALTER TABLE organization_requests ADD CONSTRAINT organization_requests_organization_name_not_null
  CHECK (organization_name IS NOT NULL);

ALTER TABLE organization_requests ADD CONSTRAINT organization_requests_organization_type_not_null
  CHECK (organization_type IS NOT NULL);

ALTER TABLE organization_requests ADD CONSTRAINT organization_requests_request_id_not_null
  CHECK (request_id IS NOT NULL);

ALTER TABLE organization_requests ADD CONSTRAINT organization_requests_requested_by_not_null
  CHECK (requested_by IS NOT NULL);

ALTER TABLE organization_requests ADD CONSTRAINT organization_requests_status_not_null
  CHECK (status IS NOT NULL);

ALTER TABLE organization_requests ADD CONSTRAINT organization_requests_updated_at_not_null
  CHECK (updated_at IS NOT NULL);

ALTER TABLE organizations ADD CONSTRAINT organizations_created_at_not_null
  CHECK (created_at IS NOT NULL);

ALTER TABLE organizations ADD CONSTRAINT organizations_organization_code_not_null
  CHECK (organization_code IS NOT NULL);

ALTER TABLE organizations ADD CONSTRAINT organizations_organization_id_not_null
  CHECK (organization_id IS NOT NULL);

ALTER TABLE organizations ADD CONSTRAINT organizations_organization_name_not_null
  CHECK (organization_name IS NOT NULL);

ALTER TABLE organizations ADD CONSTRAINT organizations_organization_type_not_null
  CHECK (organization_type IS NOT NULL);

ALTER TABLE organizations ADD CONSTRAINT organizations_status_check
  CHECK (((status)::text = ANY ((ARRAY['PENDING'::character varying, 'ACTIVE'::character varying, 'SUSPENDED'::character varying, 'ARCHIVED'::character varying])::text[])));

ALTER TABLE race_results ADD CONSTRAINT race_results_candidate_race_id_not_null
  CHECK (candidate_race_id IS NOT NULL);

ALTER TABLE race_results ADD CONSTRAINT race_results_last_updated_not_null
  CHECK (last_updated IS NOT NULL);

ALTER TABLE race_results ADD CONSTRAINT race_results_race_id_not_null
  CHECK (race_id IS NOT NULL);

ALTER TABLE race_results ADD CONSTRAINT race_results_total_votes_not_null
  CHECK (total_votes IS NOT NULL);

ALTER TABLE roles ADD CONSTRAINT roles_role_id_not_null
  CHECK (role_id IS NOT NULL);

ALTER TABLE roles ADD CONSTRAINT roles_role_name_not_null
  CHECK (role_name IS NOT NULL);

ALTER TABLE schema_migrations ADD CONSTRAINT schema_migrations_applied_at_not_null
  CHECK (applied_at IS NOT NULL);

ALTER TABLE schema_migrations ADD CONSTRAINT schema_migrations_filename_not_null
  CHECK (filename IS NOT NULL);

ALTER TABLE system_configs ADD CONSTRAINT system_configs_config_id_not_null
  CHECK (config_id IS NOT NULL);

ALTER TABLE system_configs ADD CONSTRAINT system_configs_config_json_not_null
  CHECK (config_json IS NOT NULL);

ALTER TABLE system_configs ADD CONSTRAINT system_configs_config_key_not_null
  CHECK (config_key IS NOT NULL);

ALTER TABLE system_configs ADD CONSTRAINT system_configs_updated_at_not_null
  CHECK (updated_at IS NOT NULL);

ALTER TABLE user_accounts ADD CONSTRAINT user_accounts_created_at_not_null
  CHECK (created_at IS NOT NULL);

ALTER TABLE user_accounts ADD CONSTRAINT user_accounts_email_not_null
  CHECK (email IS NOT NULL);

ALTER TABLE user_accounts ADD CONSTRAINT user_accounts_is_active_not_null
  CHECK (is_active IS NOT NULL);

ALTER TABLE user_accounts ADD CONSTRAINT user_accounts_password_hash_not_null
  CHECK (password_hash IS NOT NULL);

ALTER TABLE user_accounts ADD CONSTRAINT user_accounts_role_id_not_null
  CHECK (role_id IS NOT NULL);

ALTER TABLE user_accounts ADD CONSTRAINT user_accounts_user_id_not_null
  CHECK (user_id IS NOT NULL);

ALTER TABLE user_accounts ADD CONSTRAINT user_accounts_username_not_null
  CHECK (username IS NOT NULL);

ALTER TABLE voters ADD CONSTRAINT voters_is_approved_not_null
  CHECK (is_approved IS NOT NULL);

ALTER TABLE voters ADD CONSTRAINT voters_member_id_not_null
  CHECK (member_id IS NOT NULL);

ALTER TABLE voters ADD CONSTRAINT voters_organization_id_not_null
  CHECK (organization_id IS NOT NULL);

ALTER TABLE voters ADD CONSTRAINT voters_registered_at_not_null
  CHECK (registered_at IS NOT NULL);

ALTER TABLE voters ADD CONSTRAINT voters_status_not_null
  CHECK (status IS NOT NULL);

ALTER TABLE voters ADD CONSTRAINT voters_user_id_not_null
  CHECK (user_id IS NOT NULL);

ALTER TABLE voters ADD CONSTRAINT voters_voter_id_not_null
  CHECK (voter_id IS NOT NULL);

ALTER TABLE voters ADD CONSTRAINT voters_voter_type_not_null
  CHECK (voter_type IS NOT NULL);

ALTER TABLE votes ADD CONSTRAINT chk_invalid_reason_consistency
  CHECK ((((is_valid = true) AND (invalid_reason IS NULL)) OR ((is_valid = false) AND (invalid_reason IS NOT NULL))));

ALTER TABLE votes ADD CONSTRAINT votes_candidate_race_id_not_null
  CHECK (candidate_race_id IS NOT NULL);

ALTER TABLE votes ADD CONSTRAINT votes_cast_at_not_null
  CHECK (cast_at IS NOT NULL);

ALTER TABLE votes ADD CONSTRAINT votes_cast_channel_not_null
  CHECK (cast_channel IS NOT NULL);

ALTER TABLE votes ADD CONSTRAINT votes_is_valid_not_null
  CHECK (is_valid IS NOT NULL);

ALTER TABLE votes ADD CONSTRAINT votes_race_id_not_null
  CHECK (race_id IS NOT NULL);

ALTER TABLE votes ADD CONSTRAINT votes_vote_id_not_null
  CHECK (vote_id IS NOT NULL);

ALTER TABLE votes ADD CONSTRAINT votes_voter_id_not_null
  CHECK (voter_id IS NOT NULL);
