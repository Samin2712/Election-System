CREATE INDEX idx_votes_candidate_race ON public.votes USING btree (candidate_race_id);
