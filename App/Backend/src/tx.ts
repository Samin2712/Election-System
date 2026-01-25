import { pool } from "./db";
import { randomUUID } from "crypto";

/**
 * Runs a function inside a DB transaction and sets Postgres session context
 * so triggers/audit can read:
 *  - app.actor_user_id
 *  - app.organization_id
 *  - app.request_id
 */
export async function withTx<T>(req: any, fn: (client: any) => Promise<T>): Promise<T> {
  const client = await pool.connect();

  const requestId = String(req.headers["x-request-id"] ?? randomUUID());
  const userId = String(req.user?.user_id ?? "");            // set by auth middleware
  const orgId  = String(req.orgId ?? req.headers["x-org-id"] ?? ""); // your org scoping

  try {
    await client.query("BEGIN");

    // ✅ THESE ARE THE 3 LINES (kept here centrally)
    await client.query("select set_config('app.actor_user_id', $1, true)", [userId]);
    await client.query("select set_config('app.organization_id', $1, true)", [orgId]);
    await client.query("select set_config('app.request_id', $1, true)", [requestId]);

    const result = await fn(client);

    await client.query("COMMIT");
    return result;
  } catch (err) {
    await client.query("ROLLBACK");
    throw err;
  } finally {
    client.release();
  }
}
