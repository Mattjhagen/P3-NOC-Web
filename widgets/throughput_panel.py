from textual.widgets import Static
from textual.reactive import reactive
from rich.text import Text
from config.themes import THEME_COLORS

class ThroughputPanel(Static):
    """
    Displays operational performance statistics:
    throughput rate, processing latencies, remaining load, and completion ETA.
    """
    processed_last_hour = reactive(0)
    avg_time = reactive(0.0)
    remaining = reactive(0)
    eta_str = reactive("0m")
    
    current_theme = reactive("matrix-green")

    def on_mount(self):
        self.border_title = "THROUGHPUT"

    def render(self) -> Text:
        theme = THEME_COLORS.get(self.current_theme, THEME_COLORS["matrix-green"])
        primary = theme["primary"]
        muted = theme["muted"]
        accent = theme["accent"]
        warning = theme["warning"]
        healthy = theme["healthy"]

        content = Text()
        content.append("\n Performance:\n\n", style=f"bold {primary}")

        # Processed last hour
        content.append(f"  Last Hour:", style="white")
        content.append(f"{self.processed_last_hour:>8}\n", style=healthy)

        # Avg processing latency
        content.append(f"  Avg Time:", style="white")
        content.append(f"{f'{self.avg_time:.1f}s':>9}\n", style=accent)

        # Queue remaining
        content.append(f"  Remaining:", style="white")
        content.append(f"{self.remaining:>8}\n", style=warning)

        # ETA
        content.append(f"  ETA:", style="white")
        content.append(f"{self.eta_str:>14}\n", style="bold white")

        return content
