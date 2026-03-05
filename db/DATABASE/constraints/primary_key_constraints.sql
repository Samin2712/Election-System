ALTER TABLE audit_logs ADD CONSTRAINT audit_logs_pkey
  PRIMARY KEY (audit_id);

ALTER TABLE candidate_races ADD CONSTRAINT candidate_races_pkey
  PRIMARY KEY (candidate_race_id);

ALTER TABLE candidates ADD CONSTRAINT candidates_pkey
  PRIMARY KEY (candidate_id);

ALTER TABLE election_eligible_member_types ADD CONSTRAINT election_eligible_member_types_pkey
  PRIMARY KEY (election_id, member_type);

ALTER TABLE election_races ADD CONSTRAINT election_races_pkey
  PRIMARY KEY (race_id);

ALTER TABLE elections ADD CONSTRAINT elections_pkey
  PRIMARY KEY (election_id);

ALTER TABLE invitation_batches ADD CONSTRAINT invitation_batches_pkey
  PRIMARY KEY (batch_id);

ALTER TABLE org_member_master ADD CONSTRAINT org_member_master_pkey
  PRIMARY KEY (member_id, organization_id);

ALTER TABLE org_members ADD CONSTRAINT org_members_pkey
  PRIMARY KEY (user_id, organization_id);

ALTER TABLE organization_invites ADD CONSTRAINT organization_invites_pkey
  PRIMARY KEY (invite_id);

ALTER TABLE organization_join_requests ADD CONSTRAINT organization_join_requests_pkey
  PRIMARY KEY (request_id);

ALTER TABLE organization_requests ADD CONSTRAINT organization_requests_pkey
  PRIMARY KEY (request_id);

ALTER TABLE organizations ADD CONSTRAINT organizations_pkey
  PRIMARY KEY (organization_id);

ALTER TABLE race_results ADD CONSTRAINT race_results_pkey
  PRIMARY KEY (candidate_race_id, race_id);

ALTER TABLE roles ADD CONSTRAINT roles_pkey
  PRIMARY KEY (role_id);

ALTER TABLE schema_migrations ADD CONSTRAINT schema_migrations_pkey
  PRIMARY KEY (filename);

ALTER TABLE system_configs ADD CONSTRAINT system_configs_pkey
  PRIMARY KEY (config_id);

ALTER TABLE user_accounts ADD CONSTRAINT user_accounts_pkey
  PRIMARY KEY (user_id);

ALTER TABLE voters ADD CONSTRAINT voters_pkey
  PRIMARY KEY (voter_id);

ALTER TABLE votes ADD CONSTRAINT votes_pkey
  PRIMARY KEY (vote_id);
