import asyncio
import logging
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from backend.app.config import settings
from backend.app.database import init_db
from backend.app.monitoring import monitor
from backend.app.autopilot import autopilot
from backend.app.routes import auth, system, recovery, metrics, chat

# Setup logs
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    handlers=[logging.StreamHandler()]
)
logger = logging.getLogger("backend")

app = FastAPI(
    title=settings.PROJECT_NAME,
    version="1.0.0",
    docs_url="/docs"
)

# CORS configuration
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # configure restrictively in production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Connect Routers
app.include_router(auth.router, prefix=settings.API_V1_STR)
app.include_router(system.router, prefix=settings.API_V1_STR)
app.include_router(recovery.router, prefix=settings.API_V1_STR)
app.include_router(metrics.router, prefix=settings.API_V1_STR)
app.include_router(chat.router, prefix=settings.API_V1_STR)

from fastapi.responses import FileResponse
from pathlib import Path

@app.get("/")
def read_index():
    static_file = Path(__file__).resolve().parent / "static" / "index.html"
    return FileResponse(static_file)

# --- WebSocket Broadcast System ---

class WebSocketManager:
    def __init__(self):
        self.active_connections: set[WebSocket] = set()

    async def connect(self, websocket: WebSocket):
        await websocket.accept()
        self.active_connections.add(websocket)
        logger.info(f"New WebSocket client connected. Total connections: {len(self.active_connections)}")

    def disconnect(self, websocket: WebSocket):
        self.active_connections.remove(websocket)
        logger.info(f"WebSocket client disconnected. Total connections: {len(self.active_connections)}")

    async def broadcast_status(self):
        if not self.active_connections:
            return
            
        # Compile status dictionary
        # Retrieve queue counts and logs for live updates
        from backend.app.database import SessionLocal, DBProcessingQueue
        failed = 0
        processing = 0
        pending = 0
        completed = 0
        
        db = SessionLocal()
        try:
            failed = db.query(DBProcessingQueue).filter(DBProcessingQueue.status == "failed").count()
            processing = db.query(DBProcessingQueue).filter(DBProcessingQueue.status == "processing").count()
            pending = db.query(DBProcessingQueue).filter(DBProcessingQueue.status == "pending").count()
            completed = db.query(DBProcessingQueue).filter(DBProcessingQueue.status == "completed").count()
        except Exception:
            pass
        finally:
            db.close()
            
        payload = {
            "overall_health_score": autopilot.health_score,
            "overall_status": autopilot.overall_status,
            "autopilot_locked": autopilot.locked,
            "autopilot_safe_mode": autopilot.safe_mode,
            "active_issues": autopilot.active_issues,
            "total_recoveries_today": autopilot.total_recoveries_today,
            "uptime": autopilot.get_uptime_str(),
            "t310": monitor.t310_metrics,
            "r510": monitor.r510_metrics,
            "queue_counts": {
                "pending": pending,
                "processing": processing,
                "completed": completed,
                "failed": failed
            }
        }
        
        disconnected = []
        for ws in self.active_connections:
            try:
                await ws.send_json(payload)
            except Exception:
                disconnected.append(ws)
                
        for ws in disconnected:
            self.disconnect(ws)

ws_manager = WebSocketManager()

@app.websocket("/ws/status")
async def websocket_status_endpoint(websocket: WebSocket):
    await ws_manager.connect(websocket)
    try:
        while True:
            # Keep connection open and check for client close
            data = await websocket.receive_text()
            # Handle user ping or input if sent
            await websocket.send_json({"pong": True})
    except WebSocketDisconnect:
        ws_manager.disconnect(websocket)
    except Exception as e:
        logger.error(f"WebSocket connection error: {e}")
        ws_manager.disconnect(websocket)

# --- Background Loops ---

async def monitoring_worker():
    """Polls server telemetry metrics regularly in the background."""
    while True:
        try:
            monitor.update_metrics()
        except Exception as e:
            logger.error(f"Error in telemetry polling thread: {e}")
        await asyncio.sleep(settings.POLL_INTERVAL_METRICS)

async def autopilot_worker():
    """Runs the self-healing and scoring logic once a minute."""
    while True:
        try:
            telemetry = {
                "r510": monitor.r510_metrics
            }
            autopilot.execute_evaluation_cycle(telemetry)
        except Exception as e:
            logger.error(f"Error in autopilot evaluation cycle: {e}")
        await asyncio.sleep(settings.POLL_INTERVAL_AUTOPILOT)

async def ws_broadcast_worker():
    """Pushes JSON telemetry updates to connected websockets every 3 seconds."""
    while True:
        try:
            await ws_manager.broadcast_status()
        except Exception as e:
            logger.error(f"Error broadcasting WebSocket statuses: {e}")
        await asyncio.sleep(3.0)

# --- App Lifecycle Events ---

@app.on_event("startup")
async def startup_event():
    # 1. Initialize DB and Fallbacks
    init_db()
    
    # 2. Run initial metrics polling
    monitor.update_metrics()
    
    # 3. Register background tasks
    asyncio.create_task(monitoring_worker())
    asyncio.create_task(autopilot_worker())
    asyncio.create_task(ws_broadcast_worker())
    logger.info("P3 Operations Center backend services fully started.")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("backend.app.main:app", host="0.0.0.0", port=8000, reload=True)
