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
    processed_today = reactive(0)
    avg_time = reactive(0.0)
    remaining = reactive(0)
    eta_str = reactive("0m")
    worker_efficiency = reactive(100.0)
    
    current_theme = reactive("matrix-green")

    def on_mount(self):
        self.border_title = "THROUGHPUT"

    def render(self) -> Text:
        theme = THEME_COLORS.get(self.current_theme, THEME_COLORS["matrix-green"])
        primary = theme["primary"]
        muted = theme["muted"]
        accent = theme["accent"]
        warning = theme["warning"]
        error = theme["error"]
        healthy = theme["healthy"]

        content = Text()
        content.append("\n Performance:\n\n", style=f"bold {primary}")

        # Processed last hour
        content.append(f"  Last Hour:", style="white")
        content.append(f"{self.processed_last_hour:>8}\n", style=healthy)

        # Processed today
        content.append(f"  Today:    ", style="white")
        content.append(f"{self.processed_today:>8,}\n", style=healthy)

        # Avg processing latency
        content.append(f"  Avg Time: ", style="white")
        content.append(f"{f'{self.avg_time:.1f}s':>9}\n", style=accent)

        # Queue remaining
        content.append(f"  Remaining:", style="white")
        content.append(f"{self.remaining:>8}\n", style=warning)

        # ETA
        content.append(f"  ETA:      ", style="white")
        content.append(f"{self.eta_str:>9}\n", style="bold white")

        # Worker Efficiency
        eff_style = healthy if self.worker_efficiency >= 95.0 else (warning if self.worker_efficiency >= 85.0 else error)
        content.append(f"  Efficiency:", style="white")
        content.append(f"{f'{self.worker_efficiency:.1f}%':>8}\n", style=f"bold {eff_style}")

        return content
