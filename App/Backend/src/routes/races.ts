import { Router } from "express";
import { pool } from "../db";
import { authMiddleware } from "../middleware/auth";
import { withTx } from "../tx";

const router = Router();

// Helper to parse integer parameters
function parseIntParam(value: string, name: string): number {
    const n = Number(value);
    if (!Number.isInteger(n) || n <= 0) {
        const err: any = new Error(`Invalid ${name}`);
        err.status = 400;
        throw err;
    }
    return n;
}

/**
 * POST /races
 * Create a new race for an election
 * Body: { election_id, race_name, description?, max_votes_per_voter? }
 */
router.post("/", authMiddleware, async (req, res, next) => {
    try {
        const userId = req.user!.user_id;
        const { election_id, race_name, description, max_votes_per_voter } = req.body;

        if (!election_id || !race_name) {
            return res.status(400).json({
                ok: false,
                error: "election_id and race_name are required",
            });
        }

        const electionId = Number(election_id);
        const maxVotes = Number(max_votes_per_voter) || 1;

        if (!Number.isInteger(electionId) || electionId <= 0) {
            return res.status(400).json({
                ok: false,
                error: "election_id must be a positive integer",
            });
        }

        const raceId = await withTx(req, async (client) => {
            const { rows } = await client.query(
                `SELECT sp_create_race($1, $2, $3, $4, $5) AS race_id`,
                [electionId, race_name, description || null, maxVotes, userId]
            );
            return rows[0].race_id;
        });

        return res.status(201).json({
            ok: true,
            race_id: raceId,
            race_name,
            election_id: electionId,
        });
    } catch (err: any) {
        if (err.code === "28000") {
            return res.status(403).json({
                ok: false,
                error: "Not authorized to create races",
            });
        }
        if (err.code === "22023") {
            return res.status(400).json({
                ok: false,
                error: err.message || "Invalid race data",
            });
        }
        if (err.code === "23505") {
            return res.status(409).json({
                ok: false,
                error: "Race name already exists for this election",
            });
        }
        next(err);
    }
});

/**
 * GET /races/election/:electionId
 * Get all races for an election
 */
router.get("/election/:electionId", authMiddleware, async (req, res, next) => {
    try {
        const electionId = parseIntParam(req.params.electionId as string, "electionId");

        const { rows: races } = await pool.query(
            `SELECT * FROM sp_get_races_for_election($1)`,
            [electionId]
        );

        // Fetch candidates for each race
        const racesWithCandidates = await Promise.all(races.map(async (race) => {
            const { rows: candidates } = await pool.query(
                `SELECT * FROM sp_get_candidates_for_race($1)`,
                [race.race_id]
            );
            return {
                ...race,
                candidates
            };
        }));

        return res.json({
            ok: true,
            races: racesWithCandidates,
        });
    } catch (err) {
        next(err);
    }
});

/**
 * GET /races/:raceId
 * Get race details with candidates
 */
router.get("/:raceId", authMiddleware, async (req, res, next) => {
    try {
        const raceId = parseIntParam(req.params.raceId as string, "raceId");

        // Get race details
        const raceResult = await pool.query(
            `SELECT er.*, e.election_id, e.election_name, e.organization_id
       FROM election_races er
       JOIN elections e ON er.election_id = e.election_id
       WHERE er.race_id = $1`,
            [raceId]
        );

        if (raceResult.rows.length === 0) {
            return res.status(404).json({
                ok: false,
                error: "Race not found",
            });
        }

        const race = raceResult.rows[0];

        // Get candidates
        const { rows: candidates } = await pool.query(
            `SELECT * FROM sp_get_candidates_for_race($1)`,
            [raceId]
        );

        return res.json({
            ok: true,
            race: {
                ...race,
                candidates,
            },
        });
    } catch (err) {
        next(err);
    }
});

/**
 * PUT /races/:raceId
 * Update race details
 * Body: { race_name, description?, max_votes_per_voter? }
 */
router.put("/:raceId", authMiddleware, async (req, res, next) => {
    try {
        const userId = req.user!.user_id;
        const raceId = parseIntParam(req.params.raceId as string, "raceId");
        const { race_name, description, max_votes_per_voter } = req.body;

        if (!race_name) {
            return res.status(400).json({
                ok: false,
                error: "race_name is required",
            });
        }

        const maxVotes = Number(max_votes_per_voter) || 1;

        await withTx(req, async (client) => {
            await client.query(
                `SELECT sp_update_race($1, $2, $3, $4, $5)`,
                [raceId, race_name, description || null, maxVotes, userId]
            );
        });

        return res.json({
            ok: true,
            message: "Race updated successfully",
        });
    } catch (err: any) {
        if (err.code === "28000") {
            return res.status(403).json({
                ok: false,
                error: "Not authorized to update race",
            });
        }
        if (err.code === "22023") {
            return res.status(400).json({
                ok: false,
                error: err.message || "Invalid race data",
            });
        }
        next(err);
    }
});

