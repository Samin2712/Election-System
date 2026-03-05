ALTER TABLE audit_logs ADD CONSTRAINT audit_logs_organization_id_fkey
  FOREIGN KEY (organization_id)
  REFERENCES organizations (organization_id)
  ON DELETE CASCADE;

ALTER TABLE audit_logs ADD CONSTRAINT audit_logs_user_id_fkey
  FOREIGN KEY (user_id)
  REFERENCES user_accounts (user_id)
  ON DELETE SET NULL;

ALTER TABLE candidate_races ADD CONSTRAINT candidate_races_candidate_id_fkey
  FOREIGN KEY (candidate_id)
  REFERENCES candidates (candidate_id)
  ON DELETE CASCADE;

ALTER TABLE candidate_races ADD CONSTRAINT candidate_races_race_id_fkey
  FOREIGN KEY (race_id)
  REFERENCES election_races (race_id)
  ON DELETE CASCADE;

ALTER TABLE candidates ADD CONSTRAINT candidates_organization_id_fkey
  FOREIGN KEY (organization_id)
  REFERENCES organizations (organization_id)
  ON DELETE CASCADE;

ALTER TABLE election_eligible_member_types ADD CONSTRAINT election_eligible_member_types_election_id_fkey
  FOREIGN KEY (election_id)
  REFERENCES elections (election_id)
  ON DELETE CASCADE;

ALTER TABLE election_races ADD CONSTRAINT election_races_election_id_fkey
  FOREIGN KEY (election_id)
  REFERENCES elections (election_id)
  ON DELETE CASCADE;

ALTER TABLE elections ADD CONSTRAINT elections_created_by_fkey
  FOREIGN KEY (created_by)
  REFERENCES user_accounts (user_id)
  ON DELETE SET NULL;

ALTER TABLE elections ADD CONSTRAINT elections_organization_id_fkey
  FOREIGN KEY (organization_id)
  REFERENCES organizations (organization_id)
  ON DELETE CASCADE;

ALTER TABLE invitation_batches ADD CONSTRAINT invitation_batches_created_by_fkey
  FOREIGN KEY (created_by)
  REFERENCES user_accounts (user_id)
  ON DELETE SET NULL;

ALTER TABLE invitation_batches ADD CONSTRAINT invitation_batches_organization_id_fkey
  FOREIGN KEY (organization_id)
  REFERENCES organizations (organization_id)
  ON DELETE CASCADE;

ALTER TABLE org_member_master ADD CONSTRAINT org_member_master_organization_id_fkey
  FOREIGN KEY (organization_id)
  REFERENCES organizations (organization_id)
  ON DELETE CASCADE;

ALTER TABLE org_members ADD CONSTRAINT org_members_organization_id_fkey
  FOREIGN KEY (organization_id)
  REFERENCES organizations (organization_id)
  ON DELETE CASCADE;

ALTER TABLE org_members ADD CONSTRAINT org_members_user_id_fkey
  FOREIGN KEY (user_id)
  REFERENCES user_accounts (user_id)
  ON DELETE CASCADE;

ALTER TABLE organization_invites ADD CONSTRAINT organization_invites_batch_id_fkey
  FOREIGN KEY (batch_id)
  REFERENCES invitation_batches (batch_id)
  ON DELETE CASCADE;

ALTER TABLE organization_invites ADD CONSTRAINT organization_invites_created_by_fkey
  FOREIGN KEY (created_by)
  REFERENCES user_accounts (user_id)
  ON DELETE SET NULL;

ALTER TABLE organization_invites ADD CONSTRAINT organization_invites_organization_id_fkey
  FOREIGN KEY (organization_id)
  REFERENCES organizations (organization_id)
  ON DELETE CASCADE;

ALTER TABLE organization_join_requests ADD CONSTRAINT organization_join_requests_approved_by_fkey
  FOREIGN KEY (approved_by)
  REFERENCES user_accounts (user_id)
  ON DELETE SET NULL;

ALTER TABLE organization_join_requests ADD CONSTRAINT organization_join_requests_organization_id_fkey
  FOREIGN KEY (organization_id)
  REFERENCES organizations (organization_id)
  ON DELETE CASCADE;

ALTER TABLE organization_join_requests ADD CONSTRAINT organization_join_requests_user_id_fkey
  FOREIGN KEY (user_id)
  REFERENCES user_accounts (user_id)
  ON DELETE CASCADE;

ALTER TABLE organization_requests ADD CONSTRAINT organization_requests_requested_by_fkey
  FOREIGN KEY (requested_by)
  REFERENCES user_accounts (user_id)
  ON DELETE CASCADE;

ALTER TABLE organization_requests ADD CONSTRAINT organization_requests_reviewed_by_fkey
  FOREIGN KEY (reviewed_by)
  REFERENCES user_accounts (user_id);

ALTER TABLE race_results ADD CONSTRAINT race_results_candidate_race_id_fkey
  FOREIGN KEY (candidate_race_id)
  REFERENCES candidate_races (candidate_race_id)
  ON DELETE CASCADE;

ALTER TABLE race_results ADD CONSTRAINT race_results_race_id_fkey
  FOREIGN KEY (race_id)
  REFERENCES election_races (race_id)
  ON DELETE CASCADE;

ALTER TABLE system_configs ADD CONSTRAINT system_configs_organization_id_fkey
  FOREIGN KEY (organization_id)
  REFERENCES organizations (organization_id)
  ON DELETE CASCADE;

ALTER TABLE user_accounts ADD CONSTRAINT user_accounts_role_id_fkey
  FOREIGN KEY (role_id)
  REFERENCES roles (role_id)
  ON DELETE RESTRICT;

ALTER TABLE voters ADD CONSTRAINT fk_voter_member
  FOREIGN KEY (organization_id, member_id)
  REFERENCES org_member_master (member_id, organization_id)
  ON DELETE CASCADE;

ALTER TABLE voters ADD CONSTRAINT voters_approved_by_fkey
  FOREIGN KEY (approved_by)
  REFERENCES user_accounts (user_id)
  ON DELETE SET NULL;

ALTER TABLE voters ADD CONSTRAINT voters_organization_id_fkey
  FOREIGN KEY (organization_id)
  REFERENCES organizations (organization_id)
  ON DELETE CASCADE;

ALTER TABLE voters ADD CONSTRAINT voters_user_id_fkey
  FOREIGN KEY (user_id)
  REFERENCES user_accounts (user_id)
  ON DELETE CASCADE;

ALTER TABLE votes ADD CONSTRAINT votes_candidate_race_id_fkey
  FOREIGN KEY (candidate_race_id)
  REFERENCES candidate_races (candidate_race_id)
  ON DELETE CASCADE;

ALTER TABLE votes ADD CONSTRAINT votes_race_id_fkey
  FOREIGN KEY (race_id)
  REFERENCES election_races (race_id)
  ON DELETE CASCADE;

ALTER TABLE votes ADD CONSTRAINT votes_voter_id_fkey
  FOREIGN KEY (voter_id)
  REFERENCES voters (voter_id)
  ON DELETE CASCADE;
