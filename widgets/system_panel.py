from textual.widgets import Static
from textual.reactive import reactive
from rich.text import Text
from rich.panel import Panel
from config.themes import THEME_COLORS

class SystemPanel(Static):
    """
    Displays service queue state details: counts for
    pending, processing, completed, and failed items.
    """
    pending_count = reactive(0)
    processing_count = reactive(0)
    completed_count = reactive(0)
    failed_count = reactive(0)
    
    current_theme = reactive("matrix-green")

    def on_mount(self):
        self.border_title = "SYSTEM"

    def render(self) -> Text:
        theme = THEME_COLORS.get(self.current_theme, THEME_COLORS["matrix-green"])
        primary = theme["primary"]
        muted = theme["muted"]
        accent = theme["accent"]
        warning = theme["warning"]
        error = theme["error"]
        healthy = theme["healthy"]

        content = Text()
        content.append("\n Queue States:\n\n", style=f"bold {primary}")
        
        # Helper to align rows
        def add_row(label: str, val: int, style: str):
            content.append(f"  {label:<12}", style="white")
            content.append(f"{val:>5}\n", style=style)

        add_row("Pending:", self.pending_count, healthy)
        add_row("Processing:", self.processing_count, warning)
        add_row("Completed:", self.completed_count, healthy)
        add_row("Failed:", self.failed_count, error)
        
        return content
