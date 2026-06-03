from textual.widgets import Static
from textual.reactive import reactive
from rich.text import Text
from config.themes import THEME_COLORS
from config.settings import OLLAMA_REMOTE

class AlertPanel(Static):
    """
    Displays real-time operational alerts, Smart Recommendations,
    and trend-based Predictive Anomaly Warnings.
    """
    # Active states for alerts
    ollama_online = reactive(True)
    db_online = reactive(True)
    worker_active = reactive(True)
    ingest_active = reactive(True)
    
    ollama_failures = reactive(0)
    max_retry = reactive(0)
    failed_queue_count = reactive(0)
    latest_risk_score = reactive(0)
    worker_efficiency = reactive(100.0)
    avg_time = reactive(0.0)
    
    # v4 Smart Recommendations states
    host_ram_percent = reactive(0.0)
    queue_processing_count = reactive(0)
    active_ollama_model = reactive("")
    env_ollama_model = reactive("")
    
    # v5 Autopilot & Predictive states
    autopilot_locked = reactive(False)
    predictive_alerts = reactive([])
    startup_failures = reactive([])
    
    current_theme = reactive("matrix-green")

    def on_mount(self):
        self.border_title = "ALERTS"

    def render(self) -> Text:
        theme = THEME_COLORS.get(self.current_theme, THEME_COLORS["matrix-green"])
        primary = theme["primary"]
        error = theme["error"]
        warning = theme["warning"]
        healthy = theme["healthy"]
        accent = theme["accent"]

        content = Text()
        
        # 0. Check Autopilot Lockout
        if self.autopilot_locked:
            content.append("\n 🔴 AUTOPILOT LOCKED\n", style="bold reverse red")
            content.append(" 🔴 MANUAL REVIEW REQUIRED\n\n", style="bold red")
        else:
            content.append("\n Active Alerts:\n\n", style=f"bold {primary}")

        # Render Startup failures if any exist
        if self.startup_failures:
            for fail in self.startup_failures:
                content.append(f" 🔴 STARTUP: {fail}\n", style="bold red")

        # Render Predictive Anomaly Warnings
        if self.predictive_alerts:
            for pred in self.predictive_alerts:
                content.append(f" ⚠ TREND: {pred}\n", style="bold yellow reverse")

        # 1. Model Mismatch (Model Drift check)
        mismatch_active = False
        if self.env_ollama_model and self.active_ollama_model:
            if self.env_ollama_model.lower() != self.active_ollama_model.lower():
                content.append(" ⚠ MODEL MISMATCH\n", style="bold reverse red")
                mismatch_active = True

        # 2. Bitcoin Risk Score > 80
        if self.latest_risk_score >= 80:
            content.append(f" 🔴 Bitcoin Risk Score > 80 ({self.latest_risk_score})\n", style="bold red")
        elif self.latest_risk_score >= 50:
            content.append(f" 🟡 Bitcoin Risk Score Elevated ({self.latest_risk_score})\n", style="bold yellow")

        # 3. Ollama Offline / Timeouts
        if not self.ollama_online:
            if OLLAMA_REMOTE:
                content.append(" 🔴 REMOTE OLLAMA OFFLINE\n", style="bold red reverse")
            else:
                content.append(" 🔴 Ollama Server Offline\n", style="bold red")
        elif self.ollama_failures >= 3:
            if OLLAMA_REMOTE:
                content.append(f" 🔴 REMOTE OLLAMA OFFLINE ({self.ollama_failures} fails)\n", style="bold red reverse")
            else:
                content.append(f" 🔴 Ollama Timeout Spike ({self.ollama_failures} fails)\n", style="bold red")

        # 4. Queue Failure Rate Rising
        if self.worker_efficiency < 85.0:
            content.append(f" 🔴 Queue Failure Rate Rising ({100.0 - self.worker_efficiency:.1f}% error)\n", style="bold red")
        elif self.worker_efficiency < 95.0:
            content.append(f" 🟡 Queue Failure Rate Rising ({100.0 - self.worker_efficiency:.1f}% error)\n", style="bold yellow")

        # 5. Queue size alerts
        if self.failed_queue_count > 25:
            content.append(f" 🔴 Failed Queue > 25 ({self.failed_queue_count} items)\n", style="bold red")
        elif self.failed_queue_count > 10:
            content.append(f" 🟡 Failed Queue > 10 ({self.failed_queue_count} items)\n", style="bold yellow")

        # 6. Ingest / Worker offline alerts
        if not self.ingest_active:
            content.append(" 🔴 Ingest Offline\n", style="bold red")
        else:
            content.append(" 🟢 Ingest Running Normally\n", style="green")

        if not self.worker_active:
            content.append(" 🔴 Worker Offline\n", style="bold red")

        if not self.db_online:
            content.append(" 🔴 Database Offline\n", style="bold red")

        # 7. Average analysis duration warning
        if self.avg_time > 180.0:
            content.append(f" 🟡 Average Analysis > 180s ({self.avg_time:.1f}s)\n", style="bold yellow")

        # --- Smart Recommendations Section ---
        content.append("\n RECOMMENDED ACTIONS:\n", style=f"bold {primary}")
        recommendations = []

        # If locked, recommend unlocking
        if self.autopilot_locked:
            recommendations.append(("🔴 Autopilot Locked Out", "Run F12 Full Health Recovery to Unlock"))
            
        # Rule 1: Ollama Offline
        if not self.ollama_online:
            if OLLAMA_REMOTE:
                recommendations.append(("🔴 Remote Ollama Offline", "Check R510 Remote Host status"))
            else:
                recommendations.append(("🔴 Ollama Offline", "Run F10 Restart Ollama"))
        
        # Rule 2: Memory Pressure
        if self.host_ram_percent > 90.0:
            if OLLAMA_REMOTE:
                recommendations.append(("🔴 Memory Pressure (>90% RAM)", "Check host services"))
            else:
                recommendations.append(("🔴 Memory Pressure (>90% RAM)", "Run F10 Restart Ollama"))

        # Rule 3: Worker Offline
        if not self.worker_active:
            recommendations.append(("🟡 Worker Not Running", "Run F6 Restart Worker"))

        # Rule 4: Ollama Slow
        if self.avg_time > 120.0:
            recommendations.append(("🔴 Ollama Timeout Spike", "Run F11 Warm Model"))

        # Rule 5: Queue Jam
        if self.queue_processing_count > 5:
            recommendations.append(("🟡 Processing Stuck", "Run F9 Clear Stuck"))

        # Rule 6: Backlog
        if self.failed_queue_count > 20:
            recommendations.append(("🔴 Failed Queue > 20", "Run F8 Requeue Failed"))

        # Rule 7: Model Mismatch
        if mismatch_active:
            recommendations.append(("⚠ Model Mismatch Active", "Configure env or Warm Cache"))

        # Render recommendations
        if recommendations:
            for condition, action in recommendations:
                content.append(f" {condition}\n", style="bold white")
                content.append(f"  → {action}\n", style=accent)
        else:
            content.append(" 🟢 No active incidents detected\n", style="green")

        return content
