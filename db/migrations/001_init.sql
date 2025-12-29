BEGIN;

-- WHY: We use extensions for UUID generation + case-insensitive email
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS citext;

-- =========================
-- 1) ENUMS (Controlled values)
-- WHY: prevents invalid status strings like 'opennn' / 'close'
-- =========================
DO $$ BEGIN
  CREATE TYPE voter_status AS ENUM ('PENDING','APPROVED','BLOCKED');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE election_status AS ENUM ('DRAFT','SCHEDULED','OPEN','CLOSED','ARCHIVED');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE vote_channel AS ENUM ('WEB','MOBILE','OTHER');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- =========================
-- 2) ORGANIZATIONS
-- WHY: top-level tenant boundary (all data scoped by org)
-- =========================
CREATE TABLE IF NOT EXISTS organizations (
  organization_id   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  organization_name VARCHAR(200) NOT NULL,
  organization_type VARCHAR(50)  NOT NULL,  -- e.g. UNIVERSITY/COMPANY/SCHOOL
  organization_code VARCHAR(50)  NOT NULL UNIQUE, -- e.g. IUT
  created_at        TIMESTAMPTZ  NOT NULL DEFAULT now()
);

-- =========================
-- 3) ROLES
-- WHY: system-wide permission grouping
-- =========================
CREATE TABLE IF NOT EXISTS roles (
  role_id     BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  role_name   VARCHAR(50) NOT NULL UNIQUE,  -- SUPER_ADMIN / ORG_ADMIN / OFFICER / USER
  description VARCHAR(255)
);

-- =========================
-- 4) USER ACCOUNTS
-- WHY: platform login identity; not automatically a voter
-- =========================
CREATE TABLE IF NOT EXISTS user_accounts (
  user_id       BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  username      VARCHAR(50) NOT NULL UNIQUE,
  email         CITEXT      NOT NULL UNIQUE,
  password_hash TEXT        NOT NULL,
  role_id       BIGINT      NOT NULL REFERENCES roles(role_id) ON DELETE RESTRICT,
  is_active     BOOLEAN     NOT NULL DEFAULT TRUE,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- =========================
-- 5) ORG MEMBER MASTER
-- WHY: trusted official member registry per organization
-- Only these people can become voters in that org
-- PK is (organization_id, member_id) as you specified
-- =========================
CREATE TABLE IF NOT EXISTS org_member_master (
  organization_id BIGINT NOT NULL REFERENCES organizations(organization_id) ON DELETE CASCADE,
  member_id       VARCHAR(80) NOT NULL,     -- student_id/employee_id etc
  member_type     VARCHAR(50) NOT NULL,     -- STUDENT/TEACHER/EMPLOYEE
  full_name       VARCHAR(200) NOT NULL,
  date_of_birth   DATE,
  email           CITEXT,
  extra_info_json JSONB,
  is_active       BOOLEAN NOT NULL DEFAULT TRUE,

  PRIMARY KEY (organization_id, member_id)
);

-- =========================
-- 6) VOTERS
-- WHY: links platform user to org member, adds approval status
-- constraints ensure:
--  - one user can be voter once per org
--  - one member_id can be used once per org
-- =========================
CREATE TABLE IF NOT EXISTS voters (
  voter_id        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id         BIGINT NOT NULL REFERENCES user_accounts(user_id) ON DELETE CASCADE,
  organization_id BIGINT NOT NULL REFERENCES organizations(organization_id) ON DELETE CASCADE,
  member_id       VARCHAR(80) NOT NULL,
  voter_type      VARCHAR(50) NOT NULL,
  status          voter_status NOT NULL DEFAULT 'PENDING',
  registered_at   TIMESTAMPTZ NOT NULL DEFAULT now(),

  -- WHY: ensure member belongs to the same org and exists in master
  CONSTRAINT fk_voter_member
    FOREIGN KEY (organization_id, member_id)
    REFERENCES org_member_master(organization_id, member_id)
    ON DELETE RESTRICT,

  CONSTRAINT uq_voters_org_member UNIQUE (organization_id, member_id),
  CONSTRAINT uq_voters_org_user   UNIQUE (organization_id, user_id)
);

-- =========================
-- 7) ELECTIONS
-- WHY: election event inside an organization
-- =========================
CREATE TABLE IF NOT EXISTS elections (
  election_id      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  organization_id  BIGINT NOT NULL REFERENCES organizations(organization_id) ON DELETE CASCADE,
  election_name    VARCHAR(200) NOT NULL,
  description      TEXT,
  start_datetime   TIMESTAMPTZ,
  end_datetime     TIMESTAMPTZ,
  status           election_status NOT NULL DEFAULT 'DRAFT',
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),

  -- WHY: basic sanity rule (end after start) when both exist
  CONSTRAINT chk_election_time
    CHECK (start_datetime IS NULL OR end_datetime IS NULL OR end_datetime > start_datetime)
);

