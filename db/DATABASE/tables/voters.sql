CREATE TABLE voters (
  voter_id  BIGINT  NOT NULL,
  user_id  BIGINT  NOT NULL,
  organization_id  BIGINT  NOT NULL,
  member_id  VARCHAR(80)  NOT NULL,
  voter_type  VARCHAR(50)  NOT NULL,
  status  voter_status  DEFAULT 'PENDING'::voter_status  NOT NULL,
  registered_at  TIMESTAMPTZ  DEFAULT now()  NOT NULL,
  is_approved  BOOLEAN  DEFAULT false  NOT NULL,
  approved_by  BIGINT,
  approved_at  TIMESTAMPTZ
);
