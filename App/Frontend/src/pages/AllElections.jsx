import React, { useEffect, useState } from "react";
import { api } from "../api/client";
import { Link } from "react-router-dom";

export default function AllElections() {
  const [elections, setElections] = useState([]);
  const [err, setErr] = useState("");

  async function load() {
    setErr("");
    try {
      const r = await api("/api/elections/all");
      setElections(r.elections || []);
    } catch (e) {
      setErr(e.message);
    }
  }

  useEffect(() => { load(); }, []);

  return (
    <div>
      <h2>All Elections</h2>
      {err ? <div style={{ color: "red", marginBottom: 12 }}>{err}</div> : null}

      <div style={{ display: "grid", gap: 12 }}>
        {elections.map((e) => {
          const access = (e.my_access_status || "NONE").toUpperCase();
          const isOpen = e.status === "OPEN";

          return (
            <div key={e.election_id} style={{ border: "1px solid #ddd", padding: 12 }}>
              <div style={{ fontWeight: 700, fontSize: 18 }}>{e.name}</div>
              <div>Organizer/Org: {e.org_name} ({e.org_code})</div>
              <div>Status: {e.status}</div>
              <div>My Access: {access}</div>

              <div style={{ marginTop: 10, display: "flex", gap: 12, flexWrap: "wrap" }}>
                {(access === "NONE" || access === "REJECTED") && (
                  <Link to={`/election/${e.election_id}/secret`}>Submit Secret Code</Link>
                )}

                {access === "PENDING" && (
                  <span style={{ color: "#b36b00" }}>Waiting for organizer approval…</span>
                )}

                {access === "APPROVED" && isOpen && (
                  <Link to={`/org/${e.org_id}/election/${e.election_id}/vote`}>Enter & Vote</Link>
                )}

                {access === "APPROVED" && !isOpen && (
                  <span style={{ color: "#1a4" }}>
                    Approved. Voting will be available when election is OPEN.
                  </span>
                )}

                <Link to={`/election/${e.election_id}/results`}>Results</Link>
              </div>
            </div>
          );
        })}

        {elections.length === 0 ? <div style={{ color: "#666" }}>No elections found.</div> : null}
      </div>
    </div>
  );
}
