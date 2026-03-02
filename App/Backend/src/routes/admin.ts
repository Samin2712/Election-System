import { Router } from "express";
import { pool } from "../db";
import { authMiddleware } from "../middleware/auth";
import { superAdminMiddleware, isSuperAdmin } from "../middleware/superAdmin";
import { withTx } from "../tx";
import { proofDocumentUpload } from "../upload";

const router = Router();

// ============================================================
// USER-FACING: Organization request endpoints
// ============================================================

/**
 * POST /admin/org-requests
 * Submit a request to create an organization (with optional proof document)
 * Body (multipart/form-data): { organization_name, organization_type, organization_code, purpose?, expected_members?, proof_document? }
 */
router.post(
  "/org-requests",
  authMiddleware,
  proofDocumentUpload.single("proof_document"),
  async (req, res, next) => {
    try {
      const userId = req.user!.user_id;
      const {
        organization_name,
        organization_type,
        organization_code,
        purpose,
        expected_members,
      } = req.body;

      if (!organization_name || !organization_type || !organization_code) {
        return res.status(400).json({
          ok: false,
          error:
            "organization_name, organization_type, and organization_code are required",
        });
      }

      const proofUrl = req.file
        ? `proofs/${req.file.filename}`
        : null;

      const requestId = await withTx(req, async (client) => {
        const { rows } = await client.query(
          `SELECT sp_submit_org_request($1, $2, $3, $4, $5, $6, $7) AS request_id`,
          [
            userId,
            organization_name,
            organization_type,
            organization_code,
            purpose || null,
            expected_members ? Number(expected_members) : null,
            proofUrl,
          ]
        );
        return rows[0].request_id;
      });

      return res.status(201).json({
        ok: true,
        request_id: requestId,
        message:
          "Organization request submitted. A super admin will review it shortly.",
      });
    } catch (err: any) {
      if (err.code === "23505") {
        return res.status(409).json({
          ok: false,
          error:
            err.message || "Organization code already exists or duplicate request",
        });
      }
      next(err);
    }
  }
);

/**
 * GET /admin/org-requests/my
 * Get current user's own organization requests
 */
router.get("/org-requests/my", authMiddleware, async (req, res, next) => {
  try {
    const userId = req.user!.user_id;
    const { rows } = await pool.query(
      `SELECT * FROM sp_get_my_org_requests($1)`,
      [userId]
    );
    return res.json({ ok: true, requests: rows });
  } catch (err) {
    next(err);
  }
});

// ============================================================
// SUPER ADMIN: Review endpoints
// ============================================================

/**
 * GET /admin/org-requests
 * List all organization requests (filterable by status)
 * Query: ?status=PENDING|APPROVED|REJECTED  (optional)
 */
router.get(
  "/org-requests",
  authMiddleware,
  superAdminMiddleware,
  async (req, res, next) => {
    try {
      const status = req.query.status as string | undefined;
      const validStatuses = ["PENDING", "APPROVED", "REJECTED"];
      const statusParam =
        status && validStatuses.includes(status.toUpperCase())
          ? status.toUpperCase()
          : null;

      const { rows } = await pool.query(
        `SELECT * FROM sp_get_org_requests($1::org_request_status)`,
        [statusParam]
      );

      return res.json({ ok: true, requests: rows });
    } catch (err) {
      next(err);
    }
  }
);

/**
 * POST /admin/org-requests/:requestId/approve
 * Approve an organization request (super admin only)
 * Body: { admin_notes? }
 */
router.post(
  "/org-requests/:requestId/approve",
  authMiddleware,
  superAdminMiddleware,
  async (req, res, next) => {
    try {
      const adminUserId = req.user!.user_id;
      const requestId = Number(req.params.requestId);
      const { admin_notes } = req.body;

      if (!Number.isInteger(requestId) || requestId <= 0) {
        return res
          .status(400)
          .json({ ok: false, error: "Invalid request ID" });
      }

      const orgId = await withTx(req, async (client) => {
        const { rows } = await client.query(
          `SELECT sp_approve_org_request($1, $2, $3) AS org_id`,
          [requestId, adminUserId, admin_notes || null]
        );
        return rows[0].org_id;
      });

      return res.json({
        ok: true,
        organization_id: orgId,
        message: "Organization request approved. Organization has been created.",
      });
    } catch (err: any) {
      if (err.code === "22023") {
        return res.status(400).json({
          ok: false,
          error: err.message || "Invalid request",
        });
      }
      next(err);
    }
  }
);

/**
 * POST /admin/org-requests/:requestId/reject
 * Reject an organization request (super admin only)
 * Body: { admin_notes? }
 */
