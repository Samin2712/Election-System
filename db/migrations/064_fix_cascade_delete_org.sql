BEGIN;

-- Fix: candidates.organization_id FK missing ON DELETE CASCADE
ALTER TABLE candidates
  DROP CONSTRAINT candidates_organization_id_fkey,
  ADD CONSTRAINT candidates_organization_id_fkey
    FOREIGN KEY (organization_id)
    REFERENCES organizations(organization_id)
    ON DELETE CASCADE;

-- Fix: organization_join_requests.organization_id FK missing ON DELETE CASCADE
ALTER TABLE organization_join_requests
  DROP CONSTRAINT organization_join_requests_organization_id_fkey,
  ADD CONSTRAINT organization_join_requests_organization_id_fkey
    FOREIGN KEY (organization_id)
    REFERENCES organizations(organization_id)
    ON DELETE CASCADE;

COMMIT;
