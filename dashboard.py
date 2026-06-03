#!/usr/bin/env python3
import argparse
import sys
from datetime import datetime
from textual.app import App, ComposeResult
from textual.containers import Container
from textual.widgets import Footer
from textual.reactive import reactive
from config.settings import REFRESH_RATES
from config.themes import THEMES, THEME_NAMES
from services.db_service import DBService
from services.log_service import LogService
from services.ollama_service import OllamaService
from services.feed_service import FeedService
from services.btc_ticker_service import BTCTickerService

# Import custom widgets
from widgets.header import HeaderWidget
from widgets.system_panel import SystemPanel
from widgets.throughput_panel import ThroughputPanel
from widgets.ollama_panel import OllamaPanel
from widgets.alert_panel import AlertPanel
from widgets.risk_radar import RiskRadar
from widgets.news_feed import NewsFeed
from widgets.log_panel import LogPanel
from widgets.ticker import TickerWidget

class P3NocApp(App):
    """
    P3 NOC - Bitcoin Intelligence Operations Center terminal dashboard.
    """
    # TCSS Stylesheet configuration for the grid and dynamic themes
    CSS = """
    /* Theme color variables */
    .matrix-green {
        --primary: #00ff00;
        --background: #020a02;
        --border: #008800;
        --panel-bg: #041404;
        --text: #00ff00;
        --muted: #005500;
    }
    .amber-crt {
        --primary: #ffb000;
        --background: #0a0600;
        --border: #aa7000;
        --panel-bg: #140d00;
        --text: #ffb000;
        --muted: #773c00;
    }
    .cyber-blue {
        --primary: #00f0ff;
        --background: #000911;
        --border: #006699;
        --panel-bg: #001222;
        --text: #00f0ff;
        --muted: #004466;
    }
    .red-alert {
        --primary: #ff3333;
        --background: #110000;
        --border: #880000;
        --panel-bg: #220000;
        --text: #ff3333;
        --muted: #550000;
    }

    Screen {
        background: var(--background);
        color: var(--text);
    }

    HeaderWidget {
        height: auto;
        margin: 0 1;
        background: transparent;
    }

    #grid-middle {
        layout: grid;
        grid-size: 3;
        grid-columns: 1fr 1.5fr 1fr;
        height: 18;
        margin: 0 1 1 1;
    }

    #left-col {
        layout: grid;
        grid-size: 1 2;
        grid-rows: 1fr 1fr;
        row-gap: 1;
    }

    #right-col {
        layout: grid;
        grid-size: 1 2;
        grid-rows: 1fr 1fr;
        row-gap: 1;
    }

    SystemPanel, ThroughputPanel, RiskRadar, OllamaPanel, AlertPanel, NewsFeed, LogPanel, TickerWidget {
        border: round var(--border);
        background: var(--panel-bg);
        color: var(--text);
    }

    SystemPanel:focus, ThroughputPanel:focus, RiskRadar:focus, OllamaPanel:focus, AlertPanel:focus, NewsFeed:focus, LogPanel:focus, TickerWidget:focus {
        border: double var(--primary);
    }

    NewsFeed {
        height: 9;
        margin: 0 1 1 1;
    }

    LogPanel {
        height: 9;
        margin: 0 1 1 1;
    }

    TickerWidget {
        height: 3;
        margin: 0 1;
        background: var(--panel-bg);
    }
    """

    # Interactive key bindings
    BINDINGS = [
        ("l", "focus_logs", "Focus Logs"),
        ("n", "focus_news", "Focus News"),
        ("r", "focus_risk", "Focus Risk"),
        ("f2", "next_theme", "Cycle Theme"),
        ("f3", "toggle_compact", "Toggle Compact"),
        ("f4", "toggle_fullscreen_logs", "Fullscreen Logs"),
        ("q", "quit_app", "Quit"),
    ]

    def __init__(self, wallboard_mode=False, **kwargs):
        super().__init__(**kwargs)
        self.wallboard_mode = wallboard_mode
        self.theme_index = 0
        self.logs_fullscreen = False
        
        # Initialize services
        self.db_service = DBService()
        self.log_service = LogService()
        self.ollama_service = OllamaService()
        self.feed_service = FeedService()
        self.ticker_service = BTCTickerService()
        
        # Operational variables to cache statuses for widgets
        self.latest_btc = {"price_str": "$104,321", "change_str": "+2.4%", "is_positive": True}
        self.worker_online = True
        self.db_online = True
        self.ollama_online = True
        self.ingest_online = True

    def compose(self) -> ComposeResult:
        """Compose the layout and mount widgets."""
        yield HeaderWidget()
        
        with Container(id="grid-middle"):
            with Container(id="left-col"):
                yield SystemPanel()
                yield ThroughputPanel()
            
            yield RiskRadar()
            
            with Container(id="right-col"):
                yield OllamaPanel()
                yield AlertPanel()
                
        yield NewsFeed()
        yield LogPanel()
        yield TickerWidget()
        yield Footer()

    def on_mount(self):
        """Register update timers and start default theme class."""
        self.add_class(THEMES[self.theme_index])
        
        # 1. Start update intervals
        self.set_interval(REFRESH_RATES["status"], self.run_status_and_logs_update)
        self.set_interval(REFRESH_RATES["db"], self.run_db_metrics_update)
        self.set_interval(REFRESH_RATES["ticker_fetch"], self.run_btc_ticker_update)

        # 2. If in wallboard mode, register auto-rotation timer and hide footer/instructions
        if self.wallboard_mode:
            self.set_interval(6.0, self.auto_rotate_focus)
            # Hide the interactive footer to make it feel like a TV display
            self.query_one(Footer).display = False

        # 3. Trigger immediate updates to avoid blank dashboards
        self.run_status_and_logs_update()
        self.run_db_metrics_update()
        self.run_btc_ticker_update()

    # --- Background Workers & Data Fetching Jobs ---

    def run_status_and_logs_update(self):
        """Offload status checking and log fetching to a worker thread."""
        self.run_worker(self._fetch_status_and_logs_job, thread=True)

    def _fetch_status_and_logs_job(self):
        """Executes actual status and log queries in background thread."""
        try:
            # Check services status
            worker_active = self.feed_service.check_worker_service_status()
            ingest_active = self.feed_service.check_ingest_service_status()
            
            # Check db and ollama status
            db_active = self.db_service.check_db_health()
            ollama_stats = self.ollama_service.get_ollama_stats()
            ollama_active = ollama_stats["status"] == "ONLINE"
            
            # Fetch log stream
            logs = self.log_service.fetch_worker_logs(lines=100)
            
            # Dispatch UI updates back to Textual main thread
            self.app.call_from_thread(
                self._update_status_and_logs_ui,
                worker_active, ingest_active, db_active, ollama_stats, logs
            )
        except Exception as e:
            # Catch exceptions in thread to prevent crashes
            pass

    def _update_status_and_logs_ui(self, worker, ingest, db, ollama_stats, logs):
        """Update statuses and logs in UI widgets."""
        self.worker_online = worker
        self.ingest_online = ingest
        self.db_online = db
        self.ollama_online = ollama_stats["status"] == "ONLINE"

        # Update Header service bullets
        header = self.query_one(HeaderWidget)
        header.worker_status = worker
        header.ingest_status = ingest
        header.db_status = db
        header.ollama_status = self.ollama_online

        # Update Ollama panel details
        ollama_panel = self.query_one(OllamaPanel)
        ollama_panel.status_str = ollama_stats["status"]
        ollama_panel.model_name = ollama_stats["model"]
        ollama_panel.server_host = ollama_stats["server"]
        ollama_panel.latency_str = ollama_stats["latency"]
        ollama_panel.failures_count = ollama_stats["failures"]
        ollama_panel.requests_count = ollama_stats["requests"]

        # Update Log panel
        log_panel = self.query_one(LogPanel)
        log_panel.update_logs(logs)

        # Update Alerts panel
        alerts = self.query_one(AlertPanel)
        alerts.ollama_online = self.ollama_online
        alerts.db_online = db
        alerts.worker_active = worker
        alerts.ingest_active = ingest
        alerts.ollama_failures = ollama_stats["failures"]

    def run_db_metrics_update(self):
        """Offload database metrics fetching to a worker thread."""
        self.run_worker(self._fetch_db_metrics_job, thread=True)

    def _fetch_db_metrics_job(self):
        """Executes database metrics queries in background thread."""
        try:
            queue_counts = self.db_service.get_queue_counts()
            throughput = self.db_service.get_queue_throughput()
            latest_articles = self.db_service.get_latest_articles(limit=50)
            latest_analysis = self.db_service.get_latest_analysis()
            
            self.app.call_from_thread(
                self._update_db_metrics_ui,
                queue_counts, throughput, latest_articles, latest_analysis
            )
        except Exception as e:
            pass

    def _update_db_metrics_ui(self, queue_counts, throughput, latest_articles, latest_analysis):
        """Update db metrics in UI widgets."""
        # Update System panel counts
        system_panel = self.query_one(SystemPanel)
        system_panel.pending_count = queue_counts["pending"]
        system_panel.processing_count = queue_counts["processing"]
        system_panel.completed_count = queue_counts["completed"]
        system_panel.failed_count = queue_counts["failed"]

        # Update Throughput panel
        tp_panel = self.query_one(ThroughputPanel)
        tp_panel.processed_last_hour = throughput["processed_last_hour"]
        tp_panel.avg_time = throughput["avg_time"]
        tp_panel.remaining = throughput["remaining"]
        tp_panel.eta_str = throughput["eta_str"]

        # Update news feed table
        news = self.query_one(NewsFeed)
        news.update_articles(latest_articles)

        # Update Risk Radar metrics
        risk_radar = self.query_one(RiskRadar)
        if latest_analysis:
            risk_radar.risk_score = latest_analysis.get("importance_score", 0)
            risk_radar.sentiment_str = latest_analysis.get("sentiment", "Neutral")
            risk_radar.sentiment_score = latest_analysis.get("sentiment_score", 0.0)
            risk_radar.importance_score = latest_analysis.get("importance_score", 0)
            risk_radar.confidence_str = latest_analysis.get("confidence", "medium")
            
            # Feed latest headline to ticker and alert panel
            ticker = self.query_one(TickerWidget)
            ticker.latest_title = latest_analysis.get("title", "No headlines yet.")
            
            alerts = self.query_one(AlertPanel)
            alerts.latest_risk_score = latest_analysis.get("importance_score", 0)
        
        # Update Alerts panel metadata
        alerts = self.query_one(AlertPanel)
        alerts.max_retry = throughput["max_retry"]
        alerts.failed_queue_count = queue_counts["failed"]

        # Update ticker stats
        ticker = self.query_one(TickerWidget)
        ticker.queue_remaining = throughput["remaining"]
        ticker.eta_str = throughput["eta_str"]
        ticker.ollama_status = "ONLINE" if self.ollama_online else "OFFLINE"

    def run_btc_ticker_update(self):
        """Offload BTC ticker fetching to a worker thread."""
        self.run_worker(self._fetch_btc_ticker_job, thread=True)

    def _fetch_btc_ticker_job(self):
        """Executes API requests to fetch BTC price in background thread."""
        try:
            btc_data = self.ticker_service.fetch_btc_price()
            self.app.call_from_thread(self._update_btc_ticker_ui, btc_data)
        except Exception as e:
            pass

    def _update_btc_ticker_ui(self, btc_data):
        """Update BTC ticker in UI widgets."""
        self.latest_btc = btc_data

        # Update header and ticker widget
        header = self.query_one(HeaderWidget)
        header.btc_price_str = btc_data["price_str"]
        header.btc_change_str = btc_data["change_str"]
        header.btc_positive = btc_data["is_positive"]

        ticker = self.query_one(TickerWidget)
        ticker.btc_price_str = btc_data["price_str"]
        ticker.btc_change_str = btc_data["change_str"]
        ticker.btc_positive = btc_data["is_positive"]

    # --- Actions / Keyboard Bindings handlers ---

    def action_focus_logs(self):
        """Key L: Focus the logs panel."""
        self.query_one(LogPanel).focus()

    def action_focus_news(self):
        """Key N: Focus the news feed."""
        self.query_one(NewsFeed).focus()

    def action_focus_risk(self):
        """Key R: Focus the Risk Radar panel."""
        self.query_one(RiskRadar).focus()

    def action_next_theme(self):
        """Key F2: Cycle dashboard theme class."""
        self.theme_index = (self.theme_index + 1) % len(THEMES)
        new_theme = THEMES[self.theme_index]
        
        # Reset classes
        for t in THEMES:
            self.remove_class(t)
        self.add_class(new_theme)
        
        # Push reactive theme update to all widgets
        self.query_one(HeaderWidget).current_theme = new_theme
        self.query_one(SystemPanel).current_theme = new_theme
        self.query_one(ThroughputPanel).current_theme = new_theme
        self.query_one(OllamaPanel).current_theme = new_theme
        self.query_one(AlertPanel).current_theme = new_theme
        self.query_one(RiskRadar).current_theme = new_theme
        self.query_one(NewsFeed).current_theme = new_theme
        self.query_one(LogPanel).current_theme = new_theme
        self.query_one(TickerWidget).current_theme = new_theme
        
        self.notify(f"Theme switched to: {THEME_NAMES[new_theme]}")

    def action_toggle_compact(self):
        """Key F3: Toggle compact mode."""
        header = self.query_one(HeaderWidget)
        header.compact_mode = not header.compact_mode

    def action_toggle_fullscreen_logs(self):
        """Key F4: Toggle fullscreen logs mode."""
        self.logs_fullscreen = not self.logs_fullscreen
        grid_mid = self.query_one("#grid-middle")
        news = self.query_one(NewsFeed)
        header = self.query_one(HeaderWidget)
        
        if self.logs_fullscreen:
            grid_mid.display = False
            news.display = False
            header.display = False
        else:
            grid_mid.display = True
            news.display = True
            header.display = True

    def action_quit_app(self):
        """Key Q: Exit the dashboard."""
        self.exit()

    def auto_rotate_focus(self):
        """Automatically rotates focus between the panels (wallboard mode)."""
        widgets = [
            self.query_one(RiskRadar),
            self.query_one(NewsFeed),
            self.query_one(LogPanel)
        ]
        
        # Check which widget currently has focus and cycle to next
        current_focus = self.focused
        next_focus_index = 0
        
        for i, w in enumerate(widgets):
            if w == current_focus:
                next_focus_index = (i + 1) % len(widgets)
                break
                
        widgets[next_focus_index].focus()

# --- Entry Point ---
if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="P3 NOC - Bitcoin Intelligence Operations Center")
    parser.add_argument("--wallboard", action="store_true", help="Launch in wallboard mode (auto-focus rotation, no keyboard footer)")
    args = parser.parse_args()

    app = P3NocApp(wallboard_mode=args.wallboard)
    app.run()
