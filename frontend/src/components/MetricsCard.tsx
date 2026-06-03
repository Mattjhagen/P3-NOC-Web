import React from "react";
import { Server, Cpu, Database, Network, CircleDot, HardDrive, ShieldCheck, ShieldAlert } from "lucide-react";

interface MetricsCardProps {
  t310: any;
  r510: any;
  queueCounts: any;
}

export const MetricsCard: React.FC<MetricsCardProps> = ({ t310, r510, queueCounts }) => {
  const t310CPU = t310?.cpu_percent ?? 0.0;
  const t310RAM = t310?.ram_percent ?? 0.0;
  const t310Disk = t310?.disk_percent ?? 0.0;
  
  const r510CPU = r510?.cpu_percent ?? 0.0;
  const r510RAM = r510?.ram_percent ?? 0.0;

  const getPercentageColor = (val: number) => {
    if (val >= 85) return "bg-rose-500 shadow-glow-critical";
    if (val >= 60) return "bg-amber-500 shadow-glow-warning";
    return "bg-emerald-400 shadow-glow-healthy";
  };

  const getPercentageTextColor = (val: number) => {
    if (val >= 85) return "text-rose-400";
    if (val >= 60) return "text-amber-400";
    return "text-emerald-400";
  };

  return (
    <div className="grid grid-cols-1 xl:grid-cols-2 gap-6 select-none">
      
      {/* T310 NOC Server Status Card */}
      <div className="glass-panel rounded-xl p-6 border border-dashboard-border relative overflow-hidden">
        <div className="absolute top-0 left-0 right-0 h-0.5 bg-dashboard-neon/40" />
        
        {/* Card Title Header */}
        <div className="flex items-center justify-between mb-6 pb-4 border-b border-dashboard-border">
          <div className="flex items-center gap-3">
            <div className="bg-dashboard-neon/10 p-2 rounded-lg">
              <Server className="w-5 h-5 text-dashboard-neon" />
            </div>
            <div>
              <h3 className="text-md font-bold font-digital tracking-wider text-white">DELL PowerEdge T310</h3>
              <p className="text-xs text-dashboard-accent font-mono tracking-widest uppercase">NOC Server / Master Node</p>
            </div>
          </div>
          <div className="flex items-center gap-2">
            <span className="w-2.5 h-2.5 rounded-full bg-emerald-500 status-beacon inline-block" />
            <span className="text-xs font-semibold text-emerald-400 uppercase font-mono font-bold">ONLINE</span>
          </div>
        </div>

        {/* System parameters grid */}
        <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-6">
          {/* CPU Metric */}
          <div className="bg-black/20 p-4 rounded-lg border border-dashboard-border/30">
            <div className="flex items-center justify-between text-xs text-dashboard-accent font-mono mb-2">
              <span className="flex items-center gap-1"><Cpu className="w-3.5 h-3.5" /> CPU LOAD</span>
              <span className={`font-semibold ${getPercentageTextColor(t310CPU)} font-digital`}>{t310CPU}%</span>
            </div>
            <div className="w-full bg-gray-900 rounded-full h-2 overflow-hidden">
              <div className={`h-full transition-all duration-500 ${getPercentageColor(t310CPU)}`} style={{ width: `${t310CPU}%` }} />
            </div>
          </div>

          {/* Memory Metric */}
          <div className="bg-black/20 p-4 rounded-lg border border-dashboard-border/30">
            <div className="flex items-center justify-between text-xs text-dashboard-accent font-mono mb-2">
              <span className="flex items-center gap-1"><CircleDot className="w-3.5 h-3.5" /> RAM USAGE</span>
              <span className={`font-semibold ${getPercentageTextColor(t310RAM)} font-digital`}>{t310RAM}%</span>
            </div>
            <div className="w-full bg-gray-900 rounded-full h-2 overflow-hidden">
              <div className={`h-full transition-all duration-500 ${getPercentageColor(t310RAM)}`} style={{ width: `${t310RAM}%` }} />
            </div>
          </div>

          {/* Disk Metric */}
          <div className="bg-black/20 p-4 rounded-lg border border-dashboard-border/30">
            <div className="flex items-center justify-between text-xs text-dashboard-accent font-mono mb-2">
              <span className="flex items-center gap-1"><HardDrive className="w-3.5 h-3.5" /> DISK SPACE</span>
              <span className={`font-semibold ${getPercentageTextColor(t310Disk)} font-digital`}>{t310Disk}%</span>
            </div>
            <div className="w-full bg-gray-900 rounded-full h-2 overflow-hidden">
              <div className={`h-full transition-all duration-500 ${getPercentageColor(t310Disk)}`} style={{ width: `${t310Disk}%` }} />
            </div>
          </div>
        </div>

        {/* Details and networking speeds */}
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4 text-xs font-mono">
          <div className="space-y-2.5 bg-black/10 p-3 rounded-lg border border-dashboard-border/20">
            <div className="flex justify-between border-b border-dashboard-border/20 pb-1.5">
              <span className="text-dashboard-accent">NETWORK IN (RX):</span>
              <span className="text-white flex items-center gap-1"><Network className="w-3 h-3 text-dashboard-accent" /> {t310?.network_rx_kbps ?? 0} KB/s</span>
            </div>
            <div className="flex justify-between border-b border-dashboard-border/20 pb-1.5">
              <span className="text-dashboard-accent">NETWORK OUT (TX):</span>
              <span className="text-white flex items-center gap-1"><Network className="w-3 h-3 text-dashboard-accent" /> {t310?.network_tx_kbps ?? 0} KB/s</span>
            </div>
            <div className="flex justify-between">
              <span className="text-dashboard-accent">LOAD AVERAGE:</span>
              <span className="text-white font-digital">{t310?.load_avg?.join("  ") ?? "0.00 0.00 0.00"}</span>
            </div>
          </div>

          <div className="space-y-2.5 bg-black/10 p-3 rounded-lg border border-dashboard-border/20">
            <div className="flex justify-between border-b border-dashboard-border/20 pb-1.5">
              <span className="text-dashboard-accent">BITCOIN WORKER:</span>
              <span className="flex items-center gap-1 text-emerald-400 font-semibold font-digital">
                <CircleDot className="w-3 h-3 animate-ping" /> RUNNING
              </span>
            </div>
            <div className="flex justify-between border-b border-dashboard-border/20 pb-1.5">
              <span className="text-dashboard-accent">POSTGRES HEALTH:</span>
              <span className={`font-semibold font-digital flex items-center gap-1 ${t310?.postgres_running ? 'text-emerald-400' : 'text-emerald-400'}`}>
                <Database className="w-3 h-3" /> ONLINE
              </span>
            </div>
            <div className="flex justify-between">
              <span className="text-dashboard-accent">QUEUE DEPTH:</span>
              <span className="text-dashboard-neon font-digital font-bold">{queueCounts?.pending ?? 0} pending | {queueCounts?.processing ?? 0} active</span>
            </div>
          </div>
        </div>
      </div>

      {/* R510 AI Server Status Card */}
      <div className="glass-panel rounded-xl p-6 border border-dashboard-border relative overflow-hidden">
        <div className="absolute top-0 left-0 right-0 h-0.5 bg-dashboard-accent/40" />

        {/* Card Title Header */}
        <div className="flex items-center justify-between mb-6 pb-4 border-b border-dashboard-border">
          <div className="flex items-center gap-3">
            <div className="bg-dashboard-accent/10 p-2 rounded-lg">
              <Server className="w-5 h-5 text-dashboard-accent" />
            </div>
            <div>
              <h3 className="text-md font-bold font-digital tracking-wider text-white">DELL PowerEdge R510</h3>
              <p className="text-xs text-dashboard-accent font-mono tracking-widest uppercase">AI inference Server / Ollama Node</p>
            </div>
          </div>
          <div className="flex items-center gap-2">
            <span className={`w-2.5 h-2.5 rounded-full status-beacon inline-block ${r510?.online ? 'bg-emerald-500' : 'bg-rose-500'}`} />
            <span className={`text-xs font-semibold uppercase font-mono font-bold ${r510?.online ? 'text-emerald-400' : 'text-rose-500'}`}>
              {r510?.online ? "ONLINE" : "OFFLINE"}
            </span>
          </div>
        </div>

        {/* System parameters grid */}
        <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-6">
          {/* CPU Metric */}
          <div className="bg-black/20 p-4 rounded-lg border border-dashboard-border/30">
            <div className="flex items-center justify-between text-xs text-dashboard-accent font-mono mb-2">
              <span className="flex items-center gap-1"><Cpu className="w-3.5 h-3.5" /> CPU LOAD</span>
              <span className={`font-semibold ${getPercentageTextColor(r510CPU)} font-digital`}>{r510CPU}%</span>
            </div>
            <div className="w-full bg-gray-900 rounded-full h-2 overflow-hidden">
              <div className={`h-full transition-all duration-500 ${getPercentageColor(r510CPU)}`} style={{ width: `${r510CPU}%` }} />
            </div>
          </div>

          {/* Memory Metric */}
          <div className="bg-black/20 p-4 rounded-lg border border-dashboard-border/30">
            <div className="flex items-center justify-between text-xs text-dashboard-accent font-mono mb-2">
              <span className="flex items-center gap-1"><CircleDot className="w-3.5 h-3.5" /> RAM USAGE</span>
              <span className={`font-semibold ${getPercentageTextColor(r510RAM)} font-digital`}>{r510RAM}%</span>
            </div>
            <div className="w-full bg-gray-900 rounded-full h-2 overflow-hidden">
              <div className={`h-full transition-all duration-500 ${getPercentageColor(r510RAM)}`} style={{ width: `${r510RAM}%` }} />
            </div>
          </div>

          {/* Ping Latency Metric */}
          <div className="bg-black/20 p-4 rounded-lg border border-dashboard-border/30 flex flex-col justify-center">
            <span className="text-[10px] text-dashboard-accent font-mono uppercase tracking-wider block mb-1">PING RESPONSE</span>
            <span className="text-xl font-bold font-digital text-dashboard-neon">
              {r510?.online ? `${r510?.ping_latency_ms ?? 0} ms` : "TIMEOUT"}
            </span>
          </div>
        </div>

        {/* Details and networking speeds */}
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4 text-xs font-mono">
          <div className="space-y-2.5 bg-black/10 p-3 rounded-lg border border-dashboard-border/20">
            <div className="flex justify-between border-b border-dashboard-border/20 pb-1.5">
              <span className="text-dashboard-accent">SSH PORT (22):</span>
              <span className={`font-semibold font-digital flex items-center gap-1 ${r510?.ssh_status === 'ONLINE' ? 'text-emerald-400' : 'text-rose-500'}`}>
                {r510?.ssh_status === 'ONLINE' ? <ShieldCheck className="w-3.5 h-3.5" /> : <ShieldAlert className="w-3.5 h-3.5" />}
                {r510?.ssh_status}
              </span>
            </div>
            <div className="flex justify-between border-b border-dashboard-border/20 pb-1.5">
              <span className="text-dashboard-accent">OLLAMA PORT (11434):</span>
              <span className={`font-semibold font-digital flex items-center gap-1 ${r510?.ollama_status === 'ONLINE' ? 'text-emerald-400' : 'text-rose-500'}`}>
                {r510?.ollama_status === 'ONLINE' ? <ShieldCheck className="w-3.5 h-3.5" /> : <ShieldAlert className="w-3.5 h-3.5" />}
                {r510?.ollama_status}
              </span>
            </div>
            <div className="flex justify-between">
              <span className="text-dashboard-accent">ACTIVE RUNNING MODEL:</span>
              <span className="text-white font-digital font-semibold truncate max-w-[150px]" title={r510?.active_model ?? "None"}>
                {r510?.active_model ?? "None"}
              </span>
            </div>
          </div>

          <div className="space-y-2.5 bg-black/10 p-3 rounded-lg border border-dashboard-border/20">
            <div className="flex justify-between border-b border-dashboard-border/20 pb-1.5">
              <span className="text-dashboard-accent">LOADED MODEL VRAM:</span>
              <span className="text-dashboard-neon font-digital font-bold">{r510?.loaded_memory_gb ?? 0.0} GB</span>
            </div>
            <div className="flex justify-between border-b border-dashboard-border/20 pb-1.5">
              <span className="text-dashboard-accent">CONCURRENT INFERENCES:</span>
              <span className="text-white font-digital">{r510?.active_requests ?? 0} request(s)</span>
            </div>
            <div className="flex justify-between">
              <span className="text-dashboard-accent">REMOTE UP-TIMER:</span>
              <span className="text-white">{r510?.online ? (r510?.uptime ?? "N/A") : "OFFLINE"}</span>
            </div>
          </div>
        </div>
      </div>

    </div>
  );
};
