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
        
        # Configure columns as requested: Risk, Sentiment, Confidence, Impact, Title
        self.add_column("Risk", width=12)
        self.add_column("Sentiment", width=12)
        self.add_column("Confidence", width=12)
        self.add_column("Impact", width=14)
        self.add_column("Title", width=60)

        # Set up a regular timer to auto-scroll the table
        self.set_interval(1.5, self.auto_scroll_row)

    def classify_headline_impact(self, title: str) -> str:
        """Classify article titles into impact categories based on keywords."""
        t = title.lower()
        if any(k in t for k in ["etf", "inflow", "outflow", "blackrock", "fidelity", "grayscale"]):
            return "ETF"
        if any(k in t for k in ["whale", "transfer", "moves", "mt. gox", "gox", "satoshi"]):
            return "WHALE"
        if any(k in t for k in ["hack", "exploit", "compromise", "phish", "steal", "vulnerability", "attack", "security"]):
            return "SECURITY"
        if any(k in t for k in ["mining", "miner", "hashrate", "halving", "difficulty"]):
            return "MINING"
        if any(k in t for k in ["sec", "regulatory", "ban", "lawsuit", "court", "compliance", "government", "regulation"]):
            return "REGULATION"
        if any(k in t for k in ["exchange", "binance", "coinbase", "kraken", "insolvency", "liquidity"]):
            return "EXCHANGE"
        if any(k in t for k in ["fed", "inflation", "interest rate", "macro", "economy", "cpi", "fomc"]):
            return "MACRO"
        return "MARKET"

    def update_articles(self, articles: list):
        """Update table data with latest articles."""
        self.clear()
        for art in articles:
            # Risk (importance_score)
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
                dot_color = theme["healthy"]
            elif row_style == "yellow":
                dot_color = theme["warning"]
            else:
                dot_color = theme["error"]

            # 1. Risk column shows: Dot + Score (e.g. 🔴  87)
            risk_text = Text()
            risk_text.append(f"{dot} ", style=dot_color)
            risk_text.append(f"{risk:<3}", style=f"bold {dot_color}")

            # 2. Sentiment column
            sent_str = art.get("sentiment", "neutral").upper()
            sent_style = theme["healthy"] if "POS" in sent_str else (theme["error"] if "NEG" in sent_str else "white")
            sentiment_text = Text(sent_str, style=sent_style)

            # 3. Confidence column
            conf_text = Text(art.get("confidence", "medium").upper(), style=theme["primary"])

            # 4. Impact category
            title = art.get("title", "Untitled")
            impact_category = self.classify_headline_impact(title)
            impact_style = "bold yellow" if impact_category in ["SECURITY", "REGULATION", "EXCHANGE"] else "cyan"
            impact_text = Text(impact_category, style=impact_style)

            # 5. Title column
            title_text = Text(title, style=text_style)

            self.add_row(risk_text, sentiment_text, conf_text, impact_text, title_text)

    def auto_scroll_row(self):
        """Automatically scroll the highlighted row if user isn't interacting."""
        if not self.auto_scroll_active or self.row_count == 0:
            return

        # If focused, don't auto scroll so the user can browse
        if self.has_focus:
            return

        current_row = self.cursor_row
        next_row = (current_row + 1) % self.row_count
        self.move_cursor(row=next_row)

    def on_focus(self):
        # Pause auto scroll when focused
        self.auto_scroll_active = False

    def on_blur(self):
        # Resume auto scroll when blurred
        self.auto_scroll_active = True
