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
 * POST /elections
 * Create a new election (OWNER/ADMIN only)
 * Body: { organization_id, election_name, description? }
 */
router.post("/", authMiddleware, async (req, res, next) => {
    try {
        const userId = req.user!.user_id;
        const { organization_id, election_name, description } = req.body;

        if (!organization_id || !election_name) {
            return res.status(400).json({
                ok: false,
                error: "organization_id and election_name are required",
            });
        }

        const orgId = Number(organization_id);
        if (!Number.isInteger(orgId) || orgId <= 0) {
            return res.status(400).json({
                ok: false,
                error: "organization_id must be a positive integer",
            });
        }

        const electionId = await withTx(req, async (client) => {
            const { rows } = await client.query(
                `SELECT sp_create_election($1, $2, $3, $4) AS election_id`,
                [orgId, election_name, description || null, userId]
            );
            return rows[0].election_id;
        });

        return res.status(201).json({
            ok: true,
            election_id: electionId,
            election_name,
            organization_id: orgId,
        });
    } catch (err: any) {
        if (err.code === "28000") {
            return res.status(403).json({
                ok: false,
                error: "Not authorized to create elections",
            });
        }
        next(err);
    }
});

/**
 * GET /elections?organization_id=1
 * List elections for an organization (members only)
 */
router.get("/", authMiddleware, async (req, res, next) => {
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

        // Check if user is member of org
        const memberCheck = await pool.query(
            `SELECT 1 FROM org_members 
       WHERE organization_id = $1 AND user_id = $2 AND is_active = TRUE`,
            [orgId, userId]
        );

        if (memberCheck.rows.length === 0) {
            return res.status(403).json({
                ok: false,
                error: "Not a member of this organization",
            });
        }

        const { rows } = await pool.query(
            `SELECT * FROM sp_get_elections_by_org($1)`,
            [orgId]
        );

        return res.json({
            ok: true,
            elections: rows,
        });
    } catch (err) {
        next(err);
    }
});

/**
 * GET /elections/:electionId
 * Get full election details including races and candidates
 */
router.get("/:electionId", authMiddleware, async (req, res, next) => {
    try {
        const userId = req.user!.user_id;
        const electionId = parseIntParam(req.params.electionId as string, "electionId");

        // Get election details
        const electionResult = await pool.query(
            `SELECT e.*, o.organization_name
       FROM elections e
       JOIN organizations o ON e.organization_id = o.organization_id
       WHERE e.election_id = $1`,
            [electionId]
        );

        if (electionResult.rows.length === 0) {
            return res.status(404).json({
                ok: false,
                error: "Election not found",
            });
        }

        const election = electionResult.rows[0];

        // Check if user is member of org
        const memberCheck = await pool.query(
            `SELECT 1 FROM org_members 
       WHERE organization_id = $1 AND user_id = $2 AND is_active = TRUE`,
            [election.organization_id, userId]
        );

        if (memberCheck.rows.length === 0) {
            return res.status(403).json({
                ok: false,
                error: "Not authorized to view this election",
            });
        }

        // Get races with candidates
        const racesResult = await pool.query(
            `SELECT 
        er.race_id,
        er.race_name,
        er.description,
        er.max_votes_per_voter
       FROM election_races er
       WHERE er.election_id = $1
       ORDER BY er.race_id`,
            [electionId]
        );

        // Get candidates for each race
        const races = await Promise.all(
            racesResult.rows.map(async (race) => {
                const candidatesResult = await pool.query(
                    `SELECT 
            c.candidate_id,
            c.full_name,
            c.affiliation_name,
            c.bio,
            c.is_approved,
            cr.display_name,
            cr.ballot_order
           FROM candidate_races cr
           JOIN candidates c ON cr.candidate_id = c.candidate_id
           WHERE cr.race_id = $1
           ORDER BY cr.ballot_order NULLS LAST, c.full_name`,
                    [race.race_id]
                );

                return {
                    ...race,
                    candidates: candidatesResult.rows,
                };
            })
        );

        return res.json({
            ok: true,
            election: {
                ...election,
                races,
            },
        });
    } catch (err) {
        next(err);
    }
});

/**
 * PUT /elections/:electionId
 * Update election (DRAFT only, OWNER/ADMIN only)
 * Body: { election_name, description?, start_at?, end_at? }
 */
