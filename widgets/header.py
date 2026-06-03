from datetime import datetime
from textual.widget import Widget
from textual.reactive import reactive
from rich.text import Text
from rich.align import Align
from config.themes import THEME_COLORS

# Large ASCII logo from request
LOGO_ASCII = """
██████╗ ██████╗ 
██╔══██╗╚════██╗
██████╔╝ █████╔╝
██╔═══╝  ╚═══██╗
██║     ██████╔╝
╚═╝     ╚═════╝ 
"""

class HeaderWidget(Widget):
    """
    Header widget displaying the P3 ASCII branding logo, dynamic timestamp,
    system services status summary, and real-time BTC ticker.
    """
    # Reactive variables to trigger re-renders
    worker_status = reactive(True)
    db_status = reactive(True)
    ollama_status = reactive(True)
    ingest_status = reactive(True)
    btc_price_str = reactive("$104,822")
    btc_change_str = reactive("+2.4%")
    btc_positive = reactive(True)
    
    current_theme = reactive("matrix-green")
    compact_mode = reactive(False)

    def render(self) -> Align:
        theme = THEME_COLORS.get(self.current_theme, THEME_COLORS["matrix-green"])
        primary_color = theme["primary"]
        muted_color = theme["muted"]
        healthy_color = theme["healthy"]
        error_color = theme["error"]
        warning_color = theme["warning"]

        # Build ASCII branding header if NOT in compact mode
        header_text = Text()
        if not self.compact_mode:
            logo = Text(LOGO_ASCII, style=primary_color)
            sub = Text("P3 NOC — Bitcoin Intelligence Operations Center\n", style=f"bold {primary_color}")
            header_text.append(logo)
            header_text.append(sub)
        else:
            # Minimal compact logo
            header_text.append(Text(" P3 NOC [SYSTEM MONITORING ACTIVE] ", style=f"bold reverse {primary_color}"))
            header_text.append(Text("\n"))

        # Build service status summary line
        status_line = Text()
        
        # Helper for bullet points
        def add_status_bullet(label: str, active: bool):
            status_line.append(f"{label} ", style="bold white")
            bullet_style = healthy_color if active else error_color
            status_line.append("●   ", style=bullet_style)

        add_status_bullet("Worker", self.worker_status)
        add_status_bullet("DB", self.db_status)
        add_status_bullet("Ollama", self.ollama_status)
        add_status_bullet("Ingest", self.ingest_status)

        # Append BTC price
        btc_style = healthy_color if self.btc_positive else warning_color
        status_line.append("BTC ", style="bold white")
        status_line.append(f"{self.btc_price_str} ({self.btc_change_str})", style=btc_style)

        # Right-aligned clock
        time_str = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        status_line_right = Text(f"🕒 {time_str}", style=muted_color)
        
        # Merge them
        full_width = self.app.size.width if self.app else 80
        # Calculate padding space between left statuses and right clock
        content_len = len(status_line.plain) + len(status_line_right.plain)
        padding_spaces = max(1, full_width - content_len - 6)
        
        status_line.append(" " * padding_spaces)
        status_line.append(status_line_right)
        
        # Join branding and status bar with a divider line
        divider = Text("─" * (full_width - 2), style=muted_color)
        
        result_text = Text()
        if not self.compact_mode:
            result_text.append(header_text)
            result_text.append(divider)
            result_text.append(Text("\n"))
        
        result_text.append(status_line)
        result_text.append(Text("\n"))
        result_text.append(divider)

        return Align.center(result_text)
