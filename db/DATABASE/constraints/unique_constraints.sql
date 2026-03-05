ALTER TABLE candidate_races ADD CONSTRAINT uq_ballot_order_per_race
  UNIQUE (race_id, ballot_order);

ALTER TABLE candidate_races ADD CONSTRAINT uq_candidate_once_per_race
  UNIQUE (candidate_id, race_id);

ALTER TABLE election_races ADD CONSTRAINT uq_race_name_per_election
  UNIQUE (election_id, race_name);

ALTER TABLE organization_invites ADD CONSTRAINT organization_invites_token_key
  UNIQUE (token);

ALTER TABLE organization_invites ADD CONSTRAINT unique_active_invite_per_email
  UNIQUE (organization_id, email);

ALTER TABLE organization_join_requests ADD CONSTRAINT organization_join_requests_approval_token_key
  UNIQUE (approval_token);

ALTER TABLE organizations ADD CONSTRAINT organizations_organization_code_key
  UNIQUE (organization_code);

ALTER TABLE roles ADD CONSTRAINT roles_role_name_key
  UNIQUE (role_name);

ALTER TABLE system_configs ADD CONSTRAINT uq_org_config_key
  UNIQUE (config_key, organization_id);

ALTER TABLE user_accounts ADD CONSTRAINT user_accounts_email_key
  UNIQUE (email);

ALTER TABLE user_accounts ADD CONSTRAINT user_accounts_username_key
  UNIQUE (username);

ALTER TABLE voters ADD CONSTRAINT uq_voters_org_member
  UNIQUE (member_id, organization_id);

ALTER TABLE voters ADD CONSTRAINT uq_voters_org_user
  UNIQUE (organization_id, user_id);

ALTER TABLE votes ADD CONSTRAINT uq_one_vote_per_candidate_per_race
  UNIQUE (candidate_race_id, race_id, voter_id);

ALTER TABLE votes ADD CONSTRAINT uq_vote_voter_candidate_race
  UNIQUE (race_id, candidate_race_id, voter_id);