-- =========================
-- 8) ELECTION RACES / POSITIONS
-- WHY: each position within an election (President, Secretary)
-- =========================
CREATE TABLE IF NOT EXISTS election_races (
  race_id             BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  election_id         BIGINT NOT NULL REFERENCES elections(election_id) ON DELETE CASCADE,
  race_name           VARCHAR(200) NOT NULL,
  description         TEXT,
  max_votes_per_voter INT NOT NULL DEFAULT 1,

  CONSTRAINT chk_race_max_votes CHECK (max_votes_per_voter >= 1),
  CONSTRAINT uq_race_name_per_election UNIQUE (election_id, race_name)
);

-- =========================
-- 9) CANDIDATES
-- WHY: candidate identity reusable across races/elections
-- =========================
CREATE TABLE IF NOT EXISTS candidates (
  candidate_id      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  full_name         VARCHAR(200) NOT NULL,
  affiliation_name  VARCHAR(200),
  bio               TEXT,
  photo_url         TEXT
);

-- =========================
-- 10) CANDIDATE RACES (linking)
-- WHY: candidate participating in a specific race
-- prevents same candidate twice in same race
-- =========================
CREATE TABLE IF NOT EXISTS candidate_races (
  candidate_race_id      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  race_id                BIGINT NOT NULL REFERENCES election_races(race_id) ON DELETE CASCADE,
  candidate_id           BIGINT NOT NULL REFERENCES candidates(candidate_id) ON DELETE RESTRICT,
  ballot_order           INT,
  display_name           VARCHAR(200),
  affiliation_snapshot   VARCHAR(200),

  CONSTRAINT uq_candidate_once_per_race UNIQUE (race_id, candidate_id),
  CONSTRAINT uq_ballot_order_per_race UNIQUE (race_id, ballot_order)
);

-- =========================
-- 11) ELECTION ELIGIBLE MEMBER TYPES
-- WHY: defines which member types can vote in an election
-- =========================
CREATE TABLE IF NOT EXISTS election_eligible_member_types (
  election_id  BIGINT NOT NULL REFERENCES elections(election_id) ON DELETE CASCADE,
  member_type  VARCHAR(50) NOT NULL,
  PRIMARY KEY (election_id, member_type)
);

-- =========================
-- 12) VOTES
-- WHY: one vote per voter per race (unique constraint)
-- and vote ties to candidate_race within that race
-- =========================
CREATE TABLE IF NOT EXISTS votes (
  vote_id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  voter_id           BIGINT NOT NULL REFERENCES voters(voter_id) ON DELETE CASCADE,
  race_id            BIGINT NOT NULL REFERENCES election_races(race_id) ON DELETE CASCADE,
  candidate_race_id  BIGINT NOT NULL REFERENCES candidate_races(candidate_race_id) ON DELETE RESTRICT,
  cast_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
  cast_channel       vote_channel NOT NULL DEFAULT 'WEB',
  is_valid           BOOLEAN NOT NULL DEFAULT TRUE,
  invalid_reason     VARCHAR(255),

  -- WHY: enforce "one vote per voter per race"
  CONSTRAINT uq_vote_once_per_race UNIQUE (voter_id, race_id)
);

-- =========================
-- 13) RACE RESULTS (denormalized)
-- WHY: fast result queries without counting votes every time
-- will be updated later via trigger/procedure in migration 003
-- =========================
CREATE TABLE IF NOT EXISTS race_results (
  race_id            BIGINT NOT NULL REFERENCES election_races(race_id) ON DELETE CASCADE,
  candidate_race_id  BIGINT NOT NULL REFERENCES candidate_races(candidate_race_id) ON DELETE CASCADE,
  total_votes        INT NOT NULL DEFAULT 0,
  last_updated       TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (race_id, candidate_race_id)
);

-- =========================
-- 14) AUDIT LOGS
-- WHY: traceability (who did what, when)
-- entity_id is BIGINT because most of your PKs are BIGINT
-- =========================
CREATE TABLE IF NOT EXISTS audit_logs (
  audit_id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  organization_id   BIGINT REFERENCES organizations(organization_id) ON DELETE CASCADE,
  user_id           BIGINT REFERENCES user_accounts(user_id) ON DELETE SET NULL,
  action_type       VARCHAR(50) NOT NULL,   -- CAST_VOTE / CLOSE_ELECTION etc
  entity_name       VARCHAR(50) NOT NULL,   -- VOTE / ELECTION / VOTER etc
  entity_id         BIGINT,
  action_timestamp  TIMESTAMPTZ NOT NULL DEFAULT now(),
  details_json      JSONB
);

-- =========================
-- 15) SYSTEM CONFIGS
-- WHY: flexible JSON settings per org (or global if org null)
-- =========================
CREATE TABLE IF NOT EXISTS system_configs (
  config_id        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  organization_id  BIGINT REFERENCES organizations(organization_id) ON DELETE CASCADE,
  config_key       VARCHAR(100) NOT NULL,
  config_json      JSONB NOT NULL,
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT now(),

  CONSTRAINT uq_org_config_key UNIQUE (organization_id, config_key)
);

COMMIT;
