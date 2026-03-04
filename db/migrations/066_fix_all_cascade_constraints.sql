BEGIN;

-- ============================================================
-- Fix ALL foreign keys that block cascade deletion of an organization
-- Changes RESTRICT / NO ACTION → CASCADE where needed
-- ============================================================

-- 1. candidate_races → candidates (RESTRICT → CASCADE)
ALTER TABLE candidate_races
  DROP CONSTRAINT candidate_races_candidate_id_fkey,
  ADD CONSTRAINT candidate_races_candidate_id_fkey
    FOREIGN KEY (candidate_id) REFERENCES candidates(candidate_id) ON DELETE CASCADE;

-- 2. votes → candidate_races (RESTRICT → CASCADE)
ALTER TABLE votes
  DROP CONSTRAINT votes_candidate_race_id_fkey,
  ADD CONSTRAINT votes_candidate_race_id_fkey
    FOREIGN KEY (candidate_race_id) REFERENCES candidate_races(candidate_race_id) ON DELETE CASCADE;

-- 3. voters → org_member_master (RESTRICT → CASCADE)
ALTER TABLE voters
  DROP CONSTRAINT IF EXISTS fk_voter_member;
-- Re-add only if the columns actually reference org_member_master
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'voters' AND column_name = 'member_id'
  ) THEN
    ALTER TABLE voters
      ADD CONSTRAINT fk_voter_member
        FOREIGN KEY (member_id, organization_id)
        REFERENCES org_member_master(member_id, organization_id)
        ON DELETE CASCADE;
  END IF;
END $$;

-- 4. elections → user_accounts (NO ACTION → SET NULL)
ALTER TABLE elections
  DROP CONSTRAINT elections_created_by_fkey,
  ADD CONSTRAINT elections_created_by_fkey
    FOREIGN KEY (created_by) REFERENCES user_accounts(user_id) ON DELETE SET NULL;

-- 5. invitation_batches → user_accounts (NO ACTION → SET NULL)
ALTER TABLE invitation_batches
  DROP CONSTRAINT invitation_batches_created_by_fkey,
  ADD CONSTRAINT invitation_batches_created_by_fkey
    FOREIGN KEY (created_by) REFERENCES user_accounts(user_id) ON DELETE SET NULL;

-- 6. organization_invites → invitation_batches (NO ACTION → CASCADE)
ALTER TABLE organization_invites
  DROP CONSTRAINT organization_invites_batch_id_fkey,
  ADD CONSTRAINT organization_invites_batch_id_fkey
    FOREIGN KEY (batch_id) REFERENCES invitation_batches(batch_id) ON DELETE CASCADE;

-- 7. organization_invites → user_accounts (NO ACTION → SET NULL)
ALTER TABLE organization_invites
  DROP CONSTRAINT organization_invites_created_by_fkey,
  ADD CONSTRAINT organization_invites_created_by_fkey
    FOREIGN KEY (created_by) REFERENCES user_accounts(user_id) ON DELETE SET NULL;

-- 8. organization_join_requests → user_accounts for approved_by (NO ACTION → SET NULL)
ALTER TABLE organization_join_requests
  DROP CONSTRAINT organization_join_requests_approved_by_fkey,
  ADD CONSTRAINT organization_join_requests_approved_by_fkey
    FOREIGN KEY (approved_by) REFERENCES user_accounts(user_id) ON DELETE SET NULL;

-- 9. organization_join_requests → user_accounts for user_id (NO ACTION → CASCADE)
ALTER TABLE organization_join_requests
  DROP CONSTRAINT organization_join_requests_user_id_fkey,
  ADD CONSTRAINT organization_join_requests_user_id_fkey
    FOREIGN KEY (user_id) REFERENCES user_accounts(user_id) ON DELETE CASCADE;

-- 10. voters → user_accounts for approved_by (NO ACTION → SET NULL)
ALTER TABLE voters
  DROP CONSTRAINT voters_approved_by_fkey,
  ADD CONSTRAINT voters_approved_by_fkey
    FOREIGN KEY (approved_by) REFERENCES user_accounts(user_id) ON DELETE SET NULL;

COMMIT;
