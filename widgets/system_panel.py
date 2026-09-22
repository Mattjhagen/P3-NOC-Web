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

        content.append("\n Queue Metrics:\n\n", style=f"bold {primary}")

        # Main metrics - big and bold
        content.append(f"  Completed: ", style="white")
        content.append(f"{self.completed_count:>6,}\n", style=f"bold {healthy}")

        content.append(f"  Failed:    ", style="white")
        content.append(f"{self.failed_count:>6,}\n", style=f"bold {error}")

        content.append(f"  Pending:   ", style="white")
        content.append(f"{self.pending_count:>6,}\n\n", style=f"bold {accent}")

        # Secondary metrics with bars
        content.append(f"  Processing:", style=muted)
        content.append(f" {self.processing_count}\n", style=warning)

        content.append(f"  Total:     ", style=muted)
        content.append(f" {total:,}\n", style=muted)

        # Success rate
        rate_style = healthy if success_rate >= 90 else (warning if success_rate >= 70 else error)
        content.append(f"\n  Success:   ", style="white")
        content.append(f"{success_rate:>5.1f}%", style=f"bold {rate_style}")
        content.append(f"  ({self.completed_count}/{finished})\n", style=muted)

        return content
