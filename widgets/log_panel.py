from textual.widgets import Log
from textual.reactive import reactive
from rich.text import Text
from config.themes import THEME_COLORS

class LogPanel(Log):
    """
    Displays live worker system logs using Textual's native Log widget.
    Highlights INFO, WARNING, ERROR, and CRITICAL messages in NOC theme colors.
    """
    current_theme = reactive("matrix-green")
    
    # Store set of printed lines to avoid duplication if appending,
    # or we can clear and rewrite. Let's do clear and rewrite for reliability.
    def on_mount(self):
        self.border_title = "WORKER LOGS"

    def update_logs(self, logs: list):
        """Clear log panel and write styled log lines."""
        self.clear()
        
        theme = THEME_COLORS.get(self.current_theme, THEME_COLORS["matrix-green"])
        info_color = theme["healthy"]
        warn_color = theme["warning"]
        err_color = theme["error"]
        crit_color = theme["critical"]
        muted_color = theme["muted"]

        for line in logs:
            styled_line = Text()
            
            # Detect log level and color appropriately
            if "INFO" in line:
                parts = line.split("INFO", 1)
                styled_line.append(parts[0], style=muted_color)
                styled_line.append("INFO", style=f"bold {info_color}")
                if len(parts) > 1:
                    styled_line.append(parts[1], style="white")
            elif "WARNING" in line:
                parts = line.split("WARNING", 1)
                styled_line.append(parts[0], style=muted_color)
                styled_line.append("WARNING", style=f"bold {warn_color}")
                if len(parts) > 1:
                    styled_line.append(parts[1], style="white")
            elif "ERROR" in line:
                parts = line.split("ERROR", 1)
                styled_line.append(parts[0], style=muted_color)
                styled_line.append("ERROR", style=f"bold {err_color}")
                if len(parts) > 1:
                    styled_line.append(parts[1], style="white")
            elif "CRITICAL" in line:
                parts = line.split("CRITICAL", 1)
                styled_line.append(parts[0], style=muted_color)
                styled_line.append("CRITICAL", style=f"bold {crit_color}")
                if len(parts) > 1:
                    styled_line.append(parts[1], style="white")
            else:
                # Default formatting
                styled_line.append(line, style="white")
                
            self.write_line(styled_line)
