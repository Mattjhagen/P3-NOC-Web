#!/usr/bin/env python3
import argparse
import sys
import os
import subprocess
import psutil
from datetime import datetime
from textual.app import App, ComposeResult
from textual.containers import Container
from textual.widgets import Footer, Button, Static
from textual.reactive import reactive
from textual.screen import ModalScreen

# Import configuration settings and themes
from config.settings import REFRESH_RATES, OLLAMA_MODEL
from config.themes import THEMES, THEME_NAMES
from services.db_service import DBService
from services.log_service import LogService
from services.ollama_service import OllamaService
from services.feed_service import FeedService
from services.btc_ticker_service import BTCTickerService
from services.recovery_service import RecoveryService
from services.autopilot_service import AutopilotService
from services.routing_service import RoutingService

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
from widgets.sys_metrics_panel import SysMetricsPanel
from widgets.risk_trend_panel import RiskTrendPanel
from widgets.confirmation_dialog import ConfirmationDialog
from widgets.runbook_panel import RunbookPanel
from widgets.autopilot_panel import AutopilotPanel

class P3NocApp(App):
    """
    P3 NOC — Bitcoin Intelligence Operations Center TUI Dashboard (v4).
    Includes Operator Actions panel, recovery services, and smart recommendations.
    """
    CSS = """
    /* Colorway themes mapping */
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
    .matrix {
        --primary: #00ff00;
        --background: #000000;
        --border: #00ff00;
        --panel-bg: #000000;
        --text: #00ff00;
        --muted: #003300;
    }
    .bloomberg {
        --primary: #ff8800;
        --background: #000033;
        --border: #0044bb;
        --panel-bg: #000022;
        --text: #ff8800;
        --muted: #0044aa;
    }
    .trading-desk {
        --primary: #00ffff;
        --background: #1c1c1c;
        --border: #444444;
        --panel-bg: #222222;
        --text: #00ffff;
        --muted: #888888;
    }
    .midnight {
        --primary: #ffffff;
        --background: #000000;
        --border: #333333;
        --panel-bg: #000000;
        --text: #ffffff;
        --muted: #444444;
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
        height: 24;
        margin: 0 1 1 1;
    }

    #left-col {
        layout: grid;
        grid-size: 1 3;
        grid-rows: 1fr 1fr 1fr;
        row-gap: 1;
    }

    #middle-col {
        layout: grid;
        grid-size: 1 3;
        grid-rows: 1fr 1fr 1fr;
        row-gap: 1;
    }

    #right-col {
        layout: grid;
        grid-size: 1 3;
        grid-rows: 1fr 1.3fr 1.2fr; /* Ollama, Alerts, Autopilot */
        row-gap: 1;
    }

    SystemPanel, ThroughputPanel, SysMetricsPanel, RiskRadar, RiskTrendPanel, OllamaPanel, AlertPanel, RunbookPanel, NewsFeed, LogPanel, TickerWidget, AutopilotPanel {
        border: round var(--border);
        background: var(--panel-bg);
        color: var(--text);
    }

    SystemPanel:focus, ThroughputPanel:focus, SysMetricsPanel:focus, RiskRadar:focus, RiskTrendPanel:focus, OllamaPanel:focus, AlertPanel:focus, RunbookPanel:focus, NewsFeed:focus, LogPanel:focus, TickerWidget:focus, AutopilotPanel:focus {
        border: double var(--primary);
    }

    /* Wallboard Mode Formatting */
    .wallboard-mode SystemPanel, .wallboard-mode ThroughputPanel, .wallboard-mode SysMetricsPanel, .wallboard-mode RiskRadar, .wallboard-mode RiskTrendPanel, .wallboard-mode OllamaPanel, .wallboard-mode AlertPanel, .wallboard-mode RunbookPanel, .wallboard-mode NewsFeed, .wallboard-mode LogPanel, .wallboard-mode TickerWidget, .wallboard-mode AutopilotPanel {
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

    # Keyboard Bindings
    BINDINGS = [
        ("l", "focus_logs", "Focus Logs"),
        ("n", "focus_news", "Focus News"),
        ("r", "focus_risk", "Focus Risk"),
        ("w", "show_weekly_report", "Weekly Report"),
        ("f2", "next_theme", "Cycle Theme"),
        ("f3", "toggle_compact", "Toggle Compact"),
        ("f4", "toggle_fullscreen_logs", "Fullscreen Logs"),
        ("f5", "refresh_data", "Refresh Data"),
        ("f6", "restart_worker", "Restart Worker"),
        ("f7", "restart_ingest", "Restart Ingest"),
        ("f8", "requeue_failed", "Requeue Failed"),
        ("f9", "clear_stuck", "Clear Stuck"),
        ("f10", "restart_ollama", "Restart Ollama"),
        ("f11", "warm_model", "Warm Model Cache"),
        ("f12", "health_recovery", "Full Health Recovery"),
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
        self.recovery_service = RecoveryService()
        
        self.routing_service = RoutingService()
        self.autopilot_service = AutopilotService(
            db_service=self.db_service,
            recovery_service=self.recovery_service,
            feed_service=self.feed_service,
            ollama_service=self.ollama_service,
            routing_service=self.routing_service
        )
        
        # Runtime status states
        self.worker_online = True
        self.db_online = True
        self.ollama_online = True
        self.ingest_online = True
        
        # Cache OLLAMA configurations
        self.ollama_model = OLLAMA_MODEL
        
        # Startup checks failures cache
        self.startup_errors = []
        
        # Audit states
        self.last_audit_date = None
        self.latest_report_path = None

    def compose(self) -> ComposeResult:
        """Compose layout grid."""
        yield HeaderWidget()
        
        with Container(id="grid-middle"):
            with Container(id="left-col"):
                yield SystemPanel()
                yield ThroughputPanel()
                yield SysMetricsPanel()
            
            with Container(id="middle-col"):
                yield RiskRadar()
                yield RiskTrendPanel()
                yield RunbookPanel()
            
            with Container(id="right-col"):
                yield OllamaPanel()
                yield AlertPanel()
                yield AutopilotPanel()
                
        yield NewsFeed()
        yield LogPanel()
        yield TickerWidget()
        yield Footer()

    def on_mount(self):
        """Register loops and load start theme."""
        # 1. Apply default theme
        self.add_class(THEMES[self.theme_index])
        if self.wallboard_mode:
            self.add_class("wallboard-mode")
            self.set_interval(6.0, self.auto_rotate_focus)
            self.query_one(Footer).display = False

        # 2. Run Startup Health Validation
        self.run_startup_validation()

        # 3. Register background timers
        self.set_interval(REFRESH_RATES["status"], self.run_status_and_logs_update)
        self.set_interval(REFRESH_RATES["db"], self.run_db_metrics_update)
        self.set_interval(REFRESH_RATES["ticker_fetch"], self.run_btc_ticker_update)
        self.set_interval(60.0, self.run_autopilot_cycle)

        # 4. Trigger initial fetches
        self.run_status_and_logs_update()
        self.run_db_metrics_update()
        self.run_btc_ticker_update()
        self.run_autopilot_cycle()

    def run_startup_validation(self):
        """Validate PostgreSQL, services, and feed health on startup."""
        self.startup_errors = []
        
        if not self.db_service.check_db_health():
            self.startup_errors.append("PostgreSQL Connection Failed")
            
        if self.ollama_service.check_ollama_status() != "ONLINE":
            self.startup_errors.append("Ollama Endpoint Unreachable")
            
        if not self.feed_service.check_worker_service_status():
            self.startup_errors.append("Worker service Inactive")
            
        if not self.feed_service.check_ingest_service_status():
            self.startup_errors.append("Ingest service Inactive")

        if not self.db_service.get_rss_feed_health():
            self.startup_errors.append("RSS Feed Polling Failed")

        # Push to alert panel
        alerts = self.query_one(AlertPanel)
        alerts.startup_failures = self.startup_errors

    # --- Background Workers & Data Fetching Jobs ---

    def run_status_and_logs_update(self):
        self.run_worker(self._fetch_status_and_logs_job, thread=True)

    def _fetch_status_and_logs_job(self):
        try:
            worker_active = self.feed_service.check_worker_service_status()
            ingest_active = self.feed_service.check_ingest_service_status()
            db_active = self.db_service.check_db_health()
            ollama_stats = self.ollama_service.get_ollama_stats()
            logs = self.log_service.fetch_worker_logs(lines=100)
            
            # Fetch host RAM usage to feed Smart Recommendations
            ram = psutil.virtual_memory().percent
            
            self.app.call_from_thread(
                self._update_status_and_logs_ui,
                worker_active, ingest_active, db_active, ollama_stats, logs, ram
            )
        except Exception:
            pass

    def _update_status_and_logs_ui(self, worker, ingest, db, ollama_stats, logs, ram):
        self.worker_online = worker
        self.ingest_online = ingest
        self.db_online = db
        self.ollama_online = ollama_stats["status"] == "ONLINE"

        # Update Header
        header = self.query_one(HeaderWidget)
        header.worker_status = worker
        header.ingest_status = ingest
        header.db_status = db
        header.ollama_status = self.ollama_online

        # Update Ollama panel
        ollama_panel = self.query_one(OllamaPanel)
        ollama_panel.status_str = ollama_stats["status"]
        ollama_panel.model_name = ollama_stats["model"]
        ollama_panel.server_host = ollama_stats["server"]
        ollama_panel.latency_sec = float(ollama_stats["latency"].replace("s", "")) if ollama_stats["latency"] != "N/A" else 0.0
        ollama_panel.failures_count = ollama_stats["failures"]
        ollama_panel.requests_count = ollama_stats["requests"]
        self.ollama_model = ollama_stats["model"]

        # Update Log panel
        log_panel = self.query_one(LogPanel)
        log_panel.update_logs(logs)

        # Update Alerts & Recommendations panel
        alerts = self.query_one(AlertPanel)
        alerts.ollama_online = self.ollama_online
        alerts.db_online = db
        alerts.worker_active = worker
        alerts.ingest_active = ingest
        alerts.ollama_failures = ollama_stats["failures"]
        alerts.avg_time = ollama_panel.latency_sec
        alerts.host_ram_percent = ram
        alerts.env_ollama_model = OLLAMA_MODEL
        alerts.active_ollama_model = ollama_stats["model"]

    def run_db_metrics_update(self):
        self.run_worker(self._fetch_db_metrics_job, thread=True)

    def _fetch_db_metrics_job(self):
        try:
            queue_counts = self.db_service.get_queue_counts()
            throughput = self.db_service.get_queue_throughput()
            processed_today = self.db_service.get_processed_today()
            risk_history = self.db_service.get_hourly_risk_history()
            latest_articles = self.db_service.get_latest_articles(limit=50)
            latest_analysis = self.db_service.get_latest_analysis()
            
            self.app.call_from_thread(
                self._update_db_metrics_ui,
                queue_counts, throughput, processed_today, risk_history, latest_articles, latest_analysis
            )
        except Exception:
            pass

    def _update_db_metrics_ui(self, queue_counts, throughput, processed_today, risk_history, latest_articles, latest_analysis):
        # Update System counts
        system_panel = self.query_one(SystemPanel)
        system_panel.pending_count = queue_counts["pending"]
        system_panel.processing_count = queue_counts["processing"]
        system_panel.completed_count = queue_counts["completed"]
        system_panel.failed_count = queue_counts["failed"]

        # Update Throughput
        tp_panel = self.query_one(ThroughputPanel)
        tp_panel.processed_last_hour = throughput["processed_last_hour"]
        tp_panel.processed_today = processed_today
        tp_panel.avg_time = throughput["avg_time"]
        tp_panel.remaining = throughput["remaining"]
        tp_panel.eta_str = throughput["eta_str"]
        
        total = queue_counts["completed"] + queue_counts["failed"]
        efficiency = (queue_counts["completed"] / max(total, 1)) * 100.0
        tp_panel.worker_efficiency = efficiency

        # Update Alerts
        alerts = self.query_one(AlertPanel)
        alerts.max_retry = throughput["max_retry"]
        alerts.failed_queue_count = queue_counts["failed"]
        alerts.worker_efficiency = efficiency
        alerts.queue_processing_count = queue_counts["processing"]

        # Update header Giant NOC Status Banner variables
        header = self.query_one(HeaderWidget)
        header.worker_efficiency = efficiency
        header.avg_time = throughput["avg_time"]

        # Update Risk Trend graph
        trend_panel = self.query_one(RiskTrendPanel)
        trend_panel.risk_history = risk_history

        # Update news feed table
        news = self.query_one(NewsFeed)
        news.update_articles(latest_articles)

        # Update Risk Radar
        risk_radar = self.query_one(RiskRadar)
        if latest_analysis:
            risk_radar.risk_score = latest_analysis.get("importance_score", 0)
            risk_radar.sentiment_str = latest_analysis.get("sentiment", "Neutral")
            risk_radar.sentiment_score = latest_analysis.get("sentiment_score", 0.0)
            risk_radar.importance_score = latest_analysis.get("importance_score", 0)
            risk_radar.confidence_str = latest_analysis.get("confidence", "medium")
            
            alerts.latest_risk_score = latest_analysis.get("importance_score", 0)
            
            # Feed header summary banner
            header.risk_score = latest_analysis.get("importance_score", 0)
            header.queue_remaining = throughput["remaining"]
            header.eta_str = throughput["eta_str"]
            header.top_event_str = latest_analysis.get("title", "No headlines yet.")

            ticker = self.query_one(TickerWidget)
            ticker.latest_title = latest_analysis.get("title", "No headlines yet.")

        # Update ticker stats
        ticker = self.query_one(TickerWidget)
        ticker.queue_remaining = throughput["remaining"]
        ticker.eta_str = throughput["eta_str"]
        ticker.ollama_status = "ONLINE" if self.ollama_online else "OFFLINE"

    def run_btc_ticker_update(self):
        self.run_worker(self._fetch_btc_ticker_job, thread=True)

    def _fetch_btc_ticker_job(self):
        try:
            btc_data = self.ticker_service.fetch_btc_price()
            self.app.call_from_thread(self._update_btc_ticker_ui, btc_data)
        except Exception:
            pass

    def _update_btc_ticker_ui(self, btc_data):
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
        self.query_one(LogPanel).focus()

    def action_focus_news(self):
        self.query_one(NewsFeed).focus()

    def action_focus_risk(self):
        self.query_one(RiskRadar).focus()

    def action_next_theme(self):
        """F2: Cycle theme."""
        self.theme_index = (self.theme_index + 1) % len(THEMES)
        new_theme = THEMES[self.theme_index]
        
        # Reset classes
        for t in THEMES:
            self.remove_class(t)
        self.add_class(new_theme)
        if self.wallboard_mode:
            self.add_class("wallboard-mode")
        
        # Push reactive theme update to all widgets
        self.query_one(HeaderWidget).current_theme = new_theme
        self.query_one(SystemPanel).current_theme = new_theme
        self.query_one(ThroughputPanel).current_theme = new_theme
        self.query_one(SysMetricsPanel).current_theme = new_theme
        self.query_one(OllamaPanel).current_theme = new_theme
        self.query_one(AlertPanel).current_theme = new_theme
        self.query_one(RiskRadar).current_theme = new_theme
        self.query_one(RiskTrendPanel).current_theme = new_theme
        self.query_one(RunbookPanel).current_theme = new_theme
        self.query_one(NewsFeed).current_theme = new_theme
        self.query_one(LogPanel).current_theme = new_theme
        self.query_one(TickerWidget).current_theme = new_theme
        self.query_one(AutopilotPanel).current_theme = new_theme
        
        self.notify(f"Theme switched to: {THEME_NAMES[new_theme]}")

    def action_toggle_compact(self):
        header = self.query_one(HeaderWidget)
        header.compact_mode = not header.compact_mode

    def action_toggle_fullscreen_logs(self):
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

    def action_refresh_data(self):
        """F5: Manual refresh."""
        self.run_status_and_logs_update()
        self.run_db_metrics_update()
        self.run_btc_ticker_update()
        self.notify("Dashboard metrics manual refresh triggered.")

    # --- Operator recovery actions ---

    def action_restart_worker(self):
        """F6: Restart Worker service."""
        def check_result(confirm: bool) -> None:
            if confirm:
                res = self.recovery_service.restart_worker()
                if res:
                    self.notify("Worker service restart command sent.")
                else:
                    self.notify("Worker service restart failed.", severity="error")

        self.push_screen(
            ConfirmationDialog("Are you sure you want to RESTART the Worker service?", theme_name=THEMES[self.theme_index]),
            check_result
        )

    def action_restart_ingest(self):
        """F7: Restart RSS Ingest timer."""
        def check_result(confirm: bool) -> None:
            if confirm:
                res = self.recovery_service.restart_ingest()
                if res:
                    self.notify("RSS Ingest Timer restart command sent.")
                else:
                    self.notify("RSS Ingest Timer restart failed.", severity="error")

        self.push_screen(
            ConfirmationDialog("Are you sure you want to RESTART the RSS Ingest timer?", theme_name=THEMES[self.theme_index]),
            check_result
        )

    def action_requeue_failed(self):
        """F8: Requeue Failed Queue Jobs."""
        def check_result(confirm: bool) -> None:
            if confirm:
                res = self.recovery_service.requeue_failed()
                if res:
                    self.notify("Successfully requeued failed and dead letter items.")
                    self.run_db_metrics_update()
                else:
                    self.notify("Failed to update PostgreSQL queue.", severity="error")

        self.push_screen(
            ConfirmationDialog("Are you sure you want to REQUEUE all failed items?", theme_name=THEMES[self.theme_index]),
            check_result
        )

    def action_clear_stuck(self):
        """F9: Clear Stuck Processing (>15m)."""
        def check_result(confirm: bool) -> None:
            if confirm:
                res = self.recovery_service.clear_stuck_processing()
                if res:
                    self.notify("Successfully cleared stuck processing items.")
                    self.run_db_metrics_update()
                else:
                    self.notify("Failed to clear stuck processing items.", severity="error")

        self.push_screen(
            ConfirmationDialog("Are you sure you want to CLEAR stuck processing items?", theme_name=THEMES[self.theme_index]),
            check_result
        )

    def action_restart_ollama(self):
        """F10: Restart Ollama service."""
        def check_result(confirm: bool) -> None:
            if confirm:
                # Runs restart in background since ping tags checking takes a few seconds
                self.run_worker(self._restart_ollama_job, thread=True)

        self.push_screen(
            ConfirmationDialog("Are you sure you want to RESTART the Ollama service?", theme_name=THEMES[self.theme_index]),
            check_result
        )

    def _restart_ollama_job(self):
        self.notify("Restarting Ollama service. Verifying status...")
        res = self.recovery_service.restart_ollama()
        if res:
            self.notify("Ollama service restarted successfully. Active tags confirmed.")
        else:
            self.notify("Ollama restart failed or service timed out.", severity="error")

    def action_warm_model(self):
        """F11: Warm Model Cache."""
        self.notify(f"Pre-loading cache for model: {self.ollama_model}...")
        self.run_worker(self._warm_model_job, thread=True)

    def _warm_model_job(self):
        res = self.recovery_service.warm_model(self.ollama_model)
        if res:
            self.notify(f"Cache preloaded successfully for model '{self.ollama_model}'.")
        else:
            self.notify(f"Failed to preload model cache for '{self.ollama_model}'.", severity="warning")

    def action_health_recovery(self):
        """F12: Full Health Recovery."""
        def check_result(confirm: bool) -> None:
            if confirm:
                self.notify("Executing Full operational Health Recovery Runbook...")
                self.run_worker(self._health_recovery_job, thread=True)

        self.push_screen(
            ConfirmationDialog("Execute FULL operational runbook recovery audit?", theme_name=THEMES[self.theme_index]),
            check_result
        )

    def _health_recovery_job(self):
        try:
            self.autopilot_service.unlock_autopilot()
            results = self.recovery_service.execute_health_recovery(self.ollama_model)
            
            # Build checklist notification
            checklist_lines = []
            for name, ok in results:
                status_icon = "✓" if ok else "✗"
                checklist_lines.append(f"[{status_icon}] {name}")
            
            notification_msg = "Full Recovery Audit completed & Autopilot Unlocked:\n" + "\n".join(checklist_lines)
            self.notify(notification_msg, severity="info" if all(ok for _, ok in results) else "warning")
            
            # Re-fetch UI metrics
            self.run_status_and_logs_update()
            self.run_db_metrics_update()
            self.run_btc_ticker_update()
            self.run_autopilot_cycle()
        except Exception as e:
            self.notify(f"Health recovery runbook execution error: {e}", severity="error")

    def action_quit_app(self):
        self.exit()

    def auto_rotate_focus(self):
        widgets = [
            self.query_one(RiskRadar),
            self.query_one(NewsFeed),
            self.query_one(LogPanel)
        ]
        current_focus = self.focused
        next_focus_index = 0
        for i, w in enumerate(widgets):
            if w == current_focus:
                next_focus_index = (i + 1) % len(widgets)
                break
        widgets[next_focus_index].focus()

    # --- Autopilot Service Background Workers ---

    def run_autopilot_cycle(self):
        self.run_worker(self._autopilot_cycle_job, thread=True)

    def _autopilot_cycle_job(self):
        try:
            # 1. Gather all metrics needed for telemetry
            db_ok = self.db_service.check_db_health()
            worker_ok = self.feed_service.check_worker_service_status()
            ingest_ok = self.feed_service.check_ingest_service_status()
            ollama_stats = self.ollama_service.get_ollama_stats()
            
            queue_counts = self.db_service.get_queue_counts()
            oldest_age = self.db_service.get_oldest_processing_age()
            throughput = self.db_service.get_queue_throughput()
            
            cpu = psutil.cpu_percent()
            ram = psutil.virtual_memory().percent
            
            telemetry = {
                "db_online": db_ok,
                "worker_online": worker_ok,
                "ingest_online": ingest_ok,
                "ollama_online": ollama_stats["status"] == "ONLINE",
                "failed_queue": queue_counts["failed"],
                "processing_queue": queue_counts["processing"],
                "oldest_processing_age_mins": oldest_age,
                "ollama_failures": ollama_stats["failures"],
                "cpu": cpu,
                "ram": ram,
                "queue_remaining": throughput["remaining"],
                "avg_latency": throughput["avg_time"]
            }
            
            # 2. Run autopilot cycle on the AutopilotService
            health_state = self.autopilot_service.execute_autopilot_cycle(telemetry)
            
            # 3. Retrieve the last 4 operations actions
            last_actions = self.db_service.get_last_operations_actions(limit=4)
            
            # 4. Trigger UI update
            self.app.call_from_thread(self._update_autopilot_ui, health_state, last_actions)
            
            # 5. Check if today is Sunday to run/generate weekly report
            now = datetime.now()
            if now.weekday() == 6:  # Sunday
                date_str = now.strftime("%Y-%m-%d")
                if self.last_audit_date != date_str:
                    self.generate_weekly_report(date_str)
        except Exception as e:
            logger.error(f"Error in autopilot cycle job: {e}")

    def _update_autopilot_ui(self, health_state, last_actions):
        try:
            # Update Autopilot panel
            ap_panel = self.query_one(AutopilotPanel)
            ap_panel.status_str = health_state.overall_status
            ap_panel.health_score = health_state.score
            ap_panel.uptime_days = self.autopilot_service.get_uptime_days()
            ap_panel.actions_today = self.autopilot_service.total_recoveries_today
            ap_panel.last_actions_list = last_actions
            
            # Update Alert panel values
            alerts = self.query_one(AlertPanel)
            alerts.autopilot_locked = self.autopilot_service.locked
            alerts.predictive_alerts = self.autopilot_service.predictive_alerts
            
            # Update Header status_str
            header = self.query_one(HeaderWidget)
            header.status_str = health_state.overall_status
        except Exception as e:
            logger.error(f"Error updating autopilot UI: {e}")

    def generate_weekly_report(self, date_str):
        try:
            metrics = self.db_service.get_weekly_audit_metrics()
            
            status = "LOCKED" if self.autopilot_service.locked else ("SAFE" if self.autopilot_service.safe_mode else "ACTIVE")
            try:
                health_score = self.query_one(AutopilotPanel).health_score
            except Exception:
                health_score = 100
                
            uptime_days = self.autopilot_service.get_uptime_days()
            
            report_content = f"""# P3 NOC — Weekly Autonomous Audit Report
