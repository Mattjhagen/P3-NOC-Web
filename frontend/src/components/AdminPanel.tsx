import React, { useState } from "react";
import { Loader2 } from "lucide-react";
import axios from "axios";

interface AdminPanelProps {
  status: {
    overall_health_score: number;
    overall_status: string;
    autopilot_locked: boolean;
    autopilot_safe_mode: boolean;
  };
  token: string;
  onActionCompleted: () => void;
}

const ACTIONS = [
  { path: "restart-worker",  label: "Restart ingest worker",    desc: "Restarts the background systemd parsing node worker" },
  { path: "restart-ingest",  label: "Restart ingest timer",     desc: "Restarts the cron RSS article ingester scheduler" },
  { path: "requeue-failed",  label: "Requeue failed items",     desc: "Resets queue statuses from failed → pending in Postgres" },
  { path: "clear-stuck",     label: "Clear stuck processing",   desc: "Clears tasks stuck in 'processing' status > 15 minutes" },
  { path: "restart-ollama",  label: "Restart Ollama service",   desc: "Attempts remote model backend service systemctl restart" },
  { path: "warm-model",      label: "Pre-warm Ollama model",    desc: "Triggers model memory warming on R510 remote node" },
];

const label = () => ({
  fontSize: "0.6875rem",
  fontWeight: 600,
  letterSpacing: "0.1em",
  textTransform: "uppercase" as const,
  color: "rgba(255,255,255,0.35)",
  marginBottom: "0.25rem",
});

