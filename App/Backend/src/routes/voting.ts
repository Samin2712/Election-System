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
 * POST /voting/register
 * Register current user as voter in organization
 * Body: { organization_id }
 */
router.post("/register", authMiddleware, async (req, res, next) => {
    try {
        const userId = req.user!.user_id;
        const { organization_id } = req.body;

        if (!organization_id) {
            return res.status(400).json({
                ok: false,
                error: "organization_id is required",
            });
        }

        const orgId = Number(organization_id);
        if (!Number.isInteger(orgId) || orgId <= 0) {
            return res.status(400).json({
                ok: false,
                error: "organization_id must be a positive integer",
            });
        }

        await withTx(req, async (client) => {
            await client.query(`SELECT sp_register_voter($1, $2)`, [orgId, userId]);
        });

        return res.status(201).json({
            ok: true,
            message: "Voter registration submitted for approval",
        });
    } catch (err: any) {
        if (err.code === "22023") {
            return res.status(400).json({
                ok: false,
                error: err.message || "Invalid voter registration",
            });
        }
        if (err.code === "23505") {
            return res.status(409).json({
                ok: false,
                error: "Already registered as voter in this organization",
            });
        }
        next(err);
    }
});

/**
 * POST /voting/approve
 * Approve a voter registration (OWNER/ADMIN only)
 * Body: { organization_id, user_id }
 */
router.post("/approve", authMiddleware, async (req, res, next) => {
    try {
        const approverId = req.user!.user_id;
        const { organization_id, user_id } = req.body;

        if (!organization_id || !user_id) {
            return res.status(400).json({
                ok: false,
                error: "organization_id and user_id are required",
            });
        }

        const orgId = Number(organization_id);
        const voterId = Number(user_id);

        if (!Number.isInteger(orgId) || orgId <= 0) {
            return res.status(400).json({
                ok: false,
                error: "organization_id must be a positive integer",
            });
        }

        if (!Number.isInteger(voterId) || voterId <= 0) {
            return res.status(400).json({
                ok: false,
                error: "user_id must be a positive integer",
            });
        }

        await withTx(req, async (client) => {
            await client.query(`SELECT sp_approve_voter($1, $2, $3)`, [
                orgId,
                voterId,
                approverId,
            ]);
        });

        return res.json({
            ok: true,
            message: "Voter approved successfully",
        });
    } catch (err: any) {
        if (err.code === "28000") {
            return res.status(403).json({
                ok: false,
                error: "Not authorized to approve voters",
            });
        }
        if (err.code === "22023") {
            return res.status(404).json({
                ok: false,
                error: err.message || "Voter registration not found",
            });
        }
        next(err);
    }
});

/**
 * POST /voting/cast
 * Cast a vote in an election
 * Body: { election_id, race_id, candidate_id }
 */
router.post("/cast", authMiddleware, async (req, res, next) => {
    try {
        const userId = req.user!.user_id;
        const { election_id, race_id, candidate_id } = req.body;

        if (!election_id || !race_id || !candidate_id) {
            return res.status(400).json({
                ok: false,
                error: "election_id, race_id, and candidate_id are required",
            });
        }

        const electionId = Number(election_id);
        const raceId = Number(race_id);
        const candidateId = Number(candidate_id);

        if (
            !Number.isInteger(electionId) ||
            electionId <= 0 ||
            !Number.isInteger(raceId) ||
            raceId <= 0 ||
            !Number.isInteger(candidateId) ||
            candidateId <= 0
        ) {
            return res.status(400).json({
                ok: false,
                error: "All IDs must be positive integers",
            });
        }

        const voteId = await withTx(req, async (client) => {
            const { rows } = await client.query(
                `SELECT sp_cast_vote($1, $2, $3, $4) AS vote_id`,
                [electionId, raceId, candidateId, userId]
            );
            return rows[0].vote_id;
        });

        return res.status(201).json({
            ok: true,
            vote_id: voteId,
            message: "Vote cast successfully",
        });
    } catch (err: any) {
        if (err.code === "28000") {
            return res.status(403).json({
                ok: false,
                error: "Not authorized to vote (voter not approved)",
            });
        }
        if (err.code === "22023") {
            return res.status(400).json({
                ok: false,
                error: err.message || "Invalid vote data",
            });
        }
        if (err.code === "23505") {
            return res.status(409).json({
                ok: false,
                error: err.message || "Already voted for this candidate or maximum votes reached",
            });
        }
        next(err);
    }
});

/**
 * GET /voting/results?election_id=1&race_id=1
 * Get results for a specific race
 */
