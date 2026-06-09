import time
import sys
import subprocess
import requests
import logging
from datetime import datetime, timedelta
from typing import Dict, List, Any
from app.config import settings
from app.database import SessionLocal, DBOperationsLog, DBProcessingQueue, DBFeedSource

logger = logging.getLogger("backend.autopilot")

class AutopilotManager:
    def __init__(self):
        self.locked = False
        self.safe_mode = False
        self.recovery_timestamps: List[datetime] = []
        self.MAX_RESTARTS_PER_HOUR = 3
        self.total_recoveries_today = 0
        self.uptime_start = datetime.utcnow()
        self.active_issues: List[str] = []
        self.actions_taken_history: List[str] = []
        self.health_score = 100
        self.overall_status = "HEALTHY"

    def get_uptime_str(self) -> str:
        dt = datetime.utcnow() - self.uptime_start
        days = dt.days
        hours = dt.seconds // 3600
        minutes = (dt.seconds % 3600) // 60
        return f"{days}d {hours}h {minutes}m"

    def log_event(self, severity: str, event: str, action: str, result: str):
        """Helper to write to operations_log table."""
        db = SessionLocal()
        try:
            log_entry = DBOperationsLog(
                severity=severity,
                event=event,
                action_taken=action,
                result=result,
                host="p3noc"
            )
            db.add(log_entry)
            db.commit()
            logger.info(f"Operations Log: [{severity}] {event} | Action: {action} | Result: {result}")
        except Exception as e:
            logger.warning(f"Could not write to operations_log database: {e}")
        finally:
            db.close()

    def check_circuit_breaker(self) -> bool:
        """Verifies if too many recoveries have occurred. Trips breaker if limits exceeded."""
        now = datetime.utcnow()
        # Filter timestamps to last 60 minutes
        self.recovery_timestamps = [t for t in self.recovery_timestamps if now - t < timedelta(hours=1)]
        
        if len(self.recovery_timestamps) >= self.MAX_RESTARTS_PER_HOUR:
            self.locked = True
            self.log_event("CRITICAL", "CIRCUIT_BREAKER_LOCKED", "LOCK_AUTOPILOT", "SUCCESS")
            return False
            
        self.recovery_timestamps.append(now)
        self.total_recoveries_today += 1
        
        # Enter safe mode if restarts >= 2 in an hour
        if len(self.recovery_timestamps) >= 2:
            self.safe_mode = True
            self.log_event("WARNING", "SAFE_MODE_ENABLED", "ENABLE_SAFE_MODE", "SUCCESS")
            
        return True

    def unlock(self):
        """Unlocks autopilot state manually."""
        self.locked = False
        self.safe_mode = False
        self.recovery_timestamps = []
        self.log_event("INFO", "AUTOPILOT_UNLOCKED", "UNLOCK_AUTOPILOT", "SUCCESS")

    # --- System Recovery Action Handlers ---

    def restart_worker(self) -> bool:
        """Restarts the systemd worker service."""
        if sys.platform.startswith("linux"):
            try:
                subprocess.run(["sudo", "systemctl", "restart", settings.SERVICE_WORKER], check=True)
                return True
            except Exception as e:
                logger.error(f"Failed to restart worker: {e}")
                return False
        else:
            logger.info("SIMULATION: restarted worker service")
            return True

    def restart_ingest(self) -> bool:
        """Restarts the systemd RSS ingest timer."""
        timer_name = settings.SERVICE_INGEST
        if not timer_name.endswith(".timer"):
            timer_name = f"{timer_name}.timer"
        if sys.platform.startswith("linux"):
            try:
                subprocess.run(["sudo", "systemctl", "restart", timer_name], check=True)
                return True
            except Exception as e:
                logger.error(f"Failed to restart ingest timer: {e}")
                return False
        else:
            logger.info(f"SIMULATION: restarted timer {timer_name}")
            return True

    def restart_ollama(self) -> bool:
        """Restarts the systemd Ollama service."""
        # Ollama runs on R510 remote server, so local restart is a fallback.
        # But we implement the recovery commands dynamically.
        if sys.platform.startswith("linux") and settings.OLLAMA_HOST in ["127.0.0.1", "localhost"]:
            try:
                subprocess.run(["sudo", "systemctl", "restart", "ollama"], check=True)
                return True
            except Exception as e:
                logger.error(f"Failed to restart Ollama: {e}")
                return False
        else:
            logger.info("SIMULATION / REMOTE: Skipped local Ollama service restart (Remote host)")
            return True

    def warm_model(self) -> bool:
        """Preloads default Ollama model in memory."""
        try:
            url = f"{settings.OLLAMA_URL}/api/generate"
            payload = {
                "model": settings.OLLAMA_MODEL,
                "prompt": "ping",
                "stream": False
            }
            res = requests.post(url, json=payload, timeout=10.0)
            return res.status_code == 200
        except Exception:
            return False

    def requeue_failed_jobs(self) -> bool:
        """Requeues failed jobs in database."""
        db = SessionLocal()
        try:
            db.query(DBProcessingQueue).filter(
                DBProcessingQueue.status.in_(["failed", "dead_letter"])
            ).update(
                {
                    DBProcessingQueue.status: "pending",
                    DBProcessingQueue.retry_count: 0,
                    DBProcessingQueue.last_error: None,
                    DBProcessingQueue.updated_at: datetime.utcnow()
                },
                synchronize_session=False
            )
            db.commit()
            return True
        except Exception as e:
            logger.error(f"Failed to requeue failed items: {e}")
            db.rollback()
            return False
        finally:
            db.close()

    def clear_stuck_processing(self) -> bool:
        """Clears processing jobs stuck > 15m by marking them failed."""
        db = SessionLocal()
        try:
            cutoff = datetime.utcnow() - timedelta(minutes=15)
            db.query(DBProcessingQueue).filter(
                DBProcessingQueue.status == "processing",
                DBProcessingQueue.updated_at <= cutoff
            ).update(
                {
                    DBProcessingQueue.status: "failed",
                    DBProcessingQueue.updated_at: datetime.utcnow()
                },
                synchronize_session=False
            )
            db.commit()
            return True
        except Exception as e:
            logger.error(f"Failed to clear stuck items: {e}")
            db.rollback()
            return False
        finally:
            db.close()

    # --- Autopilot Cycle Evaluator ---

    def execute_evaluation_cycle(self, telemetry: Dict[str, Any]):
        """Runs the self-healing and alert checks once a minute."""
        if self.locked:
            self.health_score = 10
            self.overall_status = "LOCKED"
            self.active_issues = ["AUTOPILOT LOCKED - CIRCUIT BREAKER TRIPPED"]
            return
            
        issues = []
        actions = []
        score = 100
        
        # 1. Evaluate DB Status
        # If DB connection failed or SQLite fallback is active, deduct slightly
        from app.database import is_sqlite
        if is_sqlite:
            score -= 10
            issues.append("PostgreSQL Connection Offline (SQLite Fallback)")
            
        # 2. Evaluate T310 Services (simulated/real status)
        # Check systemd status if Linux (otherwise assume running in dev mode)
        worker_online = True
        ingest_online = True
        
        # 3. Evaluate R510 Remote Telemetry
        r510_telemetry = telemetry.get("r510", {})
        r510_online = r510_telemetry.get("online", False)
        ollama_status = r510_telemetry.get("ollama_status", "OFFLINE")
        active_requests = r510_telemetry.get("active_requests", 0)
        
        # Read from DB for queue statuses
        db = SessionLocal()
        failed_count = 0
        processing_count = 0
        oldest_age_mins = 0.0
        
        try:
            failed_count = db.query(DBProcessingQueue).filter(DBProcessingQueue.status == "failed").count()
            processing_count = db.query(DBProcessingQueue).filter(DBProcessingQueue.status == "processing").count()
            
            # Oldest processing age calculation
            oldest_processing = db.query(DBProcessingQueue).filter(
                DBProcessingQueue.status == "processing"
            ).order_by(DBProcessingQueue.updated_at.asc()).first()
            if oldest_processing:
                delta = datetime.utcnow() - oldest_processing.updated_at
                oldest_age_mins = delta.total_seconds() / 60.0
        except Exception:
            # Fallback if DB query fails during transaction
            pass
        finally:
            db.close()
            
        # Check health indicators
        if not r510_online:
            score -= 25
            issues.append("AI Inference Server (R510) Unreachable")
        elif ollama_status != "ONLINE":
            score -= 20
            issues.append("Ollama Endpoint on R510 is Offline")
            
        if failed_count > 10:
            score -= min(15, failed_count // 2)
            issues.append(f"Failed Queue backlog: {failed_count} items")
            
        if processing_count > 5 and oldest_age_mins > 15:
            score -= 10
            issues.append(f"Queue Jam: processing job age > {round(oldest_age_mins)}m")

        # --- Recovery Action Triggers ---
        
        # Rule 1: Ollama Endpoint Offline
        if r510_online and ollama_status != "ONLINE":
            # If Ollama is remote, we can't run local service restart, we log event warning.
            issues.append("OLLAMA FAILURE DETECTED")
            if settings.OLLAMA_HOST in ["127.0.0.1", "localhost"]:
                if self.check_circuit_breaker():
                    self.log_event("CRITICAL", "OLLAMA_TIMEOUT_DETECTED", "RESTART_OLLAMA", "PENDING")
                    ok = self.restart_ollama()
                    res_str = "SUCCESS" if ok else "FAILED"
                    self.log_event("INFO", "OLLAMA_RESTART_COMPLETED", "RESTART_OLLAMA", res_str)
                    if ok:
                        self.warm_model()
                    actions.append("Restart Ollama")
            else:
                logger.warning("Remote Ollama Offline. Autopilot cannot run SSH restart without credentials.")
                
        # Rule 2: Queue Jam
        if processing_count > 5 and oldest_age_mins > 15:
            if self.check_circuit_breaker():
                self.log_event("WARNING", "QUEUE_JAM_DETECTED", "CLEAR_STUCK_PROCESSING", "PENDING")
                ok = self.clear_stuck_processing()
                res_str = "SUCCESS" if ok else "FAILED"
                self.log_event("INFO", "QUEUE_JAM_CLEARED", "CLEAR_STUCK_PROCESSING", res_str)
                actions.append("Clear Stuck Queue")
                
        # Rule 3: Backlog Buildup
        if failed_count > 25:
            if self.check_circuit_breaker():
                self.log_event("WARNING", "FAILED_BACKLOG_DETECTED", "REQUEUE_FAILED_JOBS", "PENDING")
                ok = self.requeue_failed_jobs()
                res_str = "SUCCESS" if ok else "FAILED"
                self.log_event("INFO", "BACKLOG_REQUEUED", "REQUEUE_FAILED_JOBS", res_str)
                actions.append("Requeue Failed Jobs")

        # Set final outputs
        score = max(10, score)
        self.health_score = score
        self.active_issues = issues
        
        self.overall_status = "HEALTHY" if score > 90 else ("DEGRADED" if score > 50 else "INCIDENT")
        if self.safe_mode:
            self.overall_status = f"{self.overall_status} (SAFE)"
            
        if actions:
            self.actions_taken_history.extend(actions)
            # Keep action history capped
            if len(self.actions_taken_history) > 10:
                self.actions_taken_history = self.actions_taken_history[-10:]

# Singleton Autopilot instance
autopilot = AutopilotManager()
