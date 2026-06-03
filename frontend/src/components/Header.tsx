import React, { useEffect, useState } from "react";
import { Activity, ShieldAlert, Clock, LogOut, Server } from "lucide-react";

interface HeaderProps {
  healthScore: number;
  status: string;
  uptime: string;
  user: { username: string; role: string } | null;
  onLogout: () => void;
}

export const Header: React.FC<HeaderProps> = ({
  healthScore,
  status,
  uptime,
  user,
  onLogout,
}) => {
  const [timeStr, setTimeStr] = useState<string>("");

  useEffect(() => {
    const updateTime = () => {
      const now = new Date();
      setTimeStr(now.toLocaleTimeString("en-US", { hour12: false }));
    };
    updateTime();
    const interval = setInterval(updateTime, 1000);
    return () => clearInterval(interval);
  }, []);

  const getScoreColorClass = (score: number) => {
    if (score >= 90) return "text-emerald-400 border-emerald-400 bg-emerald-950/40";
    if (score >= 50) return "text-amber-400 border-amber-400 bg-amber-950/40";
    return "text-rose-500 border-rose-500 bg-rose-950/40";
  };

  const getScoreGlowClass = (score: number) => {
    if (score >= 90) return "shadow-glow-healthy";
    if (score >= 50) return "shadow-glow-warning";
    return "shadow-glow-critical";
  };

  return (
    <header className="glass-panel border-b border-dashboard-border px-6 py-4 flex flex-col md:flex-row items-center justify-between gap-4 select-none">
      {/* Brand Logo */}
      <div className="flex items-center gap-3">
        <div className="bg-dashboard-neon/10 p-2 rounded-lg border border-dashboard-neon/30">
          <Server className="w-6 h-6 text-dashboard-neon" />
        </div>
        <div>
          <h1 className="text-xl font-bold tracking-wider text-white font-digital">
            P3 OPERATIONS CENTER
          </h1>
          <p className="text-xs text-dashboard-accent tracking-widest font-mono">
            NOC COMMAND SYSTEM v1.0
          </p>
        </div>
      </div>

      {/* Center Status Indicators */}
      <div className="flex items-center flex-wrap justify-center gap-6">
        {/* Overall Health Score */}
        <div className="flex items-center gap-3">
          <div
            className={`px-3 py-1.5 rounded border font-digital text-lg font-bold flex items-center gap-2 transition-all duration-300 ${getScoreColorClass(
              healthScore
            )} ${getScoreGlowClass(healthScore)}`}
          >
            <Activity className="w-5 h-5 animate-pulse" />
            <span>SYS HEALTH: {healthScore}%</span>
          </div>
          <span className="text-xs text-dashboard-accent uppercase font-mono hidden lg:inline">
            Status: {status}
          </span>
        </div>

        {/* Uptime */}
        <div className="flex items-center gap-2 text-sm text-gray-300 font-mono">
          <span className="text-dashboard-accent">UPTIME:</span>
          <span className="text-white">{uptime}</span>
        </div>
      </div>

      {/* Right Clock & Logged-in User */}
      <div className="flex items-center gap-5">
        {/* Digital Clock */}
        <div className="flex items-center gap-2 text-dashboard-neon font-digital text-lg bg-black/40 px-3 py-1.5 rounded border border-dashboard-border">
          <Clock className="w-4 h-4" />
          <span>{timeStr}</span>
        </div>

        {/* User Card */}
        {user && (
          <div className="flex items-center gap-3 pl-4 border-l border-dashboard-border">
            <div className="text-right">
              <p className="text-sm font-semibold text-white">{user.username}</p>
              <p className="text-xs text-dashboard-accent uppercase font-mono tracking-wider">
                {user.role}
              </p>
            </div>
            <button
              onClick={onLogout}
              className="bg-transparent hover:bg-rose-950/30 text-gray-400 hover:text-rose-400 p-2 rounded-lg border border-transparent hover:border-rose-950 transition-colors"
              title="Logout session"
            >
              <LogOut className="w-5 h-5" />
            </button>
          </div>
        )}
      </div>
    </header>
  );
};
