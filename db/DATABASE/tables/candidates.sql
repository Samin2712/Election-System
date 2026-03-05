CREATE TABLE candidates (
  candidate_id  BIGINT  NOT NULL,
  full_name  VARCHAR(200)  NOT NULL,
  affiliation_name  VARCHAR(200),
  bio  TEXT,
  photo_url  TEXT,
  is_approved  BOOLEAN  DEFAULT true  NOT NULL,
  manifesto  TEXT,
  organization_id  BIGINT,
  member_id  VARCHAR(80)
);
