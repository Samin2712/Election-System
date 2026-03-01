import { Request, Response, NextFunction } from "express";
import { pool } from "../db";

/**
 * Middleware that checks if the authenticated user is the super admin.
 * Super admin is identified by a hardcoded email in SUPER_ADMIN_EMAIL env var.
 * Must be used AFTER authMiddleware.
 */
export async function superAdminMiddleware(req: Request, res: Response, next: NextFunction) {
  try {
    const userId = req.user?.user_id;
    if (!userId) {
      return res.status(401).json({ ok: false, error: "Not authenticated" });
    }

    const superAdminEmail = process.env.SUPER_ADMIN_EMAIL;
    if (!superAdminEmail) {
      return res.status(500).json({ ok: false, error: "Super admin not configured" });
    }

    const { rows } = await pool.query(
      "SELECT email FROM user_accounts WHERE user_id = $1",
      [userId]
    );

    if (rows.length === 0 || rows[0].email.toLowerCase() !== superAdminEmail.toLowerCase()) {
      return res.status(403).json({ ok: false, error: "Super admin access required" });
    }

    next();
  } catch (err) {
    return res.status(500).json({ ok: false, error: "Authorization check failed" });
  }
}

/**
 * Helper: check if a user_id is the super admin (for use in non-middleware contexts)
 */
export async function isSuperAdmin(userId: number): Promise<boolean> {
  const superAdminEmail = process.env.SUPER_ADMIN_EMAIL;
  if (!superAdminEmail) return false;

  const { rows } = await pool.query(
    "SELECT email FROM user_accounts WHERE user_id = $1",
    [userId]
  );

  return rows.length > 0 && rows[0].email.toLowerCase() === superAdminEmail.toLowerCase();
}
