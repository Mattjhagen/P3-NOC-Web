import os
from pydantic_settings import BaseSettings
from dotenv import load_dotenv

load_dotenv()

class Settings(BaseSettings):
    PROJECT_NAME: str = "P3 Operations Center"
    API_V1_STR: str = "/api"
    
    # Security / Auth
    SECRET_KEY: str = os.getenv("SECRET_KEY", "p3-operations-center-super-secure-secret-key-change-me")
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24 * 7  # 7 Days default
    
    # DB URL: default pointing to postgres, falls back to sqlite locally if postgres is unreachable
    DATABASE_URL: str = os.getenv(
        "DATABASE_URL", 
        "postgresql://researcher:secure_password_change_me@localhost:5432/bitcoin_research"
    )
    
    # Ollama endpoint on R510
    OLLAMA_HOST: str = os.getenv("OLLAMA_HOST", "192.168.1.47")
    OLLAMA_PORT: str = os.getenv("OLLAMA_PORT", "11434")
    OLLAMA_URL: str = f"http://{OLLAMA_HOST}:{OLLAMA_PORT}"
    OLLAMA_MODEL: str = os.getenv("OLLAMA_MODEL", "qwen3:8b")
    
    # Servers under monitor
    T310_IP: str = "127.0.0.1"  # Local host
    R510_IP: str = os.getenv("AI_SERVER_IP", "192.168.1.47")
    R510_SSH_PORT: int = 22
    
    # Systemd services to monitor
    SERVICE_WORKER: str = os.getenv("SERVICE_WORKER", "bitcoin-worker")
    SERVICE_INGEST: str = os.getenv("SERVICE_INGEST", "bitcoin-ingest")
    
    # Polling schedules (seconds)
    POLL_INTERVAL_METRICS: int = 5     # Local system metrics
    POLL_INTERVAL_R510: int = 10       # R510 Ping, SSH, Ollama /api/ps
    POLL_INTERVAL_AUTOPILOT: int = 60  # Autopilot healing evaluation
    
    class Config:
        case_sensitive = True

settings = Settings()
