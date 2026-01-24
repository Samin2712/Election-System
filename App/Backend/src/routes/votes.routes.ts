import express from "express";
import { withTx } from "../tx";
import { authMiddleware } from "../middleware/auth";

const router = express.Router();

router.post("/", authMiddleware, async (req, res, next) => {
  try {
    const userId = req.user!.user_id; // From authenticated JWT token
    const { race_id, candidate_race_id, channel } = req.body;

    const voteId = await withTx(req, async (client) => {
      const { rows } = await client.query(
        "select sp_cast_vote($1,$2,$3,$4) as vote_id",
        [userId, race_id, candidate_race_id, channel || "WEB"]
      );
      return rows[0].vote_id;
    });

    res.json({ ok: true, vote_id: voteId });
  } catch (e) {
    console.log("Error in /votes:", e);
    next(e);
  }
});

export default router;
