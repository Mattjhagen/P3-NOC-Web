from textual.widgets import Static
from textual.reactive import reactive
from rich.text import Text
from config.themes import THEME_COLORS

class OllamaPanel(Static):
    """
    Displays live Ollama inference statistics and server health details.
    """
    model_name = reactive("phi3:mini")
    server_host = reactive("r510")
    latency_str = reactive("224s")
    failures_count = reactive(0)
    status_str = reactive("ONLINE")
    requests_count = reactive(0)
    
    current_theme = reactive("matrix-green")

    def on_mount(self):
        self.border_title = "OLLAMA"

    def render(self) -> Text:
        theme = THEME_COLORS.get(self.current_theme, THEME_COLORS["matrix-green"])
        primary = theme["primary"]
        muted = theme["muted"]
        accent = theme["accent"]
        warning = theme["warning"]
        error = theme["error"]
        healthy = theme["healthy"]

        content = Text()
        content.append("\n Server Status:\n\n", style=f"bold {primary}")

        # Model name
        content.append(f"  Model:   ", style="white")
        content.append(f"{self.model_name}\n", style=accent)

        # Host
        content.append(f"  Server:  ", style="white")
        content.append(f"{self.server_host}\n", style=muted)

        # Latency
        content.append(f"  Latency: ", style="white")
        content.append(f"{self.latency_str}\n", style=warning)

        # Requests
        content.append(f"  Requests:", style="white")
        content.append(f"{self.requests_count}\n", style=healthy)

        # Failures
        content.append(f"  Failures:", style="white")
        fail_style = error if self.failures_count > 0 else healthy
        content.append(f"{self.failures_count}\n", style=fail_style)

        # Status
        content.append(f"  Status:  ", style="white")
        status_color = healthy if self.status_str == "ONLINE" else error
        content.append(f"{self.status_str}\n", style=f"bold {status_color}")

        return content
