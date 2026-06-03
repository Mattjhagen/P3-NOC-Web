from fastapi import APIRouter, Depends, HTTPException, status
from backend.app.autopilot import autopilot
from backend.app.auth import get_operator_user
from typing import Dict, Any

router = APIRouter(prefix="/recovery", tags=["recovery"])

@router.post("/unlock", dependencies=[Depends(get_operator_user)])
def unlock_autopilot() -> Dict[str, Any]:
    autopilot.unlock()
    return {"status": "success", "message": "Autopilot safety lock cleared manually."}

@router.post("/restart-worker", dependencies=[Depends(get_operator_user)])
def trigger_restart_worker() -> Dict[str, Any]:
    autopilot.log_event("WARNING", "MANUAL_RESTART_REQUESTED", "RESTART_WORKER", "PENDING")
    ok = autopilot.restart_worker()
    result = "SUCCESS" if ok else "FAILED"
    autopilot.log_event("INFO", "MANUAL_RESTART_COMPLETED", "RESTART_WORKER", result)
    if not ok:
        raise HTTPException(status_code=500, detail="Worker service restart failed.")
    return {"status": "success", "message": "Worker service restarted successfully."}

@router.post("/restart-ingest", dependencies=[Depends(get_operator_user)])
def trigger_restart_ingest() -> Dict[str, Any]:
    autopilot.log_event("WARNING", "MANUAL_RESTART_REQUESTED", "RESTART_INGEST", "PENDING")
    ok = autopilot.restart_ingest()
    result = "SUCCESS" if ok else "FAILED"
    autopilot.log_event("INFO", "MANUAL_RESTART_COMPLETED", "RESTART_INGEST", result)
    if not ok:
        raise HTTPException(status_code=500, detail="RSS Ingest Timer restart failed.")
    return {"status": "success", "message": "RSS Ingest Timer restarted successfully."}

@router.post("/requeue-failed", dependencies=[Depends(get_operator_user)])
def trigger_requeue_failed() -> Dict[str, Any]:
    autopilot.log_event("WARNING", "MANUAL_REQUEUE_REQUESTED", "REQUEUE_FAILED_JOBS", "PENDING")
    ok = autopilot.requeue_failed_jobs()
    result = "SUCCESS" if ok else "FAILED"
    autopilot.log_event("INFO", "MANUAL_REQUEUE_COMPLETED", "REQUEUE_FAILED_JOBS", result)
    if not ok:
        raise HTTPException(status_code=500, detail="Database requeue transaction failed.")
    return {"status": "success", "message": "Failed and dead letter items requeued successfully."}

@router.post("/clear-stuck", dependencies=[Depends(get_operator_user)])
def trigger_clear_stuck() -> Dict[str, Any]:
    autopilot.log_event("WARNING", "MANUAL_CLEANUP_REQUESTED", "CLEAR_STUCK_PROCESSING", "PENDING")
    ok = autopilot.clear_stuck_processing()
    result = "SUCCESS" if ok else "FAILED"
    autopilot.log_event("INFO", "MANUAL_CLEANUP_COMPLETED", "CLEAR_STUCK_PROCESSING", result)
    if not ok:
        raise HTTPException(status_code=500, detail="Database cleanup transaction failed.")
    return {"status": "success", "message": "Stuck processing queue items cleared successfully."}

@router.post("/restart-ollama", dependencies=[Depends(get_operator_user)])
def trigger_restart_ollama() -> Dict[str, Any]:
    autopilot.log_event("WARNING", "MANUAL_RESTART_REQUESTED", "RESTART_OLLAMA", "PENDING")
    ok = autopilot.restart_ollama()
    result = "SUCCESS" if ok else "FAILED"
    autopilot.log_event("INFO", "MANUAL_RESTART_COMPLETED", "RESTART_OLLAMA", result)
    if not ok:
        raise HTTPException(status_code=500, detail="Ollama service restart failed.")
    return {"status": "success", "message": "Ollama service restart triggered successfully."}

@router.post("/warm-model", dependencies=[Depends(get_operator_user)])
def trigger_warm_model() -> Dict[str, Any]:
    autopilot.log_event("INFO", "MANUAL_WARM_REQUESTED", "WARM_MODEL", "PENDING")
    ok = autopilot.warm_model()
    result = "SUCCESS" if ok else "FAILED"
    autopilot.log_event("INFO", "MANUAL_WARM_COMPLETED", "WARM_MODEL", result)
    if not ok:
        raise HTTPException(status_code=500, detail="Ollama model pre-warming request failed.")
    return {"status": "success", "message": "Ollama model warmed successfully."}