router.post(
  "/org-requests/:requestId/reject",
  authMiddleware,
  superAdminMiddleware,
  async (req, res, next) => {
    try {
      const adminUserId = req.user!.user_id;
      const requestId = Number(req.params.requestId);
      const { admin_notes } = req.body;

      if (!Number.isInteger(requestId) || requestId <= 0) {
        return res
          .status(400)
          .json({ ok: false, error: "Invalid request ID" });
      }

      await withTx(req, async (client) => {
        await client.query(
          `SELECT sp_reject_org_request($1, $2, $3)`,
          [requestId, adminUserId, admin_notes || null]
        );
      });

      return res.json({
        ok: true,
        message: "Organization request rejected.",
      });
    } catch (err: any) {
      if (err.code === "22023") {
        return res.status(400).json({
          ok: false,
          error: err.message || "Invalid request",
        });
      }
      next(err);
    }
  }
);

/**
 * GET /admin/check
 * Check if current user is super admin
 */
router.get("/check", authMiddleware, async (req, res, next) => {
  try {
    const userId = req.user!.user_id;
    const isAdmin = await isSuperAdmin(userId);
    return res.json({ ok: true, is_super_admin: isAdmin });
  } catch (err) {
    next(err);
  }
});

/**
 * POST /admin/org-create
 * Super admin directly creates an organization (skips request flow)
 * Body: { organization_name, organization_type, organization_code }
 */
router.post(
  "/org-create",
  authMiddleware,
  superAdminMiddleware,
  async (req, res, next) => {
    try {
      const userId = req.user!.user_id;
      const { organization_name, organization_type, organization_code } =
        req.body;

      if (!organization_name || !organization_type || !organization_code) {
        return res.status(400).json({
          ok: false,
          error:
            "organization_name, organization_type, and organization_code are required",
        });
      }

      const orgId = await withTx(req, async (client) => {
        const { rows } = await client.query(
          `SELECT sp_create_organization($1, $2, $3, $4) AS org_id`,
          [organization_name, organization_type, organization_code, userId]
        );
        return rows[0].org_id;
      });

      return res.status(201).json({
        ok: true,
        organization_id: orgId,
        organization_name,
        organization_type,
        organization_code,
      });
    } catch (err: any) {
      if (err.code === "23505") {
        return res
          .status(409)
          .json({ ok: false, error: "organization_code already exists" });
      }
      next(err);
    }
  }
);

// ============================================================
// SUPER ADMIN: Platform Statistics
// ============================================================

/**
 * GET /admin/stats
 * Returns platform-wide statistics for the super admin dashboard
 */
router.get(
  "/stats",
  authMiddleware,
  superAdminMiddleware,
  async (_req, res, next) => {
    try {
      // Run all stat queries in parallel
      const [
        usersResult,
        orgsResult,
        electionsResult,
        votesResult,
        pendingRequestsResult,
        recentUsersResult,
        orgListResult,
      ] = await Promise.all([
        pool.query(`SELECT COUNT(*) AS count FROM user_accounts`),
        pool.query(`SELECT COUNT(*) AS count FROM organizations`),
        pool.query(`SELECT COUNT(*) AS count FROM elections`),
        pool.query(`SELECT COUNT(*) AS count FROM votes`),
        pool.query(
          `SELECT COUNT(*) AS count FROM organization_requests WHERE status = 'PENDING'`
        ),
        pool.query(
          `SELECT user_id, username, email, created_at
           FROM user_accounts
           ORDER BY created_at DESC
           LIMIT 10`
        ),
        pool.query(
          `SELECT o.organization_id, o.organization_name, o.organization_type, o.organization_code, o.created_at,
                  (SELECT COUNT(*) FROM organization_members om WHERE om.organization_id = o.organization_id) AS member_count,
                  (SELECT COUNT(*) FROM elections e WHERE e.organization_id = o.organization_id) AS election_count
           FROM organizations o
           ORDER BY o.created_at DESC`
        ),
      ]);

      return res.json({
        ok: true,
        stats: {
          total_users: parseInt(usersResult.rows[0].count),
          total_organizations: parseInt(orgsResult.rows[0].count),
          total_elections: parseInt(electionsResult.rows[0].count),
          total_votes: parseInt(votesResult.rows[0].count),
          pending_requests: parseInt(pendingRequestsResult.rows[0].count),
        },
        recent_users: recentUsersResult.rows,
        organizations: orgListResult.rows,
      });
    } catch (err) {
      next(err);
    }
  }
);

export default router;
