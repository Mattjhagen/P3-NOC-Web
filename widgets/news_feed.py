from textual.widgets import DataTable
from textual.reactive import reactive
from rich.text import Text
from config.themes import THEME_COLORS

class NewsFeed(DataTable):
    """
    Displays the Bitcoin Intelligence News Feed using Textual's native DataTable.
    Automatically scrolls through analyzed headlines and colors them dynamically.
    """
    current_theme = reactive("matrix-green")
    auto_scroll_active = reactive(True)

    def on_mount(self):
        self.border_title = "NEWS FEED"
        self.cursor_type = "row"
        
        # Configure columns
        self.add_column("Status", width=6)
        self.add_column("Title", width=50)
        self.add_column("Risk", width=8)
        self.add_column("Sentiment", width=12)
        self.add_column("Importance", width=10)

        # Set up a regular timer to auto-scroll the table
        self.set_interval(1.5, self.auto_scroll_row)

    def update_articles(self, articles: list):
        """Update table data with latest articles."""
        self.clear()
        for art in articles:
            # Calculate risk (importance_score)
            risk = art.get("importance_score", 0)
            
            # Determine status dot
            if risk <= 33:
                dot = "🟢"
                row_style = "green"
            elif risk <= 66:
                dot = "🟡"
                row_style = "yellow"
            else:
                dot = "🔴"
                row_style = "red"

            # Align styles based on theme
            theme = THEME_COLORS.get(self.current_theme, THEME_COLORS["matrix-green"])
            text_style = "white"
            if row_style == "green":
                status_text = Text(dot, style=theme["healthy"])
            elif row_style == "yellow":
                status_text = Text(dot, style=theme["warning"])
            else:
                status_text = Text(dot, style=theme["error"])

            title_text = Text(art.get("title", "Untitled"), style=text_style)
            risk_text = Text(f"{risk}", style=theme["primary"] if row_style == "green" else (theme["warning"] if row_style == "yellow" else theme["error"]))
            sentiment_text = Text(art.get("sentiment", "neutral").upper(), style=text_style)
            importance_text = Text(f"{art.get('importance_score', 0)}", style=text_style)

            self.add_row(status_text, title_text, risk_text, sentiment_text, importance_text)

    def auto_scroll_row(self):
        """Automatically scroll the highlighted row if user isn't interacting."""
        if not self.auto_scroll_active or self.row_count == 0:
            return

        # If focused, don't auto scroll so the user can browse
        if self.has_focus:
            return

        current_row = self.cursor_row
        next_row = (current_row + 1) % self.row_count
        self.cursor_row = next_row

    def on_focus(self):
        # Pause auto scroll when focused
        self.auto_scroll_active = False

    def on_blur(self):
        # Resume auto scroll when blurred
        self.auto_scroll_active = True
