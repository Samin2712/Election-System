// backend/src/routes/invite.routes.js (FULL UPDATED - fixes voting gap by inserting into voter table)

import express from "express";
import crypto from "crypto";
import { auth } from "../middleware/auth.js";
import { requireOrganizerOrSuper } from "../middleware/role.js";
import { q } from "../db.js";
import { callProc } from "../sql.js";
import { makeTransport } from "../utils/mailer.js";

const router = express.Router();

/**
 * Organizer creates invite + sends email secret
 * body: { org_id, election_id, email }
 */
router.post("/create", auth, requireOrganizerOrSuper(), async (req, res) => {
  let { org_id, election_id, email } = req.body;
  if (!org_id || !election_id || !email) {
    return res.status(400).json({ error: "Missing fields" });
  }

  email = String(email).trim().toLowerCase();
  const secret = crypto.randomBytes(4).toString("hex");

  try {
    await callProc("create_election_invite", [
      req.user.user_id,
      org_id,
      election_id,
      email,
      secret,
    ]);

    // email send (if SMTP is configured)
    try {
      const t = makeTransport();
      await t.sendMail({
        from: process.env.SMTP_USER,
        to: email,
        subject: `Election Invitation`,
        text:
`Election ID: ${election_id}
Your ONE-TIME secret code: ${secret}

Rules:
- Code works ONE TIME only
- Expires in 3 days

Steps:
1) Login to the app
2) All Elections -> Submit Secret Code
3) Wait for organizer approval
4) Vote when election is OPEN.`,
      });
    } catch (mailErr) {
      console.warn("Email not sent (SMTP missing):", mailErr.message);
    }

    res.json({ ok: true, message: "Invite created (email sent if SMTP configured)" });
  } catch (e) {
    return res.status(400).json({ error: e.message });
  }
});

/**
 * Voter uses secret to create access request (consumes secret once)
 * body: { election_id, email, secret }
 */
router.post("/use", auth, async (req, res) => {
  let { election_id, email, secret } = req.body;
  if (!election_id || !email || !secret) {
    return res.status(400).json({ error: "Missing fields" });
  }

  email = String(email).trim().toLowerCase();
  secret = String(secret).trim();

  try {
    await callProc("consume_invite_and_request_access", [
      req.user.user_id,
      email,
      election_id,
      secret,
    ]);

    res.json({ ok: true, message: "Request submitted. Wait organizer approval." });
  } catch (e) {
    return res.status(400).json({ error: e.message });
  }
});

/**
 * Organizer views requests (pending + approved + rejected)
 * ✅ returns approved + status so frontend never shows undefined
 */
router.get("/pending/:electionId", auth, requireOrganizerOrSuper(), async (req, res) => {
  try {
    const r = await q(
      `SELECT 
          ea.access_id,
          ea.user_id,
          ea.requested_at,
          ea.approved_at,
          ea.approved,
          COALESCE(ea.status::text, CASE WHEN ea.approved THEN 'APPROVED' ELSE 'PENDING' END) AS status,
          u.email, u.full_name
       FROM election_access ea
       JOIN app_user u ON u.user_id = ea.user_id
       WHERE ea.election_id = $1
       ORDER BY ea.requested_at DESC`,
      [req.params.electionId]
    );

    res.json({ requests: r.rows });
  } catch (e) {
    return res.status(400).json({ error: e.message });
  }
});

/**
 * ✅ Organizer approves request
 * body: { election_id, user_id }
 *
 * FIX: also inserts/updates voter table so cast_vote_org() passes
 */
router.post("/approve", auth, requireOrganizerOrSuper(), async (req, res) => {
  const { election_id, user_id } = req.body;
  if (!election_id || !user_id) {
    return res.status(400).json({ error: "Missing fields" });
  }

  try {
    // 0) Get org_id from election
    const er = await q(`SELECT org_id FROM election WHERE election_id=$1`, [election_id]);
    if (er.rowCount === 0) return res.status(404).json({ error: "Election not found" });
    const org_id = er.rows[0].org_id;

    // 1) Approve election_access
    try {
      await q(
        `UPDATE election_access
         SET approved=true,
             status = COALESCE('APPROVED'::access_status, status),
             approved_by=$1,
             approved_at=now()
         WHERE election_id=$2 AND user_id=$3`,
        [req.user.user_id, election_id, user_id]
      );
    } catch {
      // fallback if status/type not exists
      await q(
        `UPDATE election_access
         SET approved=true, approved_by=$1, approved_at=now()
         WHERE election_id=$2 AND user_id=$3`,
        [req.user.user_id, election_id, user_id]
      );
    }

    // 2) ✅ Ensure voter row exists + approved=true
    // We do NOT need ON CONFLICT/unique constraint; we do existence check.
    const vr = await q(
      `SELECT voter_id FROM voter WHERE org_id=$1 AND user_id=$2 LIMIT 1`,
      [org_id, user_id]
    );

    if (vr.rowCount === 0) {
      // Use user email as member_id (simple). If member_id is NOT NULL in your schema,
      // this prevents insert failure.
      const ur = await q(`SELECT email FROM app_user WHERE user_id=$1`, [user_id]);
      const member_id = ur.rows[0]?.email || "INVITED_USER";

      await q(
        `INSERT INTO voter(org_id, user_id, member_id, approved)
         VALUES ($1, $2, $3, true)`,
        [org_id, user_id, member_id]
      );
    } else {
      await q(
        `UPDATE voter
         SET approved=true
         WHERE org_id=$1 AND user_id=$2`,
        [org_id, user_id]
      );
    }

    res.json({ ok: true, message: "Approved (election access + voter approved)" });
  } catch (e) {
    return res.status(400).json({ error: e.message });
  }
});

/**
 * Organizer DECLINES/REJECTS request
 * body: { election_id, user_id }
 */
router.post("/reject", auth, requireOrganizerOrSuper(), async (req, res) => {
  const { election_id, user_id } = req.body;
  if (!election_id || !user_id) {
    return res.status(400).json({ error: "Missing fields" });
  }

  try {
    try {
      await q(
        `UPDATE election_access
         SET approved=false,
             status = COALESCE('REJECTED'::access_status, status),
             approved_by=$1,
             approved_at=now()
         WHERE election_id=$2 AND user_id=$3`,
        [req.user.user_id, election_id, user_id]
      );
    } catch {
      await q(
        `UPDATE election_access
         SET approved=false, approved_by=$1, approved_at=now()
         WHERE election_id=$2 AND user_id=$3`,
        [req.user.user_id, election_id, user_id]
      );
    }

    res.json({ ok: true, message: "Rejected" });
  } catch (e) {
    return res.status(400).json({ error: e.message });
  }
});

export default router;
