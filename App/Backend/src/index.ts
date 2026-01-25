import express from "express";
import cors from "cors";
import helmet from "helmet";
import morgan from "morgan";
import dotenv from "dotenv";
import authRouter from "./routes/auth.routes";
import orgRoutes from "./routes/orgs";
import electionsRouter from "./routes/elections";
import votingRouter from "./routes/voting";
import racesRouter from "./routes/races";
import { pool } from "./db";
import votesRouter from "./routes/votes.routes";
import { electionScheduler } from "./services/electionScheduler";

dotenv.config();

const app = express();

app.use(express.json());
app.use(cors());
app.use(helmet());
app.use(morgan("dev"));

app.get("/", (req, res) => {
  res.send("API is running. Go to /health");
});

app.get("/health", async (req, res, next) => {
  try {
    const r = await pool.query("SELECT 1 as ok");
    res.set("Cache-Control", "no-store");
    res.json({ ok: true, db: r.rows[0].ok });
  } catch (e) {
    next(e);
  }
});

// ✅ Mount routes
app.use("/votes", votesRouter);

app.use("/auth", authRouter);

app.use("/orgs", orgRoutes);

app.use("/elections", electionsRouter);

app.use("/voting", votingRouter);

app.use("/races", racesRouter);


// ✅ 404 handler (if route not found)
app.use((req, res) => {
  res.status(404).json({ ok: false, error: `Not Found: ${req.method} ${req.path}` });
});

// ✅ Error handler (THIS will show Postgres errors clearly)
app.use((err: any, req: any, res: any, next: any) => {
  console.error("❌ ERROR:", err);

  res.status(500).json({
    ok: false,
    error: err.message,
    code: err.code,      // Postgres error code (often exists)
    detail: err.detail,  // extra info (sometimes exists)
  });
});

const port = Number(process.env.PORT || 4000);
app.listen(port, () => {
  console.log(`API running: http://localhost:${port}`);

  // Start election scheduler
  electionScheduler.start();
});
