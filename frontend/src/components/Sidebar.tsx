import React from "react";
import { LayoutDashboard, MessageSquareCode, ShieldAlert, Terminal, HelpCircle } from "lucide-react";

interface SidebarProps {
  activeTab: string;
  setActiveTab: (tab: string) => void;
  activeAlertCount: number;
}

export const Sidebar: React.FC<SidebarProps> = ({
  activeTab,
  setActiveTab,
  activeAlertCount,
}) => {
  const tabs = [
    { id: "dashboard", label: "Dashboard", icon: LayoutDashboard },
    { id: "chat", label: "AI Assistant", icon: MessageSquareCode },
    { id: "alerts", label: "Alerts & Logs", icon: ShieldAlert, count: activeAlertCount },
    { id: "admin", label: "System Admin", icon: Terminal },
  ];

  return (
    <aside className="w-full md:w-64 glass-panel border-r border-dashboard-border flex flex-col select-none">
      {/* Navigation List */}
      <nav className="flex-1 px-4 py-6 space-y-2">
        {tabs.map((tab) => {
          const Icon = tab.icon;
          const isActive = activeTab === tab.id;
          return (
            <button
              key={tab.id}
              onClick={() => setActiveTab(tab.id)}
              className={`w-full flex items-center justify-between px-4 py-3.5 rounded-lg border text-left transition-all duration-300 font-medium ${
                isActive
                  ? "bg-dashboard-neon/10 text-dashboard-neon border-dashboard-neon/50 shadow-glow-neon glow-active-tab"
                  : "text-gray-400 hover:text-gray-200 bg-transparent border-transparent hover:bg-white/5"
              }`}
            >
              <div className="flex items-center gap-3">
                <Icon className={`w-5 h-5 ${isActive ? "text-dashboard-neon" : "text-gray-400"}`} />
                <span className="text-sm font-semibold tracking-wider uppercase font-digital">{tab.label}</span>
              </div>
              
              {/* Alert Badge count */}
              {tab.count !== undefined && tab.count > 0 && (
                <span className="bg-rose-500/20 text-rose-400 border border-rose-500/50 text-xs px-2.5 py-0.5 rounded-full font-bold font-digital">
                  {tab.count}
                </span>
              )}
            </button>
          );
        })}
      </nav>

      {/* Footer Info */}
      <div className="p-4 border-t border-dashboard-border bg-black/20 text-center text-xs text-dashboard-accent font-mono">
        <p className="flex items-center justify-center gap-1.5 hover:text-dashboard-neon cursor-pointer">
          <HelpCircle className="w-3.5 h-3.5" />
          <span>HELP & DOCUMENTS</span>
        </p>
        <p className="mt-1 opacity-60">P3 NOC Infrastructure</p>
      </div>
    </aside>
  );
};
