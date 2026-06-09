import React from "react";


interface MetricsCardProps {
  t310: any;
  r510: any;
  queueCounts: any;
}

const S = {
  card: {
    background: "#111",
    padding: "1.5rem",
    marginBottom: "0",
  } as React.CSSProperties,
  label: {
    fontSize: "0.6875rem",
    fontWeight: 600,
    letterSpacing: "0.1em",
    textTransform: "uppercase" as const,
    color: "rgba(255,255,255,0.35)",
    marginBottom: "0.25rem",
  } as React.CSSProperties,
  value: {
    fontSize: "1.75rem",
    fontWeight: 700,
    letterSpacing: "-0.02em",
    lineHeight: 1,
    color: "#fff",
  } as React.CSSProperties,
  row: {
    display: "flex",
    justifyContent: "space-between",
    alignItems: "center",
    padding: "0.6rem 0",
    borderBottom: "1px solid rgba(255,255,255,0.05)",
    fontSize: "0.8125rem",
  } as React.CSSProperties,
  rowLabel: { color: "rgba(255,255,255,0.35)", fontWeight: 400 } as React.CSSProperties,
  rowValue: { color: "#fff", fontWeight: 500 } as React.CSSProperties,
};

const metricColor = (val: number) =>
  val >= 85 ? "#ef233c" : val >= 60 ? "#ffd166" : "#06d6a0";

const ProgressBar: React.FC<{ value: number; label: string }> = ({ value, label }) => (
  <div style={{ marginBottom: "1rem" }}>
    <div style={{ display: "flex", justifyContent: "space-between", marginBottom: "0.375rem" }}>
      <span style={S.label}>{label}</span>
      <span style={{ fontSize: "0.8125rem", fontWeight: 600, color: metricColor(value) }}>{value}%</span>
    </div>
    <div style={{ background: "rgba(255,255,255,0.06)", height: "3px", borderRadius: "2px", overflow: "hidden" }}>
      <div style={{ width: `${value}%`, height: "100%", background: metricColor(value), transition: "width 0.5s ease" }} />
    </div>
  </div>
);

export const MetricsCard: React.FC<MetricsCardProps> = ({ t310, r510, queueCounts }) => {
  const t310CPU = t310?.cpu_percent ?? 0;
  const t310RAM = t310?.ram_percent ?? 0;
  const t310Disk = t310?.disk_percent ?? 0;
  const r510CPU = r510?.cpu_percent ?? 0;
  const r510RAM = r510?.ram_percent ?? 0;
  const r510Online = r510?.online ?? false;

  return (
    <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(340px, 1fr))", gap: "1px", background: "rgba(255,255,255,0.05)" }}>

      {/* T310 Card */}
      <div style={{ background: "#0f0f0f", padding: "1.75rem" }}>
        <div style={{ marginBottom: "1.5rem" }}>
          <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start", marginBottom: "0.25rem" }}>
            <div>
              <div style={S.label}>noc server</div>
              <div style={{ fontSize: "1.25rem", fontWeight: 300, color: "#fff", letterSpacing: "-0.01em" }}>Dell PowerEdge T310</div>
            </div>
            <div style={{ display: "flex", alignItems: "center", gap: "0.5rem" }}>
              <span style={{ width: "7px", height: "7px", borderRadius: "50%", background: "#06d6a0", display: "inline-block" }} />
              <span style={{ fontSize: "0.6875rem", fontWeight: 600, letterSpacing: "0.08em", color: "#06d6a0" }}>ONLINE</span>
            </div>
          </div>
        </div>

        <ProgressBar value={t310CPU} label="CPU load" />
        <ProgressBar value={t310RAM} label="Memory usage" />
        <ProgressBar value={t310Disk} label="Disk usage" />

        <div style={{ marginTop: "1rem", borderTop: "1px solid rgba(255,255,255,0.05)", paddingTop: "1rem" }}>
          <div style={S.row}>
            <span style={S.rowLabel}>Network RX</span>
            <span style={S.rowValue}>{t310?.network_rx_kbps ?? 0} KB/s</span>
          </div>
          <div style={S.row}>
            <span style={S.rowLabel}>Network TX</span>
            <span style={S.rowValue}>{t310?.network_tx_kbps ?? 0} KB/s</span>
          </div>
          <div style={{ ...S.row, borderBottom: "none" }}>
            <span style={S.rowLabel}>Load average</span>
            <span style={S.rowValue}>{t310?.load_avg?.join("  ") ?? "0.00"}</span>
          </div>
        </div>
      </div>

      {/* R510 Card */}
      <div style={{ background: "#0f0f0f", padding: "1.75rem" }}>
        <div style={{ marginBottom: "1.5rem" }}>
          <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start", marginBottom: "0.25rem" }}>
            <div>
              <div style={S.label}>ai inference node</div>
              <div style={{ fontSize: "1.25rem", fontWeight: 300, color: "#fff", letterSpacing: "-0.01em" }}>Dell PowerEdge R510</div>
            </div>
            <div style={{ display: "flex", alignItems: "center", gap: "0.5rem" }}>
              <span style={{ width: "7px", height: "7px", borderRadius: "50%", background: r510Online ? "#06d6a0" : "#ef233c", display: "inline-block" }} />
              <span style={{ fontSize: "0.6875rem", fontWeight: 600, letterSpacing: "0.08em", color: r510Online ? "#06d6a0" : "#ef233c" }}>
                {r510Online ? "ONLINE" : "OFFLINE"}
              </span>
            </div>
          </div>
        </div>

        <ProgressBar value={r510CPU} label="CPU load" />
        <ProgressBar value={r510RAM} label="Memory usage" />

        <div style={{ marginBottom: "1rem" }}>
          <div style={S.label}>Ping latency</div>
          <div style={{ fontSize: "1.75rem", fontWeight: 700, color: r510Online ? "var(--metro-accent)" : "#ef233c" }}>
            {r510Online ? `${r510?.ping_latency_ms ?? 0}ms` : "TIMEOUT"}
          </div>
        </div>

        <div style={{ marginTop: "1rem", borderTop: "1px solid rgba(255,255,255,0.05)", paddingTop: "1rem" }}>
          <div style={S.row}>
            <span style={S.rowLabel}>Ollama port</span>
            <span style={{ ...S.rowValue, color: r510?.ollama_status === "ONLINE" ? "#06d6a0" : "#ef233c" }}>
              {r510?.ollama_status ?? "—"}
            </span>
          </div>
          <div style={S.row}>
            <span style={S.rowLabel}>Active model</span>
            <span style={S.rowValue}>{r510?.active_model ?? "None"}</span>
          </div>
          <div style={S.row}>
            <span style={S.rowLabel}>Queue</span>
            <span style={S.rowValue}>{queueCounts?.pending ?? 0} pending · {queueCounts?.processing ?? 0} active</span>
          </div>
          <div style={{ ...S.row, borderBottom: "none" }}>
            <span style={S.rowLabel}>Uptime</span>
            <span style={S.rowValue}>{r510Online ? (r510?.uptime ?? "N/A") : "offline"}</span>
          </div>
        </div>
      </div>
    </div>
  );
};
