import React from "react";
import { AlertOctagon, AlertTriangle, Info, Terminal, RefreshCw } from "lucide-react";

interface AlertsPanelProps {
  alerts: {
    critical: string[];
    warning: string[];
    info: string[];
    logs: any[];
  };
  onRefresh: () => void;
}

export const AlertsPanel: React.FC<AlertsPanelProps> = ({ alerts, onRefresh }) => {
  const allAlertsCount = alerts.critical.length + alerts.warning.length + alerts.info.length;

  const getSeverityStyle = (sev: string) => {
    switch (sev.toUpperCase()) {
      case "CRITICAL":
        return "text-rose-400 font-bold";
      case "WARNING":
        return "text-amber-400 font-semibold";
      default:
        return "text-sky-400";
    }
  };

  const getResultStyle = (res: string) => {
    if (res === "SUCCESS") return "text-emerald-400";
    if (res === "FAILED") return "text-rose-500 font-bold";
    return "text-amber-400 animate-pulse";
  };

  return (
    <div className="grid grid-cols-1 lg:grid-cols-3 gap-6 select-none">
      
      {/* Left Column: Active Incidents Registry */}
      <div className="lg:col-span-1 glass-panel rounded-xl p-6 border border-dashboard-border flex flex-col h-[600px]">
        <div className="flex items-center justify-between border-b border-dashboard-border pb-4 mb-4">
          <div className="flex items-center gap-2">
            <AlertOctagon className="w-5 h-5 text-dashboard-critical animate-pulse" />
            <h3 className="text-sm font-bold font-digital tracking-wider text-white">INCIDENTS REGISTER</h3>
          </div>
          <span className="bg-rose-500/20 text-rose-400 border border-rose-500/30 text-xs px-2.5 py-0.5 rounded-full font-bold font-digital">
            {allAlertsCount} ACTIVE
          </span>
        </div>

        {/* Scrollable Alerts feed */}
        <div className="flex-1 overflow-y-auto space-y-4 pr-1">
          {allAlertsCount === 0 && (
            <div className="h-full flex flex-col items-center justify-center text-center text-gray-500 font-mono text-sm">
              <span className="text-3xl mb-2">🟢</span>
              <p>NO ACTIVE INCIDENTS</p>
              <p className="text-xs text-dashboard-accent opacity-60">All modules running normal</p>
            </div>
          )}

          {/* Critical alerts */}
          {alerts.critical.map((item, idx) => (
            <div key={`crit-${idx}`} className="p-3.5 rounded-lg border border-rose-500/30 bg-rose-950/15 flex items-start gap-3 shadow-glow-critical animate-pulse">
              <AlertOctagon className="w-5 h-5 text-rose-400 shrink-0 mt-0.5" />
              <div>
                <p className="text-xs font-mono font-bold text-rose-300 uppercase tracking-wide">CRITICAL ALARM</p>
                <p className="text-sm text-white font-semibold font-sans mt-0.5">{item}</p>
              </div>
            </div>
          ))}

          {/* Warning alerts */}
          {alerts.warning.map((item, idx) => (
            <div key={`warn-${idx}`} className="p-3.5 rounded-lg border border-amber-500/30 bg-amber-950/15 flex items-start gap-3 shadow-glow-warning">
              <AlertTriangle className="w-5 h-5 text-amber-400 shrink-0 mt-0.5" />
              <div>
                <p className="text-xs font-mono font-bold text-amber-300 uppercase tracking-wide">WARNING ALERT</p>
                <p className="text-sm text-white font-semibold font-sans mt-0.5">{item}</p>
              </div>
            </div>
          ))}

          {/* Info alerts */}
          {alerts.info.map((item, idx) => (
            <div key={`info-${idx}`} className="p-3.5 rounded-lg border border-sky-500/30 bg-sky-950/15 flex items-start gap-3">
              <Info className="w-5 h-5 text-sky-400 shrink-0 mt-0.5" />
              <div>
                <p className="text-xs font-mono font-bold text-sky-300 uppercase tracking-wide">SYSTEM DIAGNOSTIC</p>
                <p className="text-sm text-white font-semibold font-sans mt-0.5">{item}</p>
              </div>
            </div>
          ))}
        </div>
      </div>

      {/* Right Column: Terminal Operations Logs Console */}
      <div className="lg:col-span-2 glass-panel rounded-xl p-6 border border-dashboard-border flex flex-col h-[600px]">
        <div className="flex items-center justify-between border-b border-dashboard-border pb-4 mb-4">
          <div className="flex items-center gap-2.5">
            <Terminal className="w-5 h-5 text-dashboard-neon" />
            <h3 className="text-sm font-bold font-digital tracking-wider text-white">OPERATIONAL LOG JOURNAL</h3>
          </div>
          <button
            onClick={onRefresh}
            className="flex items-center gap-1.5 px-3 py-1.5 rounded bg-black/40 border border-dashboard-border text-xs text-dashboard-accent hover:text-dashboard-neon font-digital transition-all"
            title="Refresh logs journal"
          >
            <RefreshCw className="w-3.5 h-3.5" />
            <span>SYNC JOURNAL</span>
          </button>
        </div>

        {/* CRT Log viewport */}
        <div className="flex-1 bg-black/50 border border-dashboard-border/80 rounded-lg p-4 font-mono text-xs overflow-y-auto space-y-2.5 select-text shadow-inner">
          <div className="text-dashboard-accent border-b border-dashboard-border/30 pb-2 mb-2 flex justify-between uppercase opacity-65 text-[10px] tracking-widest">
            <span>[TIMESTAMP UTC] -- EVENT & OPERATION DETAILS</span>
            <span>RESULT</span>
          </div>

          {alerts.logs.length === 0 ? (
            <div className="h-full flex items-center justify-center text-gray-600">
              NO OPERATIONS LOGGED IN DATABASE
            </div>
          ) : (
            alerts.logs.map((log) => (
              <div key={log.id} className="flex items-start justify-between gap-4 border-b border-dashboard-border/10 pb-1.5 hover:bg-white/5 transition-all">
                <div className="flex-1 truncate">
                  <span className="text-gray-500 mr-2">[{log.timestamp.slice(11, 19)}]</span>
                  <span className={`uppercase font-bold mr-2 ${getSeverityStyle(log.severity)}`}>
                    [{log.severity}]
                  </span>
                  <span className="text-gray-300 font-sans mr-2 font-medium">{log.event}</span>
                  {log.action_taken && (
                    <span className="text-dashboard-accent text-[11px] italic">
                      (Action: {log.action_taken})
                    </span>
                  )}
                </div>
                <div className="shrink-0 font-digital font-bold text-right pl-2">
                  <span className={getResultStyle(log.result)}>{log.result}</span>
                </div>
              </div>
            ))
          )}
        </div>
      </div>

    </div>
  );
};
