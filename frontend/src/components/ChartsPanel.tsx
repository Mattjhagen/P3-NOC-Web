import React from "react";
import { AreaChart, Area, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, Legend } from "recharts";
import { CalendarRange, Activity } from "lucide-react";

interface ChartsPanelProps {
  metrics: any[];
  selectedRange: string;
  setSelectedRange: (range: string) => void;
}

export const ChartsPanel: React.FC<ChartsPanelProps> = ({
  metrics,
  selectedRange,
  setSelectedRange,
}) => {
  const ranges = [
    { id: "1h", label: "1 HOUR" },
    { id: "24h", label: "24 HOURS" },
    { id: "7d", label: "7 DAYS" },
    { id: "30d", label: "30 DAYS" },
  ];

  // Helper to format timestamps on XAxis
  const formatXAxis = (tickItem: string) => {
    if (!tickItem) return "";
    try {
      const date = new Date(tickItem);
      if (selectedRange === "1h") {
        return date.toLocaleTimeString("en-US", { hour12: false, hour: "2-digit", minute: "2-digit" });
      } else if (selectedRange === "24h") {
        return date.toLocaleTimeString("en-US", { hour12: false, hour: "2-digit", minute: "2-digit" });
      } else {
        return date.toLocaleDateString("en-US", { month: "short", day: "numeric" });
      }
    } catch {
      return tickItem;
    }
  };

  // Custom tooltips matching dark theme
  const CustomTooltip = ({ active, payload, label }: any) => {
    if (active && payload && payload.length) {
      return (
        <div className="glass-panel p-3 rounded-lg border border-dashboard-border bg-dashboard-card/90 shadow-lg text-xs font-mono">
          <p className="text-dashboard-accent mb-1.5 font-semibold font-digital">{formatXAxis(label)}</p>
          {payload.map((pld: any, idx: number) => (
            <p key={idx} style={{ color: pld.color }} className="flex justify-between gap-4 py-0.5">
              <span className="uppercase tracking-wider font-semibold">{pld.name}:</span>
              <span className="font-digital font-bold">{pld.value} {pld.unit || ""}</span>
            </p>
          ))}
        </div>
      );
    }
    return null;
  };

  return (
    <div className="glass-panel rounded-xl p-6 border border-dashboard-border space-y-6">
      
      {/* Header and range togglers */}
      <div className="flex flex-col sm:flex-row items-center justify-between gap-4 border-b border-dashboard-border pb-4">
        <div className="flex items-center gap-2.5">
          <Activity className="w-5 h-5 text-dashboard-neon animate-pulse" />
          <h3 className="text-md font-bold font-digital tracking-wider text-white">HISTORICAL TELEMETRY</h3>
        </div>
        
        {/* Toggle Range buttons */}
        <div className="flex bg-black/40 rounded-lg p-1 border border-dashboard-border">
          {ranges.map((r) => (
            <button
              key={r.id}
              onClick={() => setSelectedRange(r.id)}
              className={`px-3 py-1.5 rounded-md text-xs font-semibold font-digital transition-all ${
                selectedRange === r.id
                  ? "bg-dashboard-neon/15 text-dashboard-neon border border-dashboard-neon/30"
                  : "text-gray-400 hover:text-white border border-transparent"
              }`}
            >
              {r.label}
            </button>
          ))}
        </div>
      </div>

      {/* Graphs Grid */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        
        {/* Graph 1: CPU Loading History */}
        <div className="bg-black/20 p-4 rounded-xl border border-dashboard-border/30 h-72">
          <h4 className="text-xs font-mono font-bold text-dashboard-accent uppercase mb-4 tracking-widest">CPU LOADING HISTORY</h4>
          <ResponsiveContainer width="100%" height="85%">
            <AreaChart data={metrics} margin={{ top: 5, right: 5, left: -20, bottom: 5 }}>
              <defs>
                <linearGradient id="colorT310Cpu" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="5%" stopColor="#66FCF1" stopOpacity={0.25}/>
                  <stop offset="95%" stopColor="#66FCF1" stopOpacity={0}/>
                </linearGradient>
                <linearGradient id="colorR510Cpu" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="5%" stopColor="#45A29E" stopOpacity={0.25}/>
                  <stop offset="95%" stopColor="#45A29E" stopOpacity={0}/>
                </linearGradient>
              </defs>
              <CartesianGrid stroke="#2C3539" strokeDasharray="3 3" opacity={0.3} />
              <XAxis dataKey="timestamp" tickFormatter={formatXAxis} tick={{ fill: '#8A939E', fontSize: 10 }} />
              <YAxis domain={[0, 100]} tick={{ fill: '#8A939E', fontSize: 10 }} />
              <Tooltip content={<CustomTooltip />} />
              <Legend verticalAlign="top" height={36} iconType="circle" wrapperStyle={{ fontSize: 11 }} />
              <Area type="monotone" name="T310 CPU" dataKey="t310_cpu" stroke="#66FCF1" strokeWidth={2} fillOpacity={1} fill="url(#colorT310Cpu)" unit="%" />
              <Area type="monotone" name="R510 CPU" dataKey="r510_cpu" stroke="#45A29E" strokeWidth={2} fillOpacity={1} fill="url(#colorR510Cpu)" unit="%" />
            </AreaChart>
          </ResponsiveContainer>
        </div>

        {/* Graph 2: Memory (RAM) History */}
        <div className="bg-black/20 p-4 rounded-xl border border-dashboard-border/30 h-72">
          <h4 className="text-xs font-mono font-bold text-dashboard-accent uppercase mb-4 tracking-widest">MEMORY UTILIZATION HISTORY</h4>
          <ResponsiveContainer width="100%" height="85%">
            <AreaChart data={metrics} margin={{ top: 5, right: 5, left: -20, bottom: 5 }}>
              <defs>
                <linearGradient id="colorT310Ram" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="5%" stopColor="#66FCF1" stopOpacity={0.25}/>
                  <stop offset="95%" stopColor="#66FCF1" stopOpacity={0}/>
                </linearGradient>
                <linearGradient id="colorR510Ram" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="5%" stopColor="#45A29E" stopOpacity={0.25}/>
                  <stop offset="95%" stopColor="#45A29E" stopOpacity={0}/>
                </linearGradient>
              </defs>
              <CartesianGrid stroke="#2C3539" strokeDasharray="3 3" opacity={0.3} />
              <XAxis dataKey="timestamp" tickFormatter={formatXAxis} tick={{ fill: '#8A939E', fontSize: 10 }} />
              <YAxis domain={[0, 100]} tick={{ fill: '#8A939E', fontSize: 10 }} />
              <Tooltip content={<CustomTooltip />} />
              <Legend verticalAlign="top" height={36} iconType="circle" wrapperStyle={{ fontSize: 11 }} />
              <Area type="monotone" name="T310 RAM" dataKey="t310_ram" stroke="#66FCF1" strokeWidth={2} fillOpacity={1} fill="url(#colorT310Ram)" unit="%" />
              <Area type="monotone" name="R510 RAM" dataKey="r510_ram" stroke="#45A29E" strokeWidth={2} fillOpacity={1} fill="url(#colorR510Ram)" unit="%" />
            </AreaChart>
          </ResponsiveContainer>
        </div>

        {/* Graph 3: Network I/O Throughput */}
        <div className="bg-black/20 p-4 rounded-xl border border-dashboard-border/30 h-72">
          <h4 className="text-xs font-mono font-bold text-dashboard-accent uppercase mb-4 tracking-widest">T310 NETWORK SPEED (RX / TX)</h4>
          <ResponsiveContainer width="100%" height="85%">
            <AreaChart data={metrics} margin={{ top: 5, right: 5, left: -20, bottom: 5 }}>
              <defs>
                <linearGradient id="colorRx" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="5%" stopColor="#10B981" stopOpacity={0.25}/>
                  <stop offset="95%" stopColor="#10B981" stopOpacity={0}/>
                </linearGradient>
                <linearGradient id="colorTx" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="5%" stopColor="#3B82F6" stopOpacity={0.25}/>
                  <stop offset="95%" stopColor="#3B82F6" stopOpacity={0}/>
                </linearGradient>
              </defs>
              <CartesianGrid stroke="#2C3539" strokeDasharray="3 3" opacity={0.3} />
              <XAxis dataKey="timestamp" tickFormatter={formatXAxis} tick={{ fill: '#8A939E', fontSize: 10 }} />
              <YAxis tick={{ fill: '#8A939E', fontSize: 10 }} />
              <Tooltip content={<CustomTooltip />} />
              <Legend verticalAlign="top" height={36} iconType="circle" wrapperStyle={{ fontSize: 11 }} />
              <Area type="monotone" name="Download (RX)" dataKey="network_rx" stroke="#10B981" strokeWidth={2} fillOpacity={1} fill="url(#colorRx)" unit=" KB/s" />
              <Area type="monotone" name="Upload (TX)" dataKey="network_tx" stroke="#3B82F6" strokeWidth={2} fillOpacity={1} fill="url(#colorTx)" unit=" KB/s" />
            </AreaChart>
          </ResponsiveContainer>
        </div>

        {/* Graph 4: Article Ingest Rate vs AI Inference Counts */}
        <div className="bg-black/20 p-4 rounded-xl border border-dashboard-border/30 h-72">
          <h4 className="text-xs font-mono font-bold text-dashboard-accent uppercase mb-4 tracking-widest">ARTICLE PROCESSING RATE vs AI INFERENCE VOL</h4>
          <ResponsiveContainer width="100%" height="85%">
            <AreaChart data={metrics} margin={{ top: 5, right: 5, left: -20, bottom: 5 }}>
              <defs>
                <linearGradient id="colorProc" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="5%" stopColor="#F59E0B" stopOpacity={0.25}/>
                  <stop offset="95%" stopColor="#F59E0B" stopOpacity={0}/>
                </linearGradient>
                <linearGradient id="colorAi" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="5%" stopColor="#66FCF1" stopOpacity={0.25}/>
                  <stop offset="95%" stopColor="#66FCF1" stopOpacity={0}/>
                </linearGradient>
              </defs>
              <CartesianGrid stroke="#2C3539" strokeDasharray="3 3" opacity={0.3} />
              <XAxis dataKey="timestamp" tickFormatter={formatXAxis} tick={{ fill: '#8A939E', fontSize: 10 }} />
              <YAxis tick={{ fill: '#8A939E', fontSize: 10 }} />
              <Tooltip content={<CustomTooltip />} />
              <Legend verticalAlign="top" height={36} iconType="circle" wrapperStyle={{ fontSize: 11 }} />
              <Area type="monotone" name="Ingest Speed" dataKey="processing_rate" stroke="#F59E0B" strokeWidth={2} fillOpacity={1} fill="url(#colorProc)" unit=" articles/h" />
              <Area type="monotone" name="AI Requests" dataKey="ai_volume" stroke="#66FCF1" strokeWidth={2} fillOpacity={1} fill="url(#colorAi)" unit=" request(s)" />
            </AreaChart>
          </ResponsiveContainer>
        </div>

      </div>
    </div>
  );
};
