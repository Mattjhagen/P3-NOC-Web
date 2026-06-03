import React, { useState } from "react";
import { Server, Lock, User, Terminal } from "lucide-react";
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
        // Register API endpoint
        await axios.post("/api/auth/register", { username, password, role });
        // After registering, switch to login or auto-login.
        // Let's auto-login!
      }

      // Login form-data payload for OAuth2PasswordRequestForm
      const params = new URLSearchParams();
      params.append("username", username);
      params.append("password", password);

      const res = await axios.post("/api/auth/login", params, {
        headers: { "Content-Type": "application/x-www-form-urlencoded" },
      });

      const { access_token, role: userRole } = res.data;
      onLoginSuccess(access_token, username, userRole);
    } catch (err: any) {
      logger_error(err);
      setErrorMsg(
        err.response?.data?.detail || "Authentication request failed. Please check inputs."
      );
    } finally {
      setIsLoading(false);
    }
  };

  const logger_error = (e: any) => {
    console.error("Auth error:", e);
  };

  return (
    <div className="min-h-screen flex items-center justify-center bg-[#0B0C10] p-4 relative select-none">
      {/* Background Matrix-like abstract overlay */}
      <div className="absolute inset-0 bg-[radial-gradient(ellipse_at_center,rgba(69,162,158,0.07)_0%,transparent_70%)] pointer-events-none" />

      <div className="w-full max-w-md glass-panel rounded-2xl border border-dashboard-border shadow-glow-neon p-8 relative overflow-hidden">
        {/* Glowing top line */}
        <div className="absolute top-0 left-0 right-0 h-1 bg-gradient-to-r from-dashboard-accent via-dashboard-neon to-dashboard-accent" />

        {/* Center Logo */}
        <div className="text-center mb-8">
          <div className="inline-flex bg-dashboard-neon/10 p-3 rounded-full border border-dashboard-neon/30 mb-3 shadow-glow-neon">
            <Server className="w-8 h-8 text-dashboard-neon" />
          </div>
          <h2 className="text-2xl font-bold tracking-widest text-white font-digital uppercase">
            P3 Operations Center
          </h2>
          <p className="text-xs text-dashboard-accent tracking-widest font-mono mt-1">
            INFRASTRUCTURE MONITORING LOGIN
          </p>
        </div>

        {errorMsg && (
          <div className="mb-6 p-3 rounded border border-rose-500/30 bg-rose-950/20 text-rose-400 text-sm text-center font-mono">
            {errorMsg}
          </div>
        )}

        <form onSubmit={handleSubmit} className="space-y-5">
          {/* Username Input */}
          <div className="space-y-1.5">
            <label className="text-xs font-mono text-dashboard-accent uppercase tracking-wider block">
              Username ID
            </label>
            <div className="relative">
              <span className="absolute left-3 top-3.5 text-gray-500">
                <User className="w-4.5 h-4.5" />
              </span>
              <input
                type="text"
                required
                value={username}
                onChange={(e) => setUsername(e.target.value)}
                placeholder="operator_name"
                className="w-full pl-10 pr-4 py-3 bg-black/40 border border-dashboard-border rounded-lg text-white font-mono placeholder-gray-600 focus:outline-none focus:border-dashboard-neon transition-colors"
              />
            </div>
          </div>

          {/* Password Input */}
          <div className="space-y-1.5">
            <label className="text-xs font-mono text-dashboard-accent uppercase tracking-wider block">
              Security Keycode
            </label>
            <div className="relative">
              <span className="absolute left-3 top-3.5 text-gray-500">
                <Lock className="w-4.5 h-4.5" />
              </span>
              <input
                type="password"
                required
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                placeholder="••••••••"
                className="w-full pl-10 pr-4 py-3 bg-black/40 border border-dashboard-border rounded-lg text-white font-mono placeholder-gray-600 focus:outline-none focus:border-dashboard-neon transition-colors"
              />
            </div>
          </div>

          {/* Setup / Register fields */}
          {isRegister && (
            <div className="space-y-1.5">
              <label className="text-xs font-mono text-dashboard-accent uppercase tracking-wider block">
                Assigned Role
              </label>
              <div className="relative">
                <span className="absolute left-3 top-3.5 text-gray-500">
                  <Terminal className="w-4.5 h-4.5" />
                </span>
                <select
                  value={role}
                  onChange={(e) => setRole(e.target.value)}
                  className="w-full pl-10 pr-4 py-3 bg-black/40 border border-dashboard-border rounded-lg text-white font-mono focus:outline-none focus:border-dashboard-neon appearance-none transition-colors"
                >
                  <option value="admin" className="bg-dashboard-card text-white">Admin (Full Control)</option>
                  <option value="operator" className="bg-dashboard-card text-white">Operator (Control Dashboard)</option>
                  <option value="viewer" className="bg-dashboard-card text-white">Viewer (Read Only)</option>
                </select>
              </div>
            </div>
          )}

          {/* Action Button */}
          <button
            type="submit"
            disabled={isLoading}
            className="w-full bg-dashboard-neon text-black font-semibold uppercase tracking-widest py-3.5 rounded-lg hover:bg-white transition-all duration-300 shadow-glow-neon font-digital disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {isLoading ? "Authenticating..." : isRegister ? "Provision Account" : "Access Console"}
          </button>
        </form>

        {/* Toggle Mode Link */}
        <div className="mt-6 text-center text-xs font-mono text-gray-400">
          <button
            onClick={() => setIsRegister(!isRegister)}
            className="text-dashboard-accent hover:text-dashboard-neon underline bg-transparent"
          >
            {isRegister
              ? "Already have an account? Access Console"
              : "First install? Provision Admin Account"}
          </button>
        </div>
      </div>
    </div>
  );
};
