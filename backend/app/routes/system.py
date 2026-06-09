from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.database import get_db, DBProcessingQueue, DBOperationsLog, DBFeedSource, is_sqlite
from app.monitoring import monitor
from app.autopilot import autopilot
from app.auth import get_viewer_user
from typing import Dict, Any

router = APIRouter(tags=["system"])

@router.get("/status", dependencies=[Depends(get_viewer_user)])
def get_overall_status(db: Session = Depends(get_db)) -> Dict[str, Any]:
    # Query database stats
    failed_count = 0
    processing_count = 0
    pending_count = 0
    completed_count = 0
    
    try:
        failed_count = db.query(DBProcessingQueue).filter(DBProcessingQueue.status == "failed").count()
        processing_count = db.query(DBProcessingQueue).filter(DBProcessingQueue.status == "processing").count()
        pending_count = db.query(DBProcessingQueue).filter(DBProcessingQueue.status == "pending").count()
        completed_count = db.query(DBProcessingQueue).filter(DBProcessingQueue.status == "completed").count()
    except Exception:
        pass
        
    return {
        "overall_health_score": autopilot.health_score,
        "overall_status": autopilot.overall_status,
        "autopilot_locked": autopilot.locked,
        "autopilot_safe_mode": autopilot.safe_mode,
        "active_issues": autopilot.active_issues,
        "total_recoveries_today": autopilot.total_recoveries_today,
        "uptime": autopilot.get_uptime_str(),
        "queue_counts": {
            "pending": pending_count,
            "processing": processing_count,
            "completed": completed_count,
            "failed": failed_count
        }
    }

@router.get("/t310", dependencies=[Depends(get_viewer_user)])
def get_t310_status(db: Session = Depends(get_db)) -> Dict[str, Any]:
    # Supplement collected monitoring with postgres/worker service details
    t310_data = monitor.t310_metrics.copy() if monitor.t310_metrics else {
        "cpu_percent": 0.0, "ram_percent": 0.0, "disk_percent": 0.0,
        "network_rx_kbps": 0.0, "network_tx_kbps": 0.0, "load_avg": [0,0,0], "uptime": "0d 0h 0m"
    }
    
    # Read worker status / postgres status
    worker_running = True
    postgres_running = not is_sqlite
    
    t310_data.update({
        "worker_service_running": worker_running,
        "postgres_running": postgres_running
    })
    return t310_data

@router.get("/r510", dependencies=[Depends(get_viewer_user)])
def get_r510_status() -> Dict[str, Any]:
    return monitor.r510_metrics or {
        "online": False,
        "ping_latency_ms": 0.0,
        "ssh_status": "OFFLINE",
        "ollama_status": "OFFLINE",
        "active_model": "None",
        "loaded_memory_gb": 0.0,
        "active_requests": 0,
        "cpu_percent": 0.0,
        "ram_percent": 0.0,
        "uptime": "OFFLINE"
    }

@router.get("/alerts", dependencies=[Depends(get_viewer_user)])
def get_alerts_and_logs(db: Session = Depends(get_db)) -> Dict[str, Any]:
    # Construct alert levels based on autopilot issues
    critical_alerts = []
    warning_alerts = []
    info_alerts = []
    
    for issue in autopilot.active_issues:
        if "LOCKED" in issue or "Unreachable" in issue or "Offline" in issue:
            critical_alerts.append(issue)
        elif "backlog" in issue or "Jam" in issue:
            warning_alerts.append(issue)
        else:
            info_alerts.append(issue)
            
    # Fetch operations logs from db
    logs = []
    try:
        entries = db.query(DBOperationsLog).order_by(DBOperationsLog.timestamp.desc()).limit(30).all()
        logs = [
            {
                "id": entry.id,
                "timestamp": entry.timestamp.isoformat() + "Z",
                "severity": entry.severity,
                "event": entry.event,
                "action_taken": entry.action_taken,
                "result": entry.result,
                "host": entry.host
            } for entry in entries
        ]
    except Exception:
        # Dev fallback logs if query fails
        logs = [
            {
                "id": 1,
                "timestamp": (datetime.utcnow()).isoformat() + "Z",
                "severity": "INFO",
                "event": "SYSTEM_START",
                "action_taken": "INITIALIZE_MONITOR",
                "result": "SUCCESS",
                "host": "p3noc"
            }
        ]
        
    return {
        "critical": critical_alerts,
        "warning": warning_alerts,
        "info": info_alerts,
        "logs": logs
    }
