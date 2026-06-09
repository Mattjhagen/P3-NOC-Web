from fastapi import APIRouter, Depends, Query
from app.monitoring import monitor
from app.auth import get_viewer_user
from typing import List, Dict, Any

router = APIRouter(prefix="/metrics", tags=["metrics"])

@router.get("", dependencies=[Depends(get_viewer_user)])
def get_historical_metrics(range: str = Query("1h", regex="^(1h|24h|7d|30d)$")) -> List[Dict[str, Any]]:
    """
    Returns historical telemetry records formatted for frontend area/line graphs.
    """
    if range == "1h":
        return monitor.history_1h
    elif range == "24h":
        return monitor.history_24h
    elif range == "7d":
        return monitor.history_7d
    elif range == "30d":
        return monitor.history_30d
        
    return monitor.history_1h
