import React, { useEffect, useState } from "react";
import { LogOut } from "lucide-react";

interface HeaderProps {
  healthScore: number;
  status: string;
  uptime: string;
  user: { username: string; role: string } | null;
  onLogout: () => void;
}

export const Header: React.FC<HeaderProps> = ({ healthScore, status, uptime, user, onLogout }) => {
  const [timeStr, setTimeStr] = useState("");

  useEffect(() => {
    const update = () => {
      const now = new Date();
      setTimeStr(now.toLocaleTimeString("en-US", { hour12: false }));
    };
    update();
    const iv = setInterval(update, 1000);
    return () => clearInterval(iv);
  }, []);

  const scoreColor = healthScore >= 90 ? "#00ff87" : healthScore >= 50 ? "#ffd166" : "#ef233c";

  return (
    <header style={{ background: "#0f0f0f", borderBottom: "1px solid rgba(255,255,255,0.05)" }}
      className="px-8 py-4 flex items-center justify-between select-none">
      {/* Brand */}
      <div>
        <div className="metro-label" style={{ color: "var(--metro-accent)", marginBottom: 2 }}>
          P3 OPERATIONS CENTER
        </div>
        <div style={{ fontSize: "0.75rem", color: "rgba(255,255,255,0.3)", fontWeight: 300 }}>
          bitcoin · intelligence · noc
        </div>
      </div>

      {/* Center: live score */}
      <div className="hidden md:flex items-center gap-8">
        <div className="text-center">
          <div className="metro-label">health</div>
          <div style={{ fontSize: "1.75rem", fontWeight: 700, color: scoreColor, lineHeight: 1 }}>
            {healthScore}<span style={{ fontSize: "1rem", fontWeight: 300 }}>%</span>
          </div>
        </div>
        <div className="text-center">
          <div className="metro-label">status</div>
          <div style={{ fontSize: "1rem", fontWeight: 600, color: "#fff", lineHeight: 1.2 }}>{status}</div>
        </div>
        <div className="text-center">
          <div className="metro-label">uptime</div>
          <div style={{ fontSize: "1rem", fontWeight: 600, color: "#fff", lineHeight: 1.2 }}>{uptime}</div>
        </div>
      </div>

      {/* Right: clock + user */}
      <div className="flex items-center gap-6">
        <div style={{ fontSize: "1.5rem", fontWeight: 200, color: "rgba(255,255,255,0.6)", fontVariantNumeric: "tabular-nums" }}>
          {timeStr}
        </div>
        {user && (
          <div className="flex items-center gap-3">
            <div>
              <div style={{ fontSize: "0.875rem", fontWeight: 600, color: "#fff" }}>{user.username}</div>
              <div className="metro-label">{user.role}</div>
            </div>
            <button onClick={onLogout} title="Sign out"
              style={{ background: "transparent", border: "none", color: "rgba(255,255,255,0.3)", cursor: "pointer", padding: "4px" }}
              className="hover:text-white transition-colors">
              <LogOut size={18} />
            </button>
          </div>
        )}
      </div>
    </header>
  );
};
