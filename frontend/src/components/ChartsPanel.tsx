import React from "react";
import { AreaChart, Area, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, Legend } from "recharts";

interface ChartsPanelProps {
  metrics: any[];
  selectedRange: string;
  setSelectedRange: (range: string) => void;
}

const RANGES = [
  { id: "1h", label: "1h" },
  { id: "24h", label: "24h" },
  { id: "7d", label: "7d" },
  { id: "30d", label: "30d" },
];

const CustomTooltip = ({ active, payload, label }: any) => {
  if (!active || !payload?.length) return null;
  return (
    <div style={{
      background: "#111",
      border: "1px solid rgba(255,255,255,0.1)",
      padding: "0.75rem 1rem",
      fontSize: "0.75rem",
    }}>
      <div style={{ color: "rgba(255,255,255,0.4)", marginBottom: "0.5rem" }}>{label}</div>
      {payload.map((p: any, i: number) => (
        <div key={i} style={{ display: "flex", justifyContent: "space-between", gap: "1.5rem", color: p.color, marginBottom: "0.2rem" }}>
          <span>{p.name}</span>
          <span style={{ fontWeight: 600 }}>{p.value} {p.unit || ""}</span>
        </div>
      ))}
    </div>
  );
};

export const ChartsPanel: React.FC<ChartsPanelProps> = ({ metrics, selectedRange, setSelectedRange }) => {
  const formatX = (tick: string) => {
    if (!tick) return "";
    try {
      const d = new Date(tick);
      return selectedRange === "1h" || selectedRange === "24h"
        ? d.toLocaleTimeString("en-US", { hour12: false, hour: "2-digit", minute: "2-digit" })
        : d.toLocaleDateString("en-US", { month: "short", day: "numeric" });
    } catch { return tick; }
  };

  const tickStyle = { fill: "rgba(255,255,255,0.2)", fontSize: 10 };
  const gridStroke = "rgba(255,255,255,0.04)";

  const charts = [
    {
      title: "CPU load history",
      series: [
        { key: "t310_cpu", name: "T310 CPU", color: "var(--metro-accent)" },
        { key: "r510_cpu", name: "R510 CPU", color: "rgba(0,180,216,0.5)" },
      ],
      domain: [0, 100] as [number, number],
      unit: "%",
    },
    {
      title: "Memory usage history",
      series: [
        { key: "t310_ram", name: "T310 RAM", color: "#06d6a0" },
        { key: "r510_ram", name: "R510 RAM", color: "rgba(6,214,160,0.5)" },
      ],
      domain: [0, 100] as [number, number],
      unit: "%",
    },
    {
      title: "Network throughput",
      series: [
        { key: "network_rx", name: "Download RX", color: "#06d6a0" },
        { key: "network_tx", name: "Upload TX", color: "var(--metro-accent)" },
      ],
      domain: undefined,
      unit: "KB/s",
    },
    {
      title: "Article processing vs AI volume",
      series: [
        { key: "processing_rate", name: "Ingest rate", color: "#ffd166" },
        { key: "ai_volume", name: "AI requests", color: "var(--metro-accent)" },
      ],
      domain: undefined,
      unit: "",
    },
  ];

  return (
    <div style={{ background: "#0f0f0f", padding: "1.75rem" }}>
      {/* Header */}
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-end", marginBottom: "2rem" }}>
        <div>
          <div style={{ fontSize: "0.6875rem", fontWeight: 600, letterSpacing: "0.1em", textTransform: "uppercase", color: "rgba(255,255,255,0.35)", marginBottom: "0.25rem" }}>
            historical telemetry
          </div>
          <div style={{ fontSize: "1.5rem", fontWeight: 300, color: "#fff", letterSpacing: "-0.01em" }}>
            {selectedRange === "1h" ? "last hour" : selectedRange === "24h" ? "last 24 hours" : selectedRange === "7d" ? "last 7 days" : "last 30 days"}
          </div>
        </div>

        {/* Range switcher */}
        <div style={{ display: "flex", gap: "2px", background: "#1a1a1a", padding: "2px" }}>
          {RANGES.map(r => (
            <button key={r.id} onClick={() => setSelectedRange(r.id)}
              style={{
                background: selectedRange === r.id ? "var(--metro-accent)" : "transparent",
                border: "none",
                color: selectedRange === r.id ? "#000" : "rgba(255,255,255,0.35)",
                fontWeight: selectedRange === r.id ? 700 : 400,
                fontSize: "0.75rem",
                padding: "0.375rem 0.75rem",
                cursor: "pointer",
                fontFamily: "inherit",
                transition: "all 0.15s",
                letterSpacing: "0.05em",
              }}
            >{r.label}</button>
          ))}
        </div>
      </div>

      {/* Charts 2×2 grid */}
      <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit, minmax(320px, 1fr))", gap: "1px", background: "rgba(255,255,255,0.05)" }}>
        {charts.map((chart, ci) => (
          <div key={ci} style={{ background: "#0f0f0f", padding: "1.25rem", height: "280px" }}>
            <div style={{ fontSize: "0.6875rem", fontWeight: 600, letterSpacing: "0.1em", textTransform: "uppercase", color: "rgba(255,255,255,0.3)", marginBottom: "1rem" }}>
              {chart.title}
            </div>
            <ResponsiveContainer width="100%" height="85%">
              <AreaChart data={metrics} margin={{ top: 0, right: 0, left: -28, bottom: 0 }}>
                <defs>
                  {chart.series.map((s, si) => (
                    <linearGradient key={si} id={`grad_${ci}_${si}`} x1="0" y1="0" x2="0" y2="1">
                      <stop offset="5%" stopColor={s.color} stopOpacity={0.2} />
                      <stop offset="95%" stopColor={s.color} stopOpacity={0} />
                    </linearGradient>
                  ))}
                </defs>
                <CartesianGrid stroke={gridStroke} strokeDasharray="0" />
                <XAxis dataKey="timestamp" tickFormatter={formatX} tick={tickStyle} axisLine={false} tickLine={false} />
                <YAxis domain={chart.domain} tick={tickStyle} axisLine={false} tickLine={false} />
                <Tooltip content={<CustomTooltip />} cursor={{ stroke: "rgba(255,255,255,0.1)" }} />
                <Legend verticalAlign="top" height={28} iconType="circle" wrapperStyle={{ fontSize: 11, color: "rgba(255,255,255,0.4)" }} />
                {chart.series.map((s, si) => (
                  <Area
                    key={si}
                    type="monotone"
                    dataKey={s.key}
                    name={s.name}
                    stroke={s.color}
                    strokeWidth={1.5}
                    fill={`url(#grad_${ci}_${si})`}
                    unit={chart.unit ? ` ${chart.unit}` : ""}
                  />
                ))}
              </AreaChart>
            </ResponsiveContainer>
          </div>
        ))}
      </div>
    </div>
  );
};


