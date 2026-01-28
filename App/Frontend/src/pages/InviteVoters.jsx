// frontend/src/pages/InviteVoters.jsx (FULL UPDATED)

import React, { useEffect, useState } from "react";
import { api } from "../api/client";
import { useParams } from "react-router-dom";

export default function InviteVoters() {
  const { electionId } = useParams();

  const [orgId, setOrgId] = useState("");
  const [emailsText, setEmailsText] = useState("student1@gmail.com\nstudent2@gmail.com");
  const [requests, setRequests] = useState([]);
  const [msg, setMsg] = useState("");
  const [err, setErr] = useState("");

  async function loadElectionOrg() {
    const overview = await api(`/api/elections/${electionId}/overview`);
    const org_id = overview?.data?.election?.org_id;
    if (!org_id) throw new Error("Cannot find org_id for this election");
    setOrgId(org_id);
  }

  async function loadPending() {
    const r = await api(`/api/invite/pending/${electionId}`);
    setRequests(r.requests || []);
  }

  useEffect(() => {
    (async () => {
      try {
        setErr("");
        setMsg("");
        await loadElectionOrg();
        await loadPending();
      } catch (e) {
        setErr(e.message);
      }
    })();
  }, [electionId]);

  async function sendInvites() {
    try {
      setErr("");
      setMsg("");

      if (!orgId) throw new Error("orgId not loaded yet");

      const emails = emailsText
        .split(/\r?\n/)
        .map((s) => s.trim().toLowerCase())
        .filter(Boolean);

      if (emails.length === 0) throw new Error("Enter at least 1 email");

      for (const email of emails) {
        await api(`/api/invite/create`, {
          method: "POST",
          body: { org_id: orgId, election_id: electionId, email }
        });
      }

      setMsg(`Invites sent to ${emails.length} email(s).`);
    } catch (e) {
      setErr(e.message);
    }
  }

  async function approve(user_id) {
    try {
      setErr("");
      setMsg("");

      await api(`/api/invite/approve`, {
        method: "POST",
        body: { election_id: electionId, user_id }
      });

      await loadPending();
      setMsg("Approved!");
    } catch (e) {
      setErr(e.message);
    }
  }

  async function reject(user_id) {
    try {
      setErr("");
      setMsg("");

      await api(`/api/invite/reject`, {
        method: "POST",
        body: { election_id: electionId, user_id }
      });

      await loadPending();
      setMsg("Rejected!");
    } catch (e) {
      setErr(e.message);
    }
  }

  return (
    <div style={{ maxWidth: 820 }}>
      <h2>Invite / Approve Voters</h2>

      {err ? <div style={{ color: "red", marginBottom: 10 }}>{err}</div> : null}
      {msg ? <div style={{ color: "green", marginBottom: 10 }}>{msg}</div> : null}

      <div style={{ border: "1px solid #ddd", padding: 12, marginBottom: 16 }}>
        <h3>Send Invites (Organizer)</h3>
        <p>Enter one email per line. Each email will receive a one-time secret code.</p>

        <textarea
          rows={6}
          style={{ width: "100%" }}
          value={emailsText}
          onChange={(e) => setEmailsText(e.target.value)}
        />

        <button onClick={sendInvites} style={{ marginTop: 8 }}>
          Send Invites
        </button>
      </div>

      <div style={{ border: "1px solid #ddd", padding: 12 }}>
        <h3>Requests</h3>
        <p>Voters submit secret → request appears here → approve to allow voting.</p>

        {requests.length === 0 ? (
          <div>No requests yet.</div>
        ) : (
          <div style={{ display: "grid", gap: 10 }}>
            {requests.map((r) => {
              const status = (r.status || (r.approved ? "APPROVED" : "PENDING")).toUpperCase();

              return (
                <div key={r.access_id} style={{ border: "1px solid #eee", padding: 10 }}>
                  <div>
                    <b>{r.full_name}</b> ({r.email})
                  </div>
                  <div>Requested: {r.requested_at}</div>
                  <div>
                    Status: <b>{status}</b>
                  </div>

                  <div style={{ marginTop: 8, display: "flex", gap: 8 }}>
                    {status !== "APPROVED" ? (
                      <button onClick={() => approve(r.user_id)}>Approve</button>
                    ) : null}

                    {status !== "REJECTED" ? (
                      <button onClick={() => reject(r.user_id)}>Reject</button>
                    ) : null}
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </div>
    </div>
  );
}
