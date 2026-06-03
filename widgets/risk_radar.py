from textual.widgets import Static
from textual.reactive import reactive
from rich.text import Text
from rich.align import Align
from config.themes import THEME_COLORS

class RiskRadar(Static):
    """
    Displays the primary risk intelligence radar:
    renders a stylized ASCII circular dial that dynamically changes color
    based on the latest article's importance/risk score (0-100).
    """
    risk_score = reactive(0)
    sentiment_str = reactive("Neutral")
    sentiment_score = reactive(0.0)
    importance_score = reactive(0)
    confidence_str = reactive("medium")
    
    current_theme = reactive("matrix-green")

    def on_mount(self):
        self.border_title = "RISK RADAR"

    def render(self) -> Align:
        theme = THEME_COLORS.get(self.current_theme, THEME_COLORS["matrix-green"])
        primary = theme["primary"]
        muted = theme["muted"]
        healthy = theme["healthy"]
        warning = theme["warning"]
        error = theme["error"]

        # Color mapping for risk dial:
        # 0-33 = Green
        # 34-66 = Yellow
        # 67-100 = Red
        if self.risk_score <= 33:
            dial_color = healthy
        elif self.risk_score <= 66:
            dial_color = warning
        else:
            dial_color = error

        content = Text()
        content.append("\n")
        
        # Draw dynamic ASCII circle
        dial_lines = [
            f"       , - ~ ~ ~ - ,       ",
            f"   , '               ' ,   ",
            f"  ,                     ,  ",
            f" ,         [bold {dial_color}]{self.risk_score:>3}/100[/bold {dial_color}]        , ",
            f"  ,                     ,  ",
            f"   ,                 , '   ",
            f"     ' - _ _ _ _ _ '       "
        ]
        
        for line in dial_lines:
            content.append("    ") # left padding
            content.append_markup(f"[{dial_color}]{line}[/{dial_color}]\n")
            
        content.append("\n")
        
        # Details section
        def add_detail(label: str, val_str: str, val_style: str):
            content.append("  ")
            content.append(f"{label:<12}", style="white")
            content.append(f"{val_str}\n", style=val_style)

        # Sentiment mappings for display
        sentiment_label = self.sentiment_str.capitalize()
        sent_style = healthy if "pos" in self.sentiment_str.lower() else (error if "neg" in self.sentiment_str.lower() else "white")
        
        add_detail("Sentiment:", f"{sentiment_label} ({self.sentiment_score:+.2f})", sent_style)
        add_detail("Importance:", f"{self.importance_score}/100", primary)
        add_detail("Confidence:", self.confidence_str.upper(), primary)

        return Align.center(content)
