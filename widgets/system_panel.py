from textual.widgets import Static
from textual.reactive import reactive
from rich.text import Text
from rich.panel import Panel
from config.themes import THEME_COLORS

class SystemPanel(Static):
    """
    Displays service queue state details: counts for
    pending, processing, completed, and failed items with percentages.
    """
    pending_count = reactive(0)
    processing_count = reactive(0)
    completed_count = reactive(0)
    failed_count = reactive(0)

    current_theme = reactive("matrix-green")

    def on_mount(self):
        self.border_title = "QUEUE STATUS"

    def render(self) -> Text:
        theme = THEME_COLORS.get(self.current_theme, THEME_COLORS["matrix-green"])
        primary = theme["primary"]
        muted = theme["muted"]
        accent = theme["accent"]
        warning = theme["warning"]
        error = theme["error"]
        healthy = theme["healthy"]

        content = Text()

        # Calculate totals
        total = self.pending_count + self.processing_count + self.completed_count + self.failed_count
        finished = self.completed_count + self.failed_count

        # Success rate
        if finished > 0:
            success_rate = (self.completed_count / finished) * 100
        else:
            success_rate = 100.0

        content.append("\n Processing Queue:\n\n", style=f"bold {primary}")

        # Total
        content.append(f"  Total:     ", style="white")
        content.append(f"{total:>6,}\n\n", style=f"bold {primary}")

        # Helper to add status rows with percentages
        def add_row(label: str, val: int, style: str):
            pct = (val / total * 100) if total > 0 else 0
            bar_len = int(pct / 10)  # 0-10 characters
            bar = "█" * bar_len
            content.append(f"  {label:<11}", style="white")
            content.append(f"{val:>5}", style=f"bold {style}")
            content.append(f" {bar}", style=style)
            content.append(f" {pct:>5.1f}%\n", style=muted)

        add_row("Pending:", self.pending_count, accent)
        add_row("Processing:", self.processing_count, warning)
        add_row("Completed:", self.completed_count, healthy)
        add_row("Failed:", self.failed_count, error)

        # Success rate
        rate_style = healthy if success_rate >= 90 else (warning if success_rate >= 70 else error)
        content.append(f"\n  Success:   ", style="white")
        content.append(f"{success_rate:>5.1f}%", style=f"bold {rate_style}")
        content.append(f"  ({self.completed_count}/{finished})\n", style=muted)

        return content
