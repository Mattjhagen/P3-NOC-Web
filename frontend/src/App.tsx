import React, { useState, useEffect } from "react";
import axios from "axios";
import { Header } from "./components/Header";
import { Sidebar } from "./components/Sidebar";
import { Login } from "./components/Login";
import { MetricsCard } from "./components/MetricsCard";
import { ChartsPanel } from "./components/ChartsPanel";
import { AlertsPanel } from "./components/AlertsPanel";
import { AdminPanel } from "./components/AdminPanel";
import { ChatInterface } from "./components/ChatInterface";
import { useWebSocket } from "./hooks/useWebSocket";

export const App: React.FC = () => {
  const [token, setToken] = useState<string | null>(localStorage.getItem("p3_noc_token"));
  const [user, setUser] = useState<{ username: string; role: string } | null>(null);
  const [activeTab, setActiveTab] = useState<string>("dashboard");
  const [selectedRange, setSelectedRange] = useState<string>("1h");
  const [telemetry, setTelemetry] = useState<any>(null);
  const [historicalMetrics, setHistoricalMetrics] = useState<any[]>([]);
  const [alerts, setAlerts] = useState<any>({ critical: [], warning: [], info: [], logs: [] });
  const [availableModels, setAvailableModels] = useState<string[]>([]);

  useEffect(() => {
    if (token) {
      axios.defaults.headers.common["Authorization"] = `Bearer ${token}`;
      axios.get("/api/auth/me").then(res => setUser(res.data)).catch(() => handleLogout());
    } else {
      delete axios.defaults.headers.common["Authorization"];
      setUser(null);
    }
  }, [token]);

  const { data: wsData } = useWebSocket("/ws/status", token !== null);
  useEffect(() => {
    if (wsData) {
      setTelemetry(wsData);
      if (wsData.r510?.available_models) setAvailableModels(wsData.r510.available_models);
    }
  }, [wsData]);

  const fetchData = async () => {
    if (!token) return;
    try {
      const [metricsRes, alertsRes] = await Promise.all([
        axios.get(`/api/metrics?range=${selectedRange}`),
        axios.get("/api/alerts"),
      ]);
      setHistoricalMetrics(metricsRes.data);
      setAlerts(alertsRes.data);
    } catch (err) {
      console.error("Failed to sync REST APIs:", err);
    }
  };

  useEffect(() => {
    fetchData();
    const iv = setInterval(fetchData, 10000);
    return () => clearInterval(iv);
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

  if (!token) return <Login onLoginSuccess={handleLoginSuccess} />;

  const activeAlertCount =
    (telemetry?.active_issues?.length ?? 0) +
    (alerts.critical?.length ?? 0) +
    (alerts.warning?.length ?? 0);

  const healthScore = telemetry?.overall_health_score ?? 100;
  const status = telemetry?.overall_status ?? "HEALTHY";
  const uptime = telemetry?.uptime ?? "N/A";
  const queueCounts = telemetry?.queue_counts ?? { pending: 0, processing: 0, completed: 0, failed: 0 };
  const t310Data = telemetry?.t310 ?? {};
  const r510Data = telemetry?.r510 ?? {};

  return (
    <div style={{ minHeight: "100vh", display: "flex", flexDirection: "column", background: "#0f0f0f" }}>
      {/* Emergency bar */}
      {healthScore < 90 && (
        <div style={{
          background: "rgba(239,35,60,0.08)",
          borderBottom: "1px solid rgba(239,35,60,0.2)",
          padding: "0.5rem 2rem",
          display: "flex",
          alignItems: "center",
          justifyContent: "space-between",
        }}>
          <span style={{ fontSize: "0.75rem", color: "#ef233c", fontWeight: 600, letterSpacing: "0.06em", textTransform: "uppercase" }}>
            ⚠ System health degraded — {healthScore}%
          </span>
          <button onClick={() => setActiveTab("admin")}
            style={{ background: "transparent", border: "none", color: "#ef233c", fontSize: "0.75rem", fontWeight: 600, cursor: "pointer", textDecoration: "underline", fontFamily: "inherit" }}>
            Open Control Deck
          </button>
        </div>
      )}

      <Header healthScore={healthScore} status={status} uptime={uptime} user={user} onLogout={handleLogout} />
      <Sidebar activeTab={activeTab} setActiveTab={setActiveTab} activeAlertCount={activeAlertCount} />

      <main style={{ flex: 1, padding: "2.5rem 2rem", overflowY: "auto" }}>
        {activeTab === "dashboard" && (
          <div style={{ display: "flex", flexDirection: "column", gap: "2.5rem" }}>
            <MetricsCard t310={t310Data} r510={r510Data} queueCounts={queueCounts} />
            <ChartsPanel metrics={historicalMetrics} selectedRange={selectedRange} setSelectedRange={setSelectedRange} />
          </div>
        )}
        {activeTab === "chat" && <ChatInterface token={token} availableModels={availableModels} />}
        {activeTab === "alerts" && <AlertsPanel alerts={alerts} onRefresh={fetchData} />}
        {activeTab === "admin" && (
          <AdminPanel
            status={{ overall_health_score: healthScore, overall_status: status, autopilot_locked: telemetry?.autopilot_locked ?? false, autopilot_safe_mode: telemetry?.autopilot_safe_mode ?? false }}
            token={token}
            onActionCompleted={fetchData}
          />
        )}
      </main>

      <footer style={{
        borderTop: "1px solid rgba(255,255,255,0.05)",
        padding: "0.75rem 2rem",
        display: "flex",
        justifyContent: "space-between",
        alignItems: "center",
      }}>
        <span style={{ fontSize: "0.6875rem", color: "rgba(255,255,255,0.2)", letterSpacing: "0.06em" }}>
          © 2026 P3 OPERATIONS CENTER
        </span>
        <span style={{ fontSize: "0.6875rem", color: "rgba(255,255,255,0.2)", letterSpacing: "0.06em" }}>
          BITCOIN INTELLIGENCE NOC
        </span>
      </footer>
    </div>
  );
};

export default App;
