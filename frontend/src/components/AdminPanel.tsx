import React, { useState } from "react";
import { Terminal, ShieldCheck, ShieldAlert, Zap, Loader2, PlayCircle, RefreshCw, Trash2, HelpCircle } from "lucide-react";
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

export const AdminPanel: React.FC<AdminPanelProps> = ({
  status,
  token,
  onActionCompleted,
}) => {
  const [loadingAction, setLoadingAction] = useState<string | null>(null);
  const [responseMsg, setResponseMsg] = useState<{ type: "success" | "error"; text: string } | null>(null);

  const handleAction = async (actionPath: string, label: string) => {
    setLoadingAction(actionPath);
    setResponseMsg(null);
    try {
      const res = await axios.post(
        `/api/recovery/${actionPath}`,
        {},
        {
          headers: { Authorization: `Bearer ${token}` },
        }
      );
      setResponseMsg({
        type: "success",
        text: res.data.message || `Manual operation [${label}] succeeded.`,
      });
      onActionCompleted();
    } catch (err: any) {
      console.error(err);
      setResponseMsg({
        type: "error",
        text: err.response?.data?.detail || `Failed to execute operation [${label}].`,
      });
    } finally {
      setLoadingAction(null);
    }
  };

  const actions = [
    { path: "restart-worker", label: "Restart Ingest Worker", icon: PlayCircle, desc: "Restarts the background systemd parsing node worker" },
    { path: "restart-ingest", label: "Restart Ingest Timer", icon: RefreshCw, desc: "Restarts the chron RSS article ingester scheduler" },
    { path: "requeue-failed", label: "Requeue Failed Items", icon: Zap, desc: "Resets queue statuses from failed -> pending in Postgres" },
    { path: "clear-stuck", label: "Clear Stuck Processing", icon: Trash2, desc: "Clears tasks stuck in 'processing' status > 15 minutes" },
    { path: "restart-ollama", label: "Restart Ollama Service", icon: PlayCircle, desc: "Attempts remote model backend service systemctl restart" },
    { path: "warm-model", label: "Pre-Warm Ollama Model", icon: Zap, desc: "Triggers model memory warming on R510 remote node" },
  ];

  return (
    <div className="grid grid-cols-1 lg:grid-cols-3 gap-6 select-none">
      
      {/* Column 1: Autopilot Control Console */}
      <div className="lg:col-span-1 glass-panel rounded-xl p-6 border border-dashboard-border flex flex-col justify-between h-[450px] relative overflow-hidden">
        <div className="absolute top-0 left-0 right-0 h-0.5 bg-dashboard-neon/30" />
        
        <div>
          <div className="flex items-center gap-2.5 border-b border-dashboard-border pb-4 mb-5">
            <Zap className="w-5 h-5 text-dashboard-neon" />
            <h3 className="text-sm font-bold font-digital tracking-wider text-white">AUTOPILOT CONTROLLER</h3>
          </div>

          <div className="space-y-5">
            {/* Status readouts */}
            <div className="flex justify-between items-center bg-black/35 p-3 rounded-lg border border-dashboard-border/30">
              <span className="text-xs font-mono text-dashboard-accent">AUTOPILOT STATE:</span>
              <span className={`text-sm font-bold font-digital flex items-center gap-1.5 ${
                status.autopilot_locked ? "text-rose-500 shadow-glow-critical animate-pulse" : "text-emerald-400"
              }`}>
                {status.autopilot_locked ? <ShieldAlert className="w-4.5 h-4.5" /> : <ShieldCheck className="w-4.5 h-4.5" />}
                {status.overall_status}
              </span>
            </div>

            <div className="flex justify-between items-center bg-black/35 p-3 rounded-lg border border-dashboard-border/30">
              <span className="text-xs font-mono text-dashboard-accent">SAFE MODE:</span>
              <span className={`text-xs font-mono font-bold ${status.autopilot_safe_mode ? "text-amber-400" : "text-gray-500"}`}>
                {status.autopilot_safe_mode ? "ACTIVE (ROUTING ENFORCED)" : "INACTIVE"}
              </span>
            </div>

            <div className="flex justify-between items-center bg-black/35 p-3 rounded-lg border border-dashboard-border/30">
              <span className="text-xs font-mono text-dashboard-accent">HEALTH COEFFICIENT:</span>
              <span className="text-lg font-bold font-digital text-white">{status.overall_health_score}%</span>
            </div>
          </div>
        </div>

        {/* Lock override buttons */}
        <div className="pt-6 border-t border-dashboard-border/50">
          <button
            onClick={() => handleAction("unlock", "Unlock Autopilot")}
            disabled={!status.autopilot_locked && !status.autopilot_safe_mode || loadingAction !== null}
            className={`w-full py-3.5 rounded-lg font-digital font-bold uppercase tracking-wider text-xs border transition-all duration-300 ${
              status.autopilot_locked || status.autopilot_safe_mode
                ? "bg-rose-500/20 text-rose-400 border-rose-500/40 hover:bg-rose-500/30 shadow-glow-critical cursor-pointer"
                : "bg-transparent text-gray-600 border-gray-800 cursor-not-allowed"
            }`}
          >
            {loadingAction === "unlock" ? (
              <span className="flex items-center justify-center gap-2">
                <Loader2 className="w-4.5 h-4.5 animate-spin" /> BYPASSING LOCK...
              </span>
            ) : (
              "BYPASS SAFELOCK OVERRIDE"
            )}
          </button>
          <p className="text-[10px] text-dashboard-accent font-mono mt-2 text-center opacity-65">
            Operator authorization required. Unlocks self-healing systems.
          </p>
        </div>
      </div>

      {/* Column 2 & 3: Manual Control Deck */}
      <div className="lg:col-span-2 glass-panel rounded-xl p-6 border border-dashboard-border flex flex-col h-[450px]">
        <div className="flex items-center gap-2.5 border-b border-dashboard-border pb-4 mb-4">
          <Terminal className="w-5 h-5 text-dashboard-accent" />
          <h3 className="text-sm font-bold font-digital tracking-wider text-white">MANUAL RECOVERY INTERFACE</h3>
        </div>

        {responseMsg && (
          <div className={`mb-4 p-3 rounded border text-xs font-mono text-center ${
            responseMsg.type === "success"
              ? "border-emerald-500/30 bg-emerald-950/20 text-emerald-400"
              : "border-rose-500/30 bg-rose-950/20 text-rose-400"
          }`}>
            {responseMsg.text}
          </div>
        )}

        {/* Buttons grid */}
        <div className="flex-1 overflow-y-auto grid grid-cols-1 md:grid-cols-2 gap-4 pr-1">
          {actions.map((act) => {
            const Icon = act.icon;
            const isRunning = loadingAction === act.path;
            return (
              <div
                key={act.path}
                className="p-3 bg-black/20 hover:bg-black/40 rounded-lg border border-dashboard-border/30 hover:border-dashboard-accent/30 flex flex-col justify-between transition-all"
              >
                <div>
                  <h4 className="text-xs font-mono font-bold text-white uppercase tracking-wider flex items-center gap-1.5">
                    <Icon className="w-3.5 h-3.5 text-dashboard-accent" />
                    {act.label}
                  </h4>
                  <p className="text-[11px] text-dashboard-accent font-sans mt-1 opacity-80">{act.desc}</p>
                </div>

                <div className="mt-3.5 flex justify-end">
                  <button
                    onClick={() => handleAction(act.path, act.label)}
                    disabled={loadingAction !== null}
                    className="px-3.5 py-1.5 bg-dashboard-accent/10 hover:bg-dashboard-neon text-dashboard-accent hover:text-black border border-dashboard-accent/30 hover:border-transparent rounded text-xs font-semibold font-digital tracking-wider transition-all disabled:opacity-40 disabled:cursor-not-allowed"
                  >
                    {isRunning ? (
                      <span className="flex items-center gap-1">
                        <Loader2 className="w-3.5 h-3.5 animate-spin" /> EXECUTING
                      </span>
                    ) : (
                      "TRIGGER OPERATION"
                    )}
                  </button>
                </div>
              </div>
            );
          })}
        </div>
      </div>

    </div>
  );
};
