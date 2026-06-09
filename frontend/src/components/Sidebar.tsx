import React from "react";

interface SidebarProps {
  activeTab: string;
  setActiveTab: (tab: string) => void;
  activeAlertCount: number;
}

const tabs = [
  { id: "dashboard", label: "dashboard" },
  { id: "chat", label: "intelligence" },
  { id: "alerts", label: "alerts" },
  { id: "admin", label: "admin" },
];

export const Sidebar: React.FC<SidebarProps> = ({ activeTab, setActiveTab, activeAlertCount }) => {
  return (
    /* Metro panoramic horizontal navigation strip */
    <nav className="select-none"
      style={{
        borderBottom: "1px solid rgba(255,255,255,0.05)",
        background: "#0f0f0f",
        paddingLeft: "2rem",
        paddingRight: "2rem",
        display: "flex",
        alignItems: "flex-end",
        gap: "2.5rem",
        overflowX: "auto",
      }}>
      {tabs.map(tab => {
        const isActive = activeTab === tab.id;
        return (
          <button
            key={tab.id}
            onClick={() => setActiveTab(tab.id)}
            style={{
              background: "transparent",
              border: "none",
              padding: "0.875rem 0",
              cursor: "pointer",
              fontSize: "1.375rem",
              fontWeight: 300,
              letterSpacing: "-0.01em",
              color: isActive ? "#ffffff" : "rgba(255,255,255,0.3)",
              borderBottom: isActive ? "2px solid var(--metro-accent)" : "2px solid transparent",
              transition: "color 0.15s, border-color 0.15s",
              whiteSpace: "nowrap",
              position: "relative",
              fontFamily: "inherit",
            }}
          >
            {tab.label}
            {tab.id === "alerts" && activeAlertCount > 0 && (
              <span style={{
                position: "absolute",
                top: "10px",
                right: "-14px",
                background: "#ef233c",
                color: "#fff",
                fontSize: "0.6rem",
                fontWeight: 700,
                width: "16px",
                height: "16px",
                borderRadius: "2px",
                display: "flex",
                alignItems: "center",
                justifyContent: "center",
              }}>
                {activeAlertCount}
              </span>
            )}
          </button>
        );
      })}
    </nav>
  );
};
