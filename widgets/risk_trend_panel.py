from textual.widgets import Static
from textual.reactive import reactive
from rich.text import Text
from config.themes import THEME_COLORS

class RiskTrendPanel(Static):
    """
    Plots a 24-hour ASCII trend graph of Bitcoin risk scores
    using custom box-drawing connectors.
    """
    risk_history = reactive([0] * 24)
    current_theme = reactive("matrix-green")

    def on_mount(self):
        self.border_title = "RISK TREND (24H)"

    def render(self) -> Text:
        theme = THEME_COLORS.get(self.current_theme, THEME_COLORS["matrix-green"])
        primary = theme["primary"]
        muted = theme["muted"]
        healthy = theme["healthy"]
        warning = theme["warning"]
        error = theme["error"]

        # Ensure we have exactly 24 data points
        history = list(self.risk_history)
        if len(history) < 24:
            history = [0] * (24 - len(history)) + history
        elif len(history) > 24:
            history = history[-24:]

        # Grid is 5 rows high (representing 0-20, 21-40, 41-60, 61-80, 81-100) by 24 cols wide
        grid = [[" " for _ in range(24)] for _ in range(5)]

        for c in range(24):
            val = history[c]
            r = min(4, int(val / 20.0))
            
            if c < 23:
                val_next = history[c + 1]
                r_next = min(4, int(val_next / 20.0))
                
                if r_next > r:
                    grid[r][c] = "╯"
                    for intermediate_r in range(r + 1, r_next):
                        grid[intermediate_r][c] = "│"
                    grid[r_next][c] = "╭"
                elif r_next < r:
                    grid[r][c] = "╮"
                    for intermediate_r in range(r_next + 1, r):
                        grid[intermediate_r][c] = "│"
                    grid[r_next][c] = "╰"
                else:
                    grid[r][c] = "─"
            else:
                grid[r][c] = "─"

        # Construct visual text
        content = Text()
        content.append("\n Hourly Risk Averages:\n\n", style=f"bold {primary}")

        labels = [
            ("100", error),
            (" 80", error),
            (" 60", warning),
            (" 40", healthy),
            (" 20", healthy)
        ]

        # Draw from top (row 4) to bottom (row 0)
        for r in range(4, -1, -1):
            label, lbl_color = labels[4 - r]
            content.append(f"  {label} ┤ ", style=lbl_color)
            
            # Print each character in the row with row-specific colors
            row_str = "".join(grid[r])
            content.append(row_str, style=lbl_color)
            content.append("\n")

        # Bottom axis
        content.append("       └─" + "─" * 24 + "\n", style=muted)
        content.append("         24h ago           now\n", style=muted)

        return content
