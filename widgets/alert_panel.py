from textual.widgets import Static
from textual.reactive import reactive
from rich.text import Text
from config.themes import THEME_COLORS

class AlertPanel(Static):
    """
    Displays real-time operational alerts for system health,
    inference failures, and database connection.
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
    
    current_theme = reactive("matrix-green")

    def on_mount(self):
        self.border_title = "ALERTS"

    def render(self) -> Text:
        theme = THEME_COLORS.get(self.current_theme, THEME_COLORS["matrix-green"])
        primary = theme["primary"]
        error = theme["error"]
        warning = theme["warning"]
        healthy = theme["healthy"]

        content = Text()
        content.append("\n System Alerts:\n\n", style=f"bold {primary}")

        alerts_found = False

        # Alert 1: Database status
        if not self.db_online:
            content.append(" 🔴 Database Offline\n", style="bold red")
            alerts_found = True
        else:
            content.append(" 🟢 Database Healthy\n", style="green")

        # Alert 2: Worker status
        if not self.worker_active:
            content.append(" 🔴 Worker Offline\n", style="bold red")
            alerts_found = True
        else:
            content.append(" 🟢 Worker Active\n", style="green")

        # Alert 3: Ollama Status & Timeouts
        if not self.ollama_online:
            content.append(" 🔴 Ollama Server Offline\n", style="bold red")
            alerts_found = True
        elif self.ollama_failures >= 3:
            content.append(" 🔴 Ollama Timeout Rate High\n", style="bold red")
            alerts_found = True
        elif self.ollama_failures > 0:
            content.append(f" 🟡 Ollama Retries Active ({self.ollama_failures})\n", style="bold yellow")
            alerts_found = True
        else:
            content.append(" 🟢 Ollama Online\n", style="green")

        # Alert 4: Retry Count
        if self.max_retry >= 4:
            content.append(f" 🔴 Retry Spike: Count {self.max_retry}\n", style="bold red")
            alerts_found = True
        elif self.max_retry >= 2:
            content.append(f" 🟡 Worker Retry Spike\n", style="bold yellow")
            alerts_found = True

        # Alert 5: Queue Stall
        if self.failed_queue_count > 15:
            content.append(" 🔴 Queue Stalled (High Failures)\n", style="bold red")
            alerts_found = True
        elif self.failed_queue_count > 0:
            content.append(f" 🟡 Queue Accumulating Fails ({self.failed_queue_count})\n", style="bold yellow")
            alerts_found = True
        else:
            content.append(" 🟢 Queue Healthy\n", style="green")

        # Alert 6: Risk score alert
        if self.latest_risk_score >= 80:
            content.append(f" 🔴 Risk Critical: {self.latest_risk_score}/100\n", style="bold red")
            alerts_found = True
        elif self.latest_risk_score >= 50:
            content.append(f" 🟡 Risk Elevated: {self.latest_risk_score}/100\n", style="bold yellow")
            alerts_found = True

        return content