Date: {date_str}

## System Performance Metrics (Last 7 Days)
- Processed Articles: {metrics.get('processed', 0)}
- Failed Queue Items: {metrics.get('failed', 0)}
- Auto Recoveries Executed: {metrics.get('recovered', 0)}
- Average Inference Latency: {metrics.get('avg_latency', 0.0):.2f}s

## Subsystem Health Assessment
- Autopilot Status: {status}
- Health Score: {health_score}/100
- Host Uptime: {uptime_days} Days

Report generated autonomously by P3 NOC Autopilot.
"""
            report_dir = "/opt/p3-noc/reports"
            try:
                os.makedirs(report_dir, exist_ok=True)
            except Exception:
                report_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "reports")
                os.makedirs(report_dir, exist_ok=True)
                
            report_path = os.path.join(report_dir, f"{date_str}-weekly-report.md")
            with open(report_path, "w") as f:
                f.write(report_content)
                
            self.last_audit_date = date_str
            self.latest_report_path = report_path
            self.app.call_from_thread(self.notify, f"Weekly audit report generated: {os.path.basename(report_path)}")
        except Exception as e:
            logger.error(f"Failed to generate weekly report: {e}")

    def action_show_weekly_report(self):
        """Display the weekly report."""
        if not self.latest_report_path or not os.path.exists(self.latest_report_path):
            self.notify("Generating current week report on demand...")
            self.run_worker(self._generate_and_show_report_job, thread=True)
        else:
            self._show_report_modal(self.latest_report_path)

    def _generate_and_show_report_job(self):
        try:
            today_str = datetime.now().strftime("%Y-%m-%d")
            self.generate_weekly_report(today_str)
            self.app.call_from_thread(self._show_report_modal, self.latest_report_path)
        except Exception as e:
            logger.error(f"Error generating/showing report on demand: {e}")
            self.app.call_from_thread(self.notify, "Failed to generate report on demand", severity="error")

    def _show_report_modal(self, filepath):
        try:
            with open(filepath, "r") as f:
                content = f.read()
            self.push_screen(
                WeeklyReportDialog(
                    title=f"WEEKLY AUDIT REPORT: {os.path.basename(filepath)}",
                    report_text=content,
                    theme_name=THEMES[self.theme_index]
                )
            )
        except Exception as e:
            self.notify(f"Could not read report file: {e}", severity="error")

# --- Weekly Report Dialog & Autopilot Helpers ---

class WeeklyReportDialog(ModalScreen):
    CSS = """
    WeeklyReportDialog {
        align: center middle;
    }
    #report-box {
        padding: 1 2;
        width: 65;
        height: 18;
        border: thick var(--primary, #00ff00);
        background: var(--background, #001100);
        color: var(--text, #00ff00);
    }
    #report-title {
        text-align: center;
        text-style: bold;
        background: var(--primary);
        color: var(--background);
        margin-bottom: 1;
    }
    #report-body {
        height: 10;
        margin-bottom: 1;
        overflow-y: scroll;
    }
    #close-btn {
        width: 100%;
    }
    """

    def __init__(self, title: str, report_text: str, theme_name="matrix-green", **kwargs):
        super().__init__(**kwargs)
        self.title = title
        self.report_text = report_text
        self.theme_name = theme_name

    def compose(self):
        yield Container(
            Static(self.title, id="report-title"),
            Static(self.report_text, id="report-body"),
            Button("Close [Esc/Enter]", variant="primary", id="close-btn"),
            id="report-box"
        )

    def on_mount(self):
        theme = THEME_COLORS.get(self.theme_name, THEME_COLORS["matrix-green"])
        primary = theme["primary"]
        self.styles.border = ("thick", primary)

    def on_button_pressed(self, event: Button.Pressed) -> None:
        if event.button.id == "close-btn":
            self.dismiss()

    def on_key(self, event) -> None:
        if event.key in ("escape", "enter", "space"):
            self.dismiss()

# --- Entry Point ---
if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="P3 NOC — Bitcoin Intelligence Operations Center")
    parser.add_argument("--wallboard", action="store_true", help="Launch in wallboard mode (auto-focus rotation, double border, no footer)")
    args = parser.parse_args()

    app = P3NocApp(wallboard_mode=args.wallboard)
    app.run()
