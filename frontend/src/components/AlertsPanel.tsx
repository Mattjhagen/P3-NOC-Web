import React from "react";
import { RefreshCw } from "lucide-react";

interface AlertsPanelProps {
  alerts: {
    critical: string[];
    warning: string[];
    info: string[];
    logs: any[];
  };
  onRefresh: () => void;
}

const severityColor = (sev: string) => {
  switch (sev?.toUpperCase()) {
    case "CRITICAL": return "#ef233c";
    case "WARNING": return "#ffd166";
    default: return "var(--metro-accent)";
  }
};

const resultColor = (res: string) => {
  if (res === "SUCCESS") return "#06d6a0";
  if (res === "FAILED") return "#ef233c";
  return "#ffd166";
};

export const AlertsPanel: React.FC<AlertsPanelProps> = ({ alerts, onRefresh }) => {
  const allCount = alerts.critical.length + alerts.warning.length + alerts.info.length;

  return (
    <div style={{ display: "grid", gridTemplateColumns: "280px 1fr", gap: "1px", background: "rgba(255,255,255,0.05)", minHeight: "600px" }}>

      {/* Left: Active incidents */}
      <div style={{ background: "#0f0f0f", padding: "1.75rem", display: "flex", flexDirection: "column" }}>
        <div style={{ marginBottom: "1.5rem" }}>
          <div style={{ fontSize: "0.6875rem", fontWeight: 600, letterSpacing: "0.1em", textTransform: "uppercase", color: "rgba(255,255,255,0.35)", marginBottom: "0.25rem" }}>
            active incidents
          </div>
          <div style={{ display: "flex", alignItems: "baseline", gap: "0.5rem" }}>
            <span style={{ fontSize: "2.5rem", fontWeight: 700, letterSpacing: "-0.02em", color: allCount > 0 ? "#ef233c" : "#06d6a0", lineHeight: 1 }}>
              {allCount}
            </span>
            <span style={{ fontSize: "0.875rem", fontWeight: 300, color: "rgba(255,255,255,0.35)" }}>
              {allCount === 1 ? "incident" : "incidents"}
            </span>
          </div>
        </div>

        <div style={{ flex: 1, overflowY: "auto", display: "flex", flexDirection: "column", gap: "0.75rem" }}>
          {allCount === 0 ? (
            <div style={{ textAlign: "center", paddingTop: "2rem", color: "rgba(255,255,255,0.2)", fontSize: "0.875rem", fontWeight: 300 }}>
              all systems nominal
            </div>
          ) : (
            <>
              {alerts.critical.map((item, i) => (
                <div key={`c${i}`} style={{
                  borderLeft: "3px solid #ef233c",
                  paddingLeft: "0.875rem",
                  paddingTop: "0.5rem",
                  paddingBottom: "0.5rem",
                  background: "rgba(239,35,60,0.06)",
                }}>
                  <div style={{ fontSize: "0.625rem", fontWeight: 700, letterSpacing: "0.1em", color: "#ef233c", marginBottom: "0.25rem" }}>CRITICAL</div>
                  <div style={{ fontSize: "0.8125rem", color: "#fff" }}>{item}</div>
                </div>
              ))}
              {alerts.warning.map((item, i) => (
                <div key={`w${i}`} style={{
                  borderLeft: "3px solid #ffd166",
                  paddingLeft: "0.875rem",
                  paddingTop: "0.5rem",
                  paddingBottom: "0.5rem",
                  background: "rgba(255,209,102,0.06)",
                }}>
                  <div style={{ fontSize: "0.625rem", fontWeight: 700, letterSpacing: "0.1em", color: "#ffd166", marginBottom: "0.25rem" }}>WARNING</div>
                  <div style={{ fontSize: "0.8125rem", color: "#fff" }}>{item}</div>
                </div>
              ))}
              {alerts.info.map((item, i) => (
                <div key={`i${i}`} style={{
                  borderLeft: "3px solid var(--metro-accent)",
                  paddingLeft: "0.875rem",
                  paddingTop: "0.5rem",
                  paddingBottom: "0.5rem",
                  background: "rgba(0,180,216,0.06)",
                }}>
                  <div style={{ fontSize: "0.625rem", fontWeight: 700, letterSpacing: "0.1em", color: "var(--metro-accent)", marginBottom: "0.25rem" }}>INFO</div>
                  <div style={{ fontSize: "0.8125rem", color: "#fff" }}>{item}</div>
                </div>
              ))}
            </>
          )}
        </div>
      </div>

      {/* Right: Operations log */}
      <div style={{ background: "#0f0f0f", padding: "1.75rem", display: "flex", flexDirection: "column" }}>
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-end", marginBottom: "1.5rem" }}>
          <div>
            <div style={{ fontSize: "0.6875rem", fontWeight: 600, letterSpacing: "0.1em", textTransform: "uppercase", color: "rgba(255,255,255,0.35)", marginBottom: "0.25rem" }}>
              operations log
            </div>
            <div style={{ fontSize: "1.25rem", fontWeight: 300, color: "#fff", letterSpacing: "-0.01em" }}>
              {alerts.logs.length} entries
            </div>
          </div>
          <button onClick={onRefresh} style={{
            background: "transparent",
            border: "1px solid rgba(255,255,255,0.1)",
            color: "rgba(255,255,255,0.5)",
            cursor: "pointer",
            padding: "0.5rem 0.875rem",
            fontSize: "0.6875rem",
            fontWeight: 600,
            letterSpacing: "0.08em",
            textTransform: "uppercase",
            display: "flex",
            alignItems: "center",
            gap: "0.5rem",
            fontFamily: "inherit",
            transition: "all 0.15s",
          }}
            onMouseEnter={e => { e.currentTarget.style.borderColor = "rgba(255,255,255,0.3)"; e.currentTarget.style.color = "#fff"; }}
            onMouseLeave={e => { e.currentTarget.style.borderColor = "rgba(255,255,255,0.1)"; e.currentTarget.style.color = "rgba(255,255,255,0.5)"; }}
          >
            <RefreshCw size={12} /> sync
          </button>
        </div>

        {/* Log table */}
        <div style={{ flex: 1, overflowY: "auto" }}>
          {/* Header row */}
          <div style={{
            display: "grid",
            gridTemplateColumns: "90px 80px 1fr auto",
            gap: "1rem",
            padding: "0.5rem 0",
            borderBottom: "1px solid rgba(255,255,255,0.08)",
            fontSize: "0.625rem",
            fontWeight: 700,
            letterSpacing: "0.1em",
            textTransform: "uppercase",
            color: "rgba(255,255,255,0.25)",
          }}>
            <span>Time</span>
            <span>Severity</span>
            <span>Event</span>
            <span>Result</span>
          </div>

          {alerts.logs.length === 0 ? (
            <div style={{ textAlign: "center", paddingTop: "3rem", color: "rgba(255,255,255,0.15)", fontSize: "0.875rem", fontWeight: 300 }}>
              no operations logged
            </div>
          ) : (
            alerts.logs.map(log => (
              <div key={log.id} style={{
                display: "grid",
                gridTemplateColumns: "90px 80px 1fr auto",
                gap: "1rem",
                padding: "0.625rem 0",
                borderBottom: "1px solid rgba(255,255,255,0.04)",
                fontSize: "0.8125rem",
                transition: "background 0.1s",
              }}
                onMouseEnter={e => (e.currentTarget.style.background = "rgba(255,255,255,0.02)")}
                onMouseLeave={e => (e.currentTarget.style.background = "transparent")}
              >
                <span style={{ color: "rgba(255,255,255,0.3)", fontFamily: "monospace", fontSize: "0.75rem" }}>
                  {log.timestamp?.slice(11, 19) ?? "—"}
                </span>
                <span style={{ color: severityColor(log.severity), fontWeight: 600, fontSize: "0.6875rem", letterSpacing: "0.06em" }}>
                  {log.severity}
                </span>
                <span style={{ color: "rgba(255,255,255,0.7)", overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>
                  {log.event}
                  {log.action_taken && (
                    <span style={{ color: "rgba(255,255,255,0.3)", marginLeft: "0.5rem", fontSize: "0.75rem" }}>
                      · {log.action_taken}
                    </span>
                  )}
                </span>
                <span style={{ color: resultColor(log.result), fontWeight: 600, fontSize: "0.75rem", letterSpacing: "0.04em", textAlign: "right" }}>
                  {log.result}
                </span>
              </div>
            ))
          )}
        </div>
      </div>
    </div>
  );
};
