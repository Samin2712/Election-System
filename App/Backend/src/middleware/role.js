import { q } from "../db.js";

export function requireOrganizerOrSuper() {
  return async (req, res, next) => {
    const r = await q(`SELECT role FROM app_user WHERE user_id=$1`, [req.user.user_id]);
    const role = r.rows[0]?.role;
    if (role === "SUPER_ADMIN" || role === "ORGANIZER") return next();
    return res.status(403).json({ error: "ORGANIZER required" });
  };
}
