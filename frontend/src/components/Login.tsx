import React, { useState } from "react";
import axios from "axios";

interface LoginProps {
  onLoginSuccess: (token: string, username: string, role: string) => void;
}

export const Login: React.FC<LoginProps> = ({ onLoginSuccess }) => {
  const [isRegister, setIsRegister] = useState(false);
  const [username, setUsername] = useState("");
  const [password, setPassword] = useState("");
  const [role, setRole] = useState("viewer");
  const [errorMsg, setErrorMsg] = useState("");
  const [isLoading, setIsLoading] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setErrorMsg("");
    setIsLoading(true);
    try {
      if (isRegister) {
        await axios.post("/api/auth/register", { username, password, role });
      }
      const params = new URLSearchParams();
      params.append("username", username);
      params.append("password", password);
      const res = await axios.post("/api/auth/login", params, {
        headers: { "Content-Type": "application/x-www-form-urlencoded" },
      });
      const { access_token, role: userRole } = res.data;
      onLoginSuccess(access_token, username, userRole);
    } catch (err: any) {
      setErrorMsg(err.response?.data?.detail || "Authentication failed.");
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div style={{ minHeight: "100vh", background: "#0f0f0f", display: "flex" }}>
      {/* Left accent panel */}
      <div style={{
        width: "8px",
        background: "var(--metro-accent)",
        flexShrink: 0,
      }} />

      {/* Main content */}
      <div style={{ flex: 1, display: "flex", alignItems: "center", padding: "4rem 6vw" }}>
        <div style={{ maxWidth: "400px", width: "100%" }}>

          {/* Title block */}
          <div style={{ marginBottom: "3.5rem" }}>
            <div className="metro-title">p3</div>
            <div style={{
              fontSize: "clamp(1.5rem, 3vw, 2rem)",
              fontWeight: 300,
              color: "rgba(255,255,255,0.45)",
              letterSpacing: "-0.01em",
              lineHeight: 1.1,
              marginTop: "0.25rem",
            }}>
              operations center
            </div>
            <div className="metro-label" style={{ marginTop: "1rem" }}>
              {isRegister ? "create account" : "sign in to continue"}
            </div>
          </div>

          {/* Error */}
          {errorMsg && (
            <div style={{
              background: "rgba(239,35,60,0.12)",
              borderLeft: "3px solid #ef233c",
              padding: "0.875rem 1rem",
              marginBottom: "2rem",
              fontSize: "0.875rem",
              color: "#ef233c",
            }}>
              {errorMsg}
            </div>
          )}

          {/* Form */}
          <form onSubmit={handleSubmit} style={{ display: "flex", flexDirection: "column", gap: "2rem" }}>
            <div>
              <label className="metro-label" style={{ display: "block", marginBottom: "0.5rem" }}>username</label>
              <input
                type="text"
                required
                autoFocus
                value={username}
                onChange={e => setUsername(e.target.value)}
                placeholder="operator_name"
                className="metro-input"
              />
            </div>

            <div>
              <label className="metro-label" style={{ display: "block", marginBottom: "0.5rem" }}>password</label>
              <input
                type="password"
                required
                value={password}
                onChange={e => setPassword(e.target.value)}
                placeholder="••••••••"
                className="metro-input"
              />
            </div>

            {isRegister && (
              <div>
                <label className="metro-label" style={{ display: "block", marginBottom: "0.5rem" }}>role</label>
                <select
                  value={role}
                  onChange={e => setRole(e.target.value)}
                  className="metro-input"
                  style={{ cursor: "pointer" }}
                >
                  <option value="admin" style={{ background: "#1a1a1a" }}>admin</option>
                  <option value="operator" style={{ background: "#1a1a1a" }}>operator</option>
                  <option value="viewer" style={{ background: "#1a1a1a" }}>viewer</option>
                </select>
              </div>
            )}

            <button type="submit" disabled={isLoading} className="metro-btn" style={{ marginTop: "0.5rem" }}>
              {isLoading ? "authenticating..." : isRegister ? "create account" : "sign in"}
            </button>
          </form>

          <button
            onClick={() => setIsRegister(!isRegister)}
            style={{
              background: "transparent",
              border: "none",
              color: "rgba(255,255,255,0.35)",
              fontSize: "0.8125rem",
              marginTop: "2rem",
              cursor: "pointer",
              padding: 0,
              textDecoration: "underline",
              fontFamily: "inherit",
            }}
          >
            {isRegister ? "already have an account" : "first time? create account"}
          </button>
        </div>
      </div>

      {/* Right decorative typography */}
      <div style={{
        display: "none",
        alignItems: "flex-end",
        paddingBottom: "4rem",
        paddingRight: "5vw",
        overflow: "hidden",
      }} className="lg:flex">
        <div style={{
          fontSize: "clamp(6rem, 12vw, 14rem)",
          fontWeight: 700,
          color: "rgba(255,255,255,0.03)",
          lineHeight: 1,
          letterSpacing: "-0.04em",
          userSelect: "none",
        }}>
          NOC
        </div>
      </div>
    </div>
  );
};
