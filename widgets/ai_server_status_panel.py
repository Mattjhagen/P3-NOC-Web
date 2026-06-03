from textual.widgets import Static
from textual.reactive import reactive
from rich.text import Text
from config.themes import THEME_COLORS
from config.settings import AI_SERVER_HOST, AI_SERVER_IP

class AiServerStatusPanel(Static):
    """
    Displays the status of the remote AI Server (R510).
    """
    host = reactive(AI_SERVER_HOST)
    ip = reactive(AI_SERVER_IP)
    ping_latency = reactive(0.0)
    ssh_status = reactive("OFFLINE")
    ollama_status = reactive("OFFLINE")
    last_success = reactive("N/A")
    current_theme = reactive("matrix-green")

    def on_mount(self):
        self.border_title = "AI SERVER STATUS"

    def render(self) -> Text:
        theme = THEME_COLORS.get(self.current_theme, THEME_COLORS["matrix-green"])
        primary = theme["primary"]
        accent = theme["accent"]
        healthy = theme["healthy"]
        warning = theme["warning"]
        error = theme["error"]

        content = Text()
        content.append("\n Remote Host Details:\n\n", style=f"bold {primary}")
        
        content.append("  Host:   ", style="white")
        content.append(f"{self.host}\n", style=accent)
        
        content.append("  IP:     ", style="white")
        content.append(f"{self.ip}\n", style=accent)
        
        content.append("  Ping:   ", style="white")
        if self.ping_latency > 0:
            content.append(f"{self.ping_latency:.1f} ms\n", style=healthy)
        else:
            content.append("TIMEOUT\n", style=error)
            
        content.append("  SSH:    ", style="white")
        ssh_style = healthy if self.ssh_status == "ONLINE" else error
        content.append(f"{self.ssh_status}\n", style=ssh_style)
        
        content.append("  Ollama: ", style="white")
        ollama_style = healthy if self.ollama_status == "ONLINE" else error
        content.append(f"{self.ollama_status}\n", style=ollama_style)
        
        content.append("  Checked:", style="white")
        content.append(f" {self.last_success}\n", style="cyan")

        return content
