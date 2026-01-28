import React, { useEffect, useState } from "react";
import { api } from "../api/client";
import { useParams } from "react-router-dom";

export default function OrgVoters() {
  const { orgId } = useParams();
  const [voters, setVoters] = useState([]);
  const [err, setErr] = useState("");

  async function load() {
    setErr("");
    try {
      const r = await api(`/api/org/${orgId}/voters`);
      setVoters(r.voters);
    } catch (e) {
      setErr(e.message);
    }
  }

  async function approve(voterId) {
    setErr("");
    try {
      await api(`/api/org/${orgId}/voters/${voterId}/approve`, { method: "POST" });
      await load();
    } catch (e) {
      setErr(e.message);
    }
  }

  useEffect(() => { load(); }, []);

  return (
    <div>
      <h2>Voters (Admin)</h2>
      {err ? <div style={{ color: "red" }}>{err}</div> : null}
      <div style={{ display: "grid", gap: 10 }}>
        {voters.map(v => (
          <div key={v.voter_id} style={{ border: "1px solid #ddd", padding: 10 }}>
            <div><b>{v.full_name}</b> ({v.email})</div>
            <div>member_id: {v.member_id}</div>
            <div>approved: {String(v.approved)}</div>
            {!v.approved ? <button onClick={() => approve(v.voter_id)}>Approve</button> : null}
          </div>
        ))}
      </div>
    </div>
  );
}
