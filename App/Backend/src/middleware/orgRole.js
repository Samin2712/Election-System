import { q } from "../db.js";

export function requireOrgAdmin() {
  return async (req, res, next) => {
    const orgId = req.params.orgId || req.body.orgId;
    if (!orgId) return res.status(400).json({ error: "orgId required" });

    const r = await q(
      `SELECT role FROM org_user_role WHERE org_id=$1 AND user_id=$2`,
      [orgId, req.user.user_id]
    );

    if (r.rowCount === 0 || r.rows[0].role !== "ORG_ADMIN") {
      return res.status(403).json({ error: "ORG_ADMIN required" });
    }
    next();
  };
}