router.put("/:electionId", authMiddleware, async (req, res, next) => {
    try {
        const userId = req.user!.user_id;
        const electionId = parseIntParam(req.params.electionId as string, "electionId");
        const { election_name, description, start_at, end_at } = req.body;

        if (!election_name) {
            return res.status(400).json({
                ok: false,
                error: "election_name is required",
            });
        }

        await withTx(req, async (client) => {
            await client.query(
                `SELECT sp_update_election($1, $2, $3, $4, $5, $6)`,
                [
                    electionId,
                    election_name,
                    description || null,
                    start_at || null,
                    end_at || null,
                    userId,
                ]
            );
        });

        return res.json({
            ok: true,
            message: "Election updated successfully",
        });
    } catch (err: any) {
        if (err.code === "28000") {
            return res.status(403).json({
                ok: false,
                error: "Not authorized to update election",
            });
        }
        if (err.code === "22023") {
            return res.status(400).json({
                ok: false,
                error: err.message || "Invalid election state or data",
            });
        }
        next(err);
    }
});

/**
 * POST /elections/:electionId/open
 * Open election for voting (OWNER/ADMIN only)
 */
router.post("/:electionId/open", authMiddleware, async (req, res, next) => {
    try {
        const userId = req.user!.user_id;
        const electionId = parseIntParam(req.params.electionId as string, "electionId");

        await withTx(req, async (client) => {
            await client.query(`SELECT sp_open_election($1, $2)`, [
                electionId,
                userId,
            ]);
        });

        return res.json({
            ok: true,
            message: "Election opened successfully",
        });
    } catch (err: any) {
        if (err.code === "28000") {
            return res.status(403).json({
                ok: false,
                error: "Not authorized to open election",
            });
        }
        if (err.code === "22023") {
            return res.status(409).json({
                ok: false,
                error: err.message || "Cannot open election in current state",
            });
        }
        next(err);
    }
});

/**
 * POST /elections/:electionId/schedule
 * Schedule election to open automatically (OWNER/ADMIN only)
 * Body: { start_datetime, end_datetime }
 */
router.post("/:electionId/schedule", authMiddleware, async (req, res, next) => {
    try {
        const userId = req.user!.user_id;
        const electionId = parseIntParam(req.params.electionId as string, "electionId");
        const { start_datetime, end_datetime } = req.body;

        if (!start_datetime || !end_datetime) {
            return res.status(400).json({
                ok: false,
                error: "start_datetime and end_datetime are required",
            });
        }

        await withTx(req, async (client) => {
            await client.query(`SELECT sp_schedule_election($1, $2, $3, $4)`, [
                electionId,
                start_datetime,
                end_datetime,
                userId,
            ]);
        });

        return res.json({
            ok: true,
            message: "Election scheduled successfully",
        });
    } catch (err: any) {
        if (err.code === "28000") {
            return res.status(403).json({
                ok: false,
                error: "Not authorized to schedule election",
            });
        }
        if (err.code === "22023") {
            return res.status(409).json({
                ok: false,
                error: err.message || "Cannot schedule election in current state",
            });
        }
        next(err);
    }
});

/**
 * POST /elections/:electionId/close
 * Close election (OWNER/ADMIN only)
 */
router.post("/:electionId/close", authMiddleware, async (req, res, next) => {
    try {
        const userId = req.user!.user_id;
        const electionId = parseIntParam(req.params.electionId as string, "electionId");

        await withTx(req, async (client) => {
            await client.query(`SELECT sp_close_election($1, $2)`, [
                electionId,
                userId,
            ]);
        });

        return res.json({
            ok: true,
            message: "Election closed successfully",
        });
    } catch (err: any) {
        if (err.code === "28000") {
            return res.status(403).json({
                ok: false,
                error: "Not authorized to close election",
            });
        }
        if (err.code === "22023") {
            return res.status(409).json({
                ok: false,
                error: err.message || "Cannot close election in current state",
            });
        }
        next(err);
    }
});

/**
 * DELETE /elections/:electionId
 * Delete election (OWNER/ADMIN only, cannot delete OPEN elections)
 */
router.delete("/:electionId", authMiddleware, async (req, res, next) => {
    try {
        const userId = req.user!.user_id;
        const electionId = parseIntParam(req.params.electionId as string, "electionId");

        await withTx(req, async (client) => {
            await client.query(`SELECT sp_delete_election($1, $2)`, [
                electionId,
                userId,
            ]);
        });

        return res.json({
            ok: true,
            message: "Election deleted successfully",
        });
    } catch (err: any) {
        if (err.code === "28000") {
            return res.status(403).json({
                ok: false,
                error: "Not authorized to delete election",
            });
        }
        if (err.code === "22023") {
            return res.status(409).json({
                ok: false,
                error: err.message || "Cannot delete election in current state",
            });
        }
        next(err);
    }
});

export default router;
