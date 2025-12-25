console.log("✅ auth.routes.ts loaded");


import express from "express";
import bcrypt from "bcryptjs";
import { pool } from "../db";
import { signAccessToken, signRefreshToken, verifyRefreshToken } from "../utils/jwt";

const router = express.Router();

/**
 * POST /auth/register
 * body: { username, email, password }
 */
router.post("/register", async (req, res, next) => {
  try {
    const { username, email, password } = req.body ?? {};

    if (!username || !email || !password) {
      return res.status(400).json({ ok: false, error: "username, email, password are required" });
    }
    if (String(password).length < 6) {
      return res.status(400).json({ ok: false, error: "password must be at least 6 characters" });
    }

    const passwordHash = await bcrypt.hash(String(password), 10);

    const { rows } = await pool.query(
      "select sp_register_user($1,$2,$3,$4) as user_id",
      [String(username), String(email), passwordHash, "USER"]
    );

    const user_id = Number(rows[0].user_id);

    // fetch role_id
    const r2 = await pool.query("select role_id from user_accounts where user_id=$1", [user_id]);
    const role_id = Number(r2.rows[0].role_id);

    const accessToken = signAccessToken({ user_id, role_id });
    const refreshToken = signRefreshToken({ user_id, role_id });

    return res.json({ ok: true, user_id, accessToken, refreshToken });
  } catch (err: any) {
    // Unique violation (email/username already exists)
    if (err?.code === "23505") {
      return res.status(409).json({ ok: false, error: "username or email already exists" });
    }
    next(err);
  }
});

/**
 * POST /auth/login
 * body: { email, password }
 */
router.post("/login", async (req, res, next) => {
  try {
    const { email, password } = req.body ?? {};
    if (!email || !password) {
      return res.status(400).json({ ok: false, error: "email and password are required" });
    }

    const { rows } = await pool.query("select * from sp_get_user_for_login($1)", [String(email)]);
    if (rows.length === 0) {
      return res.status(401).json({ ok: false, error: "invalid credentials" });
    }

    const u = rows[0];
    if (!u.is_active) {
      return res.status(403).json({ ok: false, error: "account is inactive" });
    }

    const ok = await bcrypt.compare(String(password), String(u.password_hash));
    if (!ok) {
      return res.status(401).json({ ok: false, error: "invalid credentials" });
    }

    const user_id = Number(u.user_id);
    const role_id = Number(u.role_id);

    const accessToken = signAccessToken({ user_id, role_id });
    const refreshToken = signRefreshToken({ user_id, role_id });

    return res.json({ ok: true, accessToken, refreshToken, user_id, role_id });
  } catch (err) {
    next(err);
  }
});

/**
 * POST /auth/refresh
 * body: { refreshToken }
 */
router.post("/refresh", async (req, res, next) => {
  try {
    const { refreshToken } = req.body ?? {};
    if (!refreshToken) {
      return res.status(400).json({ ok: false, error: "refreshToken is required" });
    }

    const verified = verifyRefreshToken(String(refreshToken));
    
    const accessToken = signAccessToken({ 
      user_id: verified.user_id, 
      role_id: verified.role_id 
    });

    return res.json({ ok: true, accessToken });
  } catch (err) {
    return res.status(401).json({ ok: false, error: "Invalid refresh token" });
  }
});

export default router;