export const AdminPanel: React.FC<AdminPanelProps> = ({ status, token, onActionCompleted }) => {
  const [loadingAction, setLoadingAction] = useState<string | null>(null);
  const [responseMsg, setResponseMsg] = useState<{ type: "success" | "error"; text: string } | null>(null);
  const [currentPw, setCurrentPw] = useState("");
  const [newPw, setNewPw] = useState("");
  const [confirmPw, setConfirmPw] = useState("");
  const [pwLoading, setPwLoading] = useState(false);
  const [pwMsg, setPwMsg] = useState<{ type: "success" | "error"; text: string } | null>(null);

  const handleAction = async (path: string, actionLabel: string) => {
    setLoadingAction(path);
    setResponseMsg(null);
    try {
      const res = await axios.post(`/api/recovery/${path}`, {}, {
        headers: { Authorization: `Bearer ${token}` },
      });
      setResponseMsg({ type: "success", text: res.data.message || `${actionLabel} succeeded.` });
      onActionCompleted();
    } catch (err: any) {
      setResponseMsg({ type: "error", text: err.response?.data?.detail || `${actionLabel} failed.` });
    } finally {
      setLoadingAction(null);
    }
  };

  const handlePwChange = async (e: React.FormEvent) => {
    e.preventDefault();
    if (newPw !== confirmPw) { setPwMsg({ type: "error", text: "Passwords do not match." }); return; }
    setPwLoading(true);
    setPwMsg(null);
    try {
      await axios.post("/api/auth/change-password", { current_password: currentPw, new_password: newPw }, {
        headers: { Authorization: `Bearer ${token}` },
      });
      setPwMsg({ type: "success", text: "Password updated." });
      setCurrentPw(""); setNewPw(""); setConfirmPw("");
    } catch (err: any) {
      setPwMsg({ type: "error", text: err.response?.data?.detail || "Failed to update password." });
    } finally {
      setPwLoading(false);
    }
  };

  const inputStyle: React.CSSProperties = {
    background: "transparent",
    border: "none",
    borderBottom: "1px solid rgba(255,255,255,0.12)",
    color: "#fff",
    fontSize: "0.9375rem",
    padding: "0.6rem 0",
    width: "100%",
    outline: "none",
    fontFamily: "inherit",
    transition: "border-color 0.2s",
  };

  const healthColor = status.overall_health_score >= 90 ? "#06d6a0" : status.overall_health_score >= 50 ? "#ffd166" : "#ef233c";

  return (
    <div style={{ display: "grid", gridTemplateColumns: "1fr 2fr", gap: "1px", background: "rgba(255,255,255,0.05)" }}>

      {/* ── Left column ── */}
      <div style={{ display: "flex", flexDirection: "column", gap: "1px", background: "rgba(255,255,255,0.05)" }}>

        {/* Autopilot status */}
        <div style={{ background: "#0f0f0f", padding: "1.75rem" }}>
          <div style={label()}>autopilot</div>
          <div style={{ fontSize: "1.5rem", fontWeight: 300, color: "#fff", marginBottom: "1.5rem" }}>control deck</div>

          <div style={{ display: "flex", flexDirection: "column", gap: "1px", background: "rgba(255,255,255,0.05)", marginBottom: "1.5rem" }}>
            {[
              { label: "State", value: status.overall_status, color: status.autopilot_locked ? "#ef233c" : "#06d6a0" },
              { label: "Safe mode", value: status.autopilot_safe_mode ? "ACTIVE" : "INACTIVE", color: status.autopilot_safe_mode ? "#ffd166" : "rgba(255,255,255,0.3)" },
              { label: "Health", value: `${status.overall_health_score}%`, color: healthColor },
            ].map((row, i) => (
              <div key={i} style={{
                background: "#111",
                padding: "0.875rem 1rem",
                display: "flex",
                justifyContent: "space-between",
                alignItems: "center",
              }}>
                <span style={{ fontSize: "0.8125rem", color: "rgba(255,255,255,0.4)" }}>{row.label}</span>
                <span style={{ fontSize: "0.9375rem", fontWeight: 600, color: row.color }}>{row.value}</span>
              </div>
            ))}
          </div>

          <button
            onClick={() => handleAction("unlock", "Unlock autopilot")}
            disabled={(!status.autopilot_locked && !status.autopilot_safe_mode) || loadingAction !== null}
            style={{
              width: "100%",
              background: (status.autopilot_locked || status.autopilot_safe_mode) ? "rgba(239,35,60,0.12)" : "transparent",
              border: `1px solid ${(status.autopilot_locked || status.autopilot_safe_mode) ? "rgba(239,35,60,0.3)" : "rgba(255,255,255,0.06)"}`,
              color: (status.autopilot_locked || status.autopilot_safe_mode) ? "#ef233c" : "rgba(255,255,255,0.2)",
              cursor: (status.autopilot_locked || status.autopilot_safe_mode) ? "pointer" : "not-allowed",
              padding: "0.875rem",
              fontSize: "0.75rem",
              fontWeight: 700,
              letterSpacing: "0.08em",
              textTransform: "uppercase",
              fontFamily: "inherit",
              transition: "all 0.15s",
            }}
          >
            {loadingAction === "unlock"
              ? <span style={{ display: "flex", justifyContent: "center", alignItems: "center", gap: "0.5rem" }}><Loader2 size={14} className="animate-spin" /> bypassing...</span>
              : "bypass safelock override"
            }
          </button>
        </div>

        {/* Password change */}
        <div style={{ background: "#0f0f0f", padding: "1.75rem", flex: 1 }}>
          <div style={label()}>security</div>
          <div style={{ fontSize: "1.25rem", fontWeight: 300, color: "#fff", marginBottom: "1.5rem" }}>change password</div>

          {pwMsg && (
            <div style={{
              background: pwMsg.type === "success" ? "rgba(6,214,160,0.08)" : "rgba(239,35,60,0.08)",
              borderLeft: `3px solid ${pwMsg.type === "success" ? "#06d6a0" : "#ef233c"}`,
              padding: "0.75rem 1rem",
              marginBottom: "1.25rem",
              fontSize: "0.8125rem",
              color: pwMsg.type === "success" ? "#06d6a0" : "#ef233c",
            }}>
              {pwMsg.text}
            </div>
          )}

          <form onSubmit={handlePwChange} style={{ display: "flex", flexDirection: "column", gap: "1.25rem" }}>
            {[
              { label: "Current password", value: currentPw, set: setCurrentPw },
              { label: "New password", value: newPw, set: setNewPw },
              { label: "Confirm new password", value: confirmPw, set: setConfirmPw },
            ].map((field, i) => (
              <div key={i}>
                <div style={label()}>{field.label}</div>
                <input
                  type="password"
                  required
                  value={field.value}
                  onChange={e => field.set(e.target.value)}
                  style={inputStyle}
                  onFocus={e => (e.currentTarget.style.borderBottomColor = "var(--metro-accent)")}
                  onBlur={e => (e.currentTarget.style.borderBottomColor = "rgba(255,255,255,0.12)")}
                />
              </div>
            ))}
            <button type="submit" disabled={pwLoading || !currentPw || !newPw || !confirmPw}
              style={{
                background: "var(--metro-accent)",
                border: "none",
                color: "#000",
                padding: "0.75rem",
                fontSize: "0.75rem",
                fontWeight: 700,
                letterSpacing: "0.08em",
                textTransform: "uppercase",
                cursor: pwLoading || !currentPw || !newPw || !confirmPw ? "not-allowed" : "pointer",
                opacity: pwLoading || !currentPw || !newPw || !confirmPw ? 0.4 : 1,
                fontFamily: "inherit",
              }}
            >
              {pwLoading ? "updating..." : "update password"}
            </button>
          </form>
        </div>
      </div>

      {/* ── Right column: Recovery operations ── */}
      <div style={{ background: "#0f0f0f", padding: "1.75rem" }}>
        <div style={label()}>recovery interface</div>
        <div style={{ fontSize: "1.5rem", fontWeight: 300, color: "#fff", marginBottom: "0.5rem" }}>manual operations</div>

        {responseMsg && (
          <div style={{
            background: responseMsg.type === "success" ? "rgba(6,214,160,0.08)" : "rgba(239,35,60,0.08)",
            borderLeft: `3px solid ${responseMsg.type === "success" ? "#06d6a0" : "#ef233c"}`,
            padding: "0.75rem 1rem",
            marginBottom: "1.5rem",
            marginTop: "1rem",
            fontSize: "0.8125rem",
            color: responseMsg.type === "success" ? "#06d6a0" : "#ef233c",
          }}>
            {responseMsg.text}
          </div>
        )}

        <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fill, minmax(280px, 1fr))", gap: "1px", background: "rgba(255,255,255,0.05)", marginTop: "1.5rem" }}>
          {ACTIONS.map(act => {
            const isRunning = loadingAction === act.path;
            return (
              <div key={act.path} style={{ background: "#0f0f0f", padding: "1.25rem" }}>
                <div style={{ fontSize: "0.9375rem", fontWeight: 400, color: "#fff", marginBottom: "0.375rem" }}>
                  {act.label}
                </div>
                <div style={{ fontSize: "0.8125rem", color: "rgba(255,255,255,0.35)", marginBottom: "1.25rem", lineHeight: 1.4 }}>
                  {act.desc}
                </div>
                <button
                  onClick={() => handleAction(act.path, act.label)}
                  disabled={loadingAction !== null}
                  style={{
                    background: "transparent",
                    border: "1px solid rgba(255,255,255,0.1)",
                    color: isRunning ? "var(--metro-accent)" : "rgba(255,255,255,0.5)",
                    borderColor: isRunning ? "var(--metro-accent)" : "rgba(255,255,255,0.1)",
                    fontSize: "0.6875rem",
                    fontWeight: 700,
                    letterSpacing: "0.08em",
                    textTransform: "uppercase",
                    padding: "0.5rem 1rem",
                    cursor: loadingAction !== null ? "not-allowed" : "pointer",
                    opacity: loadingAction !== null && !isRunning ? 0.35 : 1,
                    display: "flex",
                    alignItems: "center",
                    gap: "0.5rem",
                    fontFamily: "inherit",
                    transition: "all 0.15s",
                  }}
                  onMouseEnter={e => { if (!loadingAction) { e.currentTarget.style.borderColor = "var(--metro-accent)"; e.currentTarget.style.color = "var(--metro-accent)"; }}}
                  onMouseLeave={e => { if (!isRunning) { e.currentTarget.style.borderColor = "rgba(255,255,255,0.1)"; e.currentTarget.style.color = "rgba(255,255,255,0.5)"; }}}
                >
                  {isRunning ? (
                    <><Loader2 size={12} className="animate-spin" /> executing...</>
                  ) : "run operation"}
                </button>
              </div>
            );
          })}
        </div>
      </div>
    </div>
  );
};