router.get("/results", authMiddleware, async (req, res, next) => {
    try {
        const userId = req.user!.user_id;
        const electionIdParam = req.query.election_id as string;
        const raceIdParam = req.query.race_id as string;

        if (!electionIdParam || !raceIdParam) {
            return res.status(400).json({
                ok: false,
                error: "election_id and race_id query parameters are required",
            });
        }

        const electionId = parseIntParam(electionIdParam, "election_id");
        const raceId = parseIntParam(raceIdParam, "race_id");

        // Verify race belongs to election
        const raceCheck = await pool.query(
            `SELECT er.race_id, er.race_name, e.organization_id, e.status
       FROM election_races er
       JOIN elections e ON er.election_id = e.election_id
       WHERE er.race_id = $1 AND er.election_id = $2`,
            [raceId, electionId]
        );

        if (raceCheck.rows.length === 0) {
            return res.status(404).json({
                ok: false,
                error: "Race not found in this election",
            });
        }

        const race = raceCheck.rows[0];

        // Check if user is member of org
        const memberCheck = await pool.query(
            `SELECT 1 FROM org_members 
       WHERE organization_id = $1 AND user_id = $2 AND is_active = TRUE`,
            [race.organization_id, userId]
        );

        if (memberCheck.rows.length === 0) {
            return res.status(403).json({
                ok: false,
                error: "Not authorized to view results",
            });
        }

        // Get results
        const { rows } = await pool.query(
            `SELECT * FROM sp_get_race_results($1, $2)`,
            [electionId, raceId]
        );

        return res.json({
            ok: true,
            election_id: electionId,
            race_id: raceId,
            race_name: race.race_name,
            election_status: race.status,
            results: rows,
        });
    } catch (err) {
        next(err);
    }
});

/**
 * GET /voting/status?organization_id=1
 * Get current user's voter status in an organization
 */
router.get("/status", authMiddleware, async (req, res, next) => {
    try {
        const userId = req.user!.user_id;
        const orgIdParam = req.query.organization_id as string;

        if (!orgIdParam) {
            return res.status(400).json({
                ok: false,
                error: "organization_id query parameter is required",
            });
        }

        const orgId = parseIntParam(orgIdParam, "organization_id");

        const { rows } = await pool.query(
            `SELECT * FROM sp_get_voter_status($1, $2)`,
            [orgId, userId]
        );

        if (rows.length === 0) {
            return res.json({
                ok: true,
                registered: false,
                message: "Not registered as voter in this organization",
            });
        }

        return res.json({
            ok: true,
            registered: true,
            voter: rows[0],
        });
    } catch (err) {
        next(err);
    }
});

/**
 * GET /voting/pending?organization_id=1
 * List pending voter registrations (OWNER/ADMIN only)
 */
router.get("/pending", authMiddleware, async (req, res, next) => {
    try {
        const userId = req.user!.user_id;
        const orgIdParam = req.query.organization_id as string;

        if (!orgIdParam) {
            return res.status(400).json({
                ok: false,
                error: "organization_id query parameter is required",
            });
        }

        const orgId = parseIntParam(orgIdParam, "organization_id");

        // Check if user is OWNER/ADMIN
        const adminCheck = await pool.query(
            `SELECT 1 FROM org_members 
       WHERE organization_id = $1 
         AND user_id = $2 
         AND is_active = TRUE 
         AND role_name IN ('OWNER', 'ADMIN')`,
            [orgId, userId]
        );

        if (adminCheck.rows.length === 0) {
            return res.status(403).json({
                ok: false,
                error: "Not authorized to view pending voters",
            });
        }

        const { rows } = await pool.query(
            `SELECT * FROM sp_list_pending_voters($1)`,
            [orgId]
        );

        return res.json({
            ok: true,
            pending_voters: rows,
        });
    } catch (err) {
        next(err);
    }
});

/**
 * GET /voting/election-results/:electionId
 * Get results for all races in an election
 */
router.get("/election-results/:electionId", authMiddleware, async (req, res, next) => {
    try {
        const userId = req.user!.user_id;
        const electionId = parseIntParam(req.params.electionId as string, "electionId");

        // Get election details and verify access
        const electionCheck = await pool.query(
            `SELECT e.election_id, e.election_name, e.organization_id, e.status, e.description
       FROM elections e
       WHERE e.election_id = $1`,
            [electionId]
        );

        if (electionCheck.rows.length === 0) {
            return res.status(404).json({
                ok: false,
                error: "Election not found",
            });
        }

        const election = electionCheck.rows[0];

        // Check if user is member of org
        const memberCheck = await pool.query(
            `SELECT 1 FROM org_members 
       WHERE organization_id = $1 AND user_id = $2 AND is_active = TRUE`,
            [election.organization_id, userId]
        );

        if (memberCheck.rows.length === 0) {
            return res.status(403).json({
                ok: false,
                error: "Not authorized to view results",
            });
        }

        // Get all races for this election
        const racesResult = await pool.query(
            `SELECT race_id, race_name, description, max_votes_per_voter, max_winners
       FROM election_races
       WHERE election_id = $1
       ORDER BY race_id`,
            [electionId]
        );

        // Get results for each race
        const racesWithResults = await Promise.all(
            racesResult.rows.map(async (race) => {
                const resultsQuery = await pool.query(
                    `SELECT * FROM sp_get_race_results($1, $2)`,
                    [electionId, race.race_id]
                );

                return {
                    ...race,
                    results: resultsQuery.rows,
                    total_votes: resultsQuery.rows.reduce((sum: number, r: any) => sum + parseInt(r.vote_count), 0)
                };
            })
        );

        return res.json({
            ok: true,
            election: {
                election_id: election.election_id,
                election_name: election.election_name,
                description: election.description,
                status: election.status
            },
            races: racesWithResults,
        });
    } catch (err) {
        next(err);
    }
});

export default router;