/**
 * DELETE /races/:raceId
 * Delete a race (DRAFT elections only)
 */
router.delete("/:raceId", authMiddleware, async (req, res, next) => {
    try {
        const userId = req.user!.user_id;
        const raceId = parseIntParam(req.params.raceId as string, "raceId");

        await withTx(req, async (client) => {
            await client.query(`SELECT sp_delete_race($1, $2)`, [raceId, userId]);
        });

        return res.json({
            ok: true,
            message: "Race deleted successfully",
        });
    } catch (err: any) {
        if (err.code === "28000") {
            return res.status(403).json({
                ok: false,
                error: "Not authorized to delete race",
            });
        }
        if (err.code === "22023") {
            return res.status(400).json({
                ok: false,
                error: err.message || "Cannot delete race",
            });
        }
        next(err);
    }
});

/**
 * POST /races/:raceId/candidates
 * Add a candidate to a race
 * Body: { full_name, affiliation_name?, bio?, manifesto?, ballot_order? }
 */
router.post("/:raceId/candidates", authMiddleware, async (req, res, next) => {
    try {
        const userId = req.user!.user_id;
        const raceId = parseIntParam(req.params.raceId as string, "raceId");
        const { full_name, affiliation_name, bio, manifesto, ballot_order } = req.body;

        if (!full_name) {
            return res.status(400).json({
                ok: false,
                error: "full_name is required",
            });
        }

        const candidateId = await withTx(req, async (client) => {
            const { rows } = await client.query(
                `SELECT sp_add_candidate_to_race($1, $2, $3, $4, $5, $6, $7) AS candidate_id`,
                [
                    raceId,
                    full_name,
                    affiliation_name || null,
                    bio || null,
                    manifesto || null,
                    ballot_order || null,
                    userId,
                ]
            );
            return rows[0].candidate_id;
        });

        return res.status(201).json({
            ok: true,
            candidate_id: candidateId,
            full_name,
            race_id: raceId,
        });
    } catch (err: any) {
        if (err.code === "28000") {
            return res.status(403).json({
                ok: false,
                error: "Not authorized to add candidates",
            });
        }
        if (err.code === "22023") {
            return res.status(400).json({
                ok: false,
                error: err.message || "Invalid candidate data",
            });
        }
        if (err.code === "23505") {
            return res.status(409).json({
                ok: false,
                error: "Candidate already exists in this race",
            });
        }
        next(err);
    }
});

/**
 * PUT /races/:raceId/candidates/:candidateId
 * Update candidate details
 * Body: { full_name, affiliation_name?, bio?, manifesto? }
 */
router.put("/:raceId/candidates/:candidateId", authMiddleware, async (req, res, next) => {
    try {
        const userId = req.user!.user_id;
        const candidateId = parseIntParam(req.params.candidateId as string, "candidateId");
        const { full_name, affiliation_name, bio, manifesto } = req.body;

        if (!full_name) {
            return res.status(400).json({
                ok: false,
                error: "full_name is required",
            });
        }

        await withTx(req, async (client) => {
            await client.query(
                `SELECT sp_update_candidate($1, $2, $3, $4, $5, $6)`,
                [
                    candidateId,
                    full_name,
                    affiliation_name || null,
                    bio || null,
                    manifesto || null,
                    userId,
                ]
            );
        });

        return res.json({
            ok: true,
            message: "Candidate updated successfully",
        });
    } catch (err: any) {
        if (err.code === "28000") {
            return res.status(403).json({
                ok: false,
                error: "Not authorized to update candidate",
            });
        }
        if (err.code === "22023") {
            return res.status(404).json({
                ok: false,
                error: "Candidate not found",
            });
        }
        next(err);
    }
});

/**
 * DELETE /races/:raceId/candidates/:candidateId
 * Remove candidate from race
 */
router.delete("/:raceId/candidates/:candidateId", authMiddleware, async (req, res, next) => {
    try {
        const userId = req.user!.user_id;
        const raceId = parseIntParam(req.params.raceId as string, "raceId");
        const candidateId = parseIntParam(req.params.candidateId as string, "candidateId");

        await withTx(req, async (client) => {
            await client.query(
                `SELECT sp_remove_candidate_from_race($1, $2, $3)`,
                [raceId, candidateId, userId]
            );
        });

        return res.json({
            ok: true,
            message: "Candidate removed from race successfully",
        });
    } catch (err: any) {
        if (err.code === "28000") {
            return res.status(403).json({
                ok: false,
                error: "Not authorized to remove candidate",
            });
        }
        if (err.code === "22023") {
            return res.status(400).json({
                ok: false,
                error: err.message || "Cannot remove candidate",
            });
        }
        next(err);
    }
});

export default router;
