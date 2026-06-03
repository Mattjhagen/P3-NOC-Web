import React, { useState, useEffect } from "react";
import axios from "axios";
import { Header } from "./components/Header";
import { Sidebar } from "./components/Sidebar";
import { Login } from "./components/Login";
import { MetricsCard } from "./components/MetricsCard";
import { ChartsPanel } from "./components/ChartsPanel";
import { AlertsPanel } from "./components/AlertsPanel";
import { AdminPanel } from "./components/AdminPanel";
import { useWebSocket } from "./hooks/useWebSocket";
import { ShieldAlert, Maximize2, Minimize2 } from "lucide-react";

export const App: React.FC = () => {
  // Authentication State
  const [token, setToken] = useState<string | null>(localStorage.getItem("p3_noc_token"));
  const [user, setUser] = useState<{ username: string; role: string } | null>(null);

  // Layout states
  const [activeTab, setActiveTab] = useState<string>("dashboard");
  const [selectedRange, setSelectedRange] = useState<string>("1h");
  const [wallboardMode, setWallboardMode] = useState<boolean>(false);

  // Telemetry telemetry state
  const [telemetry, setTelemetry] = useState<any>(null);
  const [historicalMetrics, setHistoricalMetrics] = useState<any[]>([]);
  const [alerts, setAlerts] = useState<any>({ critical: [], warning: [], info: [], logs: [] });
  const [availableModels, setAvailableModels] = useState<string[]>([]);

  // Axios interceptor helper
  useEffect(() => {
    if (token) {
      axios.defaults.headers.common["Authorization"] = `Bearer ${token}`;
      // Fetch user details
      axios
        .get("/api/auth/me")
        .then((res) => {
          setUser(res.data);
        })
        .catch(() => {
          handleLogout();
        });
    } else {
      delete axios.defaults.headers.common["Authorization"];
      setUser(null);
    }
  }, [token]);

  // Connect WebSocket status subscriber
  const { data: wsData } = useWebSocket("/ws/status", token !== null);

  // Update telemetry values from WebSocket updates
  useEffect(() => {
    if (wsData) {
      setTelemetry(wsData);
      
      // Sync models list from R510 remote status
      if (wsData.r510?.available_models) {
        setAvailableModels(wsData.r510.available_models);
      }
    }
  }, [wsData]);

  // Fetch Rest API data: metrics history and alerts journal
  const fetchData = async () => {
    if (!token) return;
    try {
      // 1. Fetch metrics history for graphs
      const resMetrics = await axios.get(`/api/metrics?range=${selectedRange}`);
      setHistoricalMetrics(resMetrics.data);

      // 2. Fetch alerts log details
      const resAlerts = await axios.get("/api/alerts");
      setAlerts(resAlerts.data);
    } catch (err) {
      console.error("Failed to sync backend metrics REST APIs:", err);
    }
  };

  // Sync REST endpoints regularly
  useEffect(() => {
    fetchData();
    const interval = setInterval(fetchData, 10000); // sync every 10s
    return () => clearInterval(interval);
  }, [token, selectedRange]);

  const handleLoginSuccess = (jwtToken: string, username: string, role: string) => {
    localStorage.setItem("p3_noc_token", jwtToken);
    setToken(jwtToken);
    setUser({ username, role });
  };

  const handleLogout = () => {
    localStorage.removeItem("p3_noc_token");
    setToken(null);
    setUser(null);
  };

  const handleActionCompleted = () => {
    fetchData();
  };

  if (!token) {
    return <Login onLoginSuccess={handleLoginSuccess} />;
  }

  // Count active warnings + critical issues
  const activeAlertCount = 
    (telemetry?.active_issues?.length ?? 0) + 
    (alerts.critical?.length ?? 0) + 
    (alerts.warning?.length ?? 0);

  // Compile overall details
  const healthScore = telemetry?.overall_health_score ?? 100;
  const status = telemetry?.overall_status ?? "HEALTHY";
  const uptime = telemetry?.uptime ?? "N/A";
  const queueCounts = telemetry?.queue_counts ?? { pending: 0, processing: 0, completed: 0, failed: 0 };
  const t310Data = telemetry?.t310 ?? {};
  const r510Data = telemetry?.r510 ?? {};

  return (
    <div className="min-h-screen flex flex-col bg-dashboard-bg text-gray-100 overflow-x-hidden relative">
      
      {/* Wallboard flashing emergency border alert if system health is degraded */}
      {healthScore < 50 && (
        <div className="absolute inset-0 border-4 border-rose-500/20 pointer-events-none animate-pulse z-50" />
      )}

      {/* 1. Header (Hidden in Wallboard Mode) */}
      {!wallboardMode && (
        <Header
          healthScore={healthScore}
          status={status}
          uptime={uptime}
          user={user}
          onLogout={handleLogout}
        />
      )}

      {/* Emergency alert bar */}
      {healthScore < 90 && !wallboardMode && (
        <div className="bg-rose-950/40 border-b border-rose-500/30 px-6 py-2 flex items-center justify-between text-xs font-mono text-rose-400 select-none animate-pulse">
          <span className="flex items-center gap-2">
            <ShieldAlert className="w-4 h-4" />
            <span>CRITICAL OPERATIONS INCIDENT: SYS HEALTH COEFFICIENT AT {healthScore}%. AUDITING SUB-SYSTEMS...</span>
          </span>
          <button onClick={() => setActiveTab("admin")} className="underline font-bold hover:text-white uppercase font-digital">
            OPEN CONTROL DECK
          </button>
        </div>
      )}

      {/* 2. Main Page Grid */}
      <div className="flex-1 flex flex-col md:flex-row relative">
        {/* Sidebar Navigation (Hidden in Wallboard Mode) */}
        {!wallboardMode && (
          <Sidebar
            activeTab={activeTab}
            setActiveTab={setActiveTab}
            activeAlertCount={activeAlertCount}
          />
        )}

        {/* Content Viewport */}
        <main className="flex-1 p-6 space-y-6 overflow-y-auto">
          
          {/* Wallboard Mode Overlay Controller */}
          {wallboardMode ? (
            <div className="flex justify-between items-center mb-4 pb-2 border-b border-dashboard-border select-none">
              <div>
                <h2 className="text-xl font-bold tracking-widest text-white font-digital">P3 NOC WALLBOARD VIEWER</h2>
                <p className="text-[10px] text-dashboard-neon font-digital tracking-widest uppercase">
                  HEALTH SCORE: {healthScore}% | STATUS: {status} | UPTIME: {uptime}
                </p>
              </div>
              <button
                onClick={() => setWallboardMode(false)}
                className="flex items-center gap-1.5 px-3 py-1.5 bg-dashboard-card border border-dashboard-border text-xs text-dashboard-accent hover:text-white font-digital rounded transition-all"
              >
                <Minimize2 className="w-3.5 h-3.5" />
                <span>EXIT WALLBOARD</span>
              </button>
            </div>
          ) : null}

          {/* Active Tab Router views */}
          {activeTab === "dashboard" && (
            <div className="space-y-6">
              <MetricsCard
                t310={t310Data}
                r510={r510Data}
                queueCounts={queueCounts}
              />
              <ChartsPanel
                metrics={historicalMetrics}
                selectedRange={selectedRange}
                setSelectedRange={setSelectedRange}
              />
            </div>
          )}

          {activeTab === "chat" && (
            <ChatInterface token={token} availableModels={availableModels} />
          )}

          {activeTab === "alerts" && (
            <AlertsPanel alerts={alerts} onRefresh={fetchData} />
          )}

          {activeTab === "admin" && (
            <AdminPanel
              status={{
                overall_health_score: healthScore,
                overall_status: status,
                autopilot_locked: telemetry?.autopilot_locked ?? false,
                autopilot_safe_mode: telemetry?.autopilot_safe_mode ?? false,
              }}
              token={token}
              onActionCompleted={handleActionCompleted}
            />
          )}
        </main>
      </div>

      {/* 3. Footer controls (Wallboard toggle option) */}
      {!wallboardMode && (
        <footer className="glass-panel border-t border-dashboard-border px-6 py-3 flex items-center justify-between text-xs text-dashboard-accent font-mono select-none">
          <p>© 2026 P3 NOC Command Center | Decoupled Architecture</p>
          <button
            onClick={() => {
              setWallboardMode(true);
              setActiveTab("dashboard");
            }}
            className="flex items-center gap-1.5 hover:text-dashboard-neon transition-colors"
            title="Maximize dashboard for physical TVs"
          >
            <Maximize2 className="w-3.5 h-3.5" />
            <span>NOC WALLBOARD DISPLAY</span>
          </button>
        </footer>
      )}

    </div>
  );
};
export default App;
