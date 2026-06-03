import os
import logging
from sqlalchemy import create_engine, Column, Integer, String, Float, DateTime, Text, Boolean, ForeignKey, event, text
from sqlalchemy.orm import declarative_base, sessionmaker, relationship
from sqlalchemy.engine import Engine
from datetime import datetime
from backend.app.config import settings

logger = logging.getLogger("backend.database")

Base = declarative_base()

# SQLite foreign key support trigger
@event.listens_for(Engine, "connect")
def set_sqlite_pragma(dbapi_connection, connection_record):
    if settings.DATABASE_URL.startswith("sqlite") or "sqlite" in str(connection_record):
        cursor = dbapi_connection.cursor()
        cursor.execute("PRAGMA foreign_keys=ON")
        cursor.close()

# ----------------- DB Models -----------------

class User(Base):
    __tablename__ = "users"
    id = Column(Integer, primary_key=True, index=True)
    username = Column(String(50), unique=True, index=True, nullable=False)
    password_hash = Column(String(255), nullable=False)
    role = Column(String(20), default="viewer", nullable=False)  # admin, operator, viewer
    
    conversations = relationship("Conversation", back_populates="user", cascade="all, delete-orphan")

class Conversation(Base):
    __tablename__ = "conversations"
    id = Column(Integer, primary_key=True, index=True)
    title = Column(String(255), nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    
    user = relationship("User", back_populates="conversations")
    messages = relationship("ChatMessage", back_populates="conversation", cascade="all, delete-orphan")

class ChatMessage(Base):
    __tablename__ = "chat_messages"
    id = Column(Integer, primary_key=True, index=True)
    conversation_id = Column(Integer, ForeignKey("conversations.id", ondelete="CASCADE"), nullable=False)
    role = Column(String(10), nullable=False)  # 'user', 'assistant'
    content = Column(Text, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    
    conversation = relationship("Conversation", back_populates="messages")

# Mirrors / mapping of pre-existing dashboard tables
class DBOperationsLog(Base):
    __tablename__ = "operations_log"
    id = Column(Integer, primary_key=True, index=True)
    timestamp = Column(DateTime, default=datetime.utcnow)
    severity = Column(String(50), nullable=False)
    event = Column(Text, nullable=False)
    action_taken = Column(Text)
    result = Column(Text)
    host = Column(String(100), default="p3noc")

class DBProcessingQueue(Base):
    __tablename__ = "processing_queue"
    id = Column(Integer, primary_key=True, index=True)
    article_id = Column(Integer)
    status = Column(String(50), nullable=False)  # pending, processing, completed, failed, dead_letter
    retry_count = Column(Integer, default=0)
    last_error = Column(Text)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow)

class DBArticle(Base):
    __tablename__ = "articles"
    id = Column(Integer, primary_key=True, index=True)
    title = Column(Text, nullable=False)
    url = Column(Text)
    created_at = Column(DateTime, default=datetime.utcnow)

class DBAnalysis(Base):
    __tablename__ = "analyses"
    id = Column(Integer, primary_key=True, index=True)
    article_id = Column(Integer, ForeignKey("articles.id"))
    sentiment_score = Column(Float)
    importance_score = Column(Float)
    sentiment = Column(String(50))
    confidence = Column(Float)
    summary = Column(Text)
    created_at = Column(DateTime, default=datetime.utcnow)

class DBAnalysisVersion(Base):
    __tablename__ = "analysis_versions"
    id = Column(Integer, primary_key=True, index=True)
    analysis_id = Column(Integer)
    model_name = Column(String(100))
    response_time_ms = Column(Float)
    created_at = Column(DateTime, default=datetime.utcnow)

class DBSystemMetric(Base):
    __tablename__ = "system_metrics"
    id = Column(Integer, primary_key=True, index=True)
    metric_name = Column(String(100), nullable=False)
    metric_value = Column(Float, nullable=False)
    recorded_at = Column(DateTime, default=datetime.utcnow)

class DBFeedSource(Base):
    __tablename__ = "feed_sources"
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(255), nullable=False)
    enabled = Column(Boolean, default=True)
    last_successful_poll = Column(DateTime)

# ----------------- DB Initialization -----------------

engine = None
SessionLocal = sessionmaker(autocommit=False, autoflush=False)
is_sqlite = False

def init_db():
    global engine, is_sqlite
    
    # Try PostgreSQL first
    try:
        pg_url = settings.DATABASE_URL
        logger.info(f"Attempting connection to PostgreSQL database at {pg_url}...")
        engine = create_engine(pg_url, connect_args={"connect_timeout": 3})
        # Test connection
        with engine.connect() as conn:
            conn.execute(text("SELECT 1"))
            pass
        SessionLocal.configure(bind=engine)
        logger.info("Successfully connected to PostgreSQL database.")
        is_sqlite = False
    except Exception as e:
        logger.warning(f"PostgreSQL connection failed ({e}). Falling back to local SQLite database...")
        sqlite_url = "sqlite:///./dev_db.sqlite"
        engine = create_engine(sqlite_url, connect_args={"check_same_thread": False})
        SessionLocal.configure(bind=engine)
        is_sqlite = True
        logger.info(f"SQLite fallback initialized at {sqlite_url}.")

    # Create tables if they don't exist
    try:
        Base.metadata.create_all(bind=engine)
        logger.info("Database tables verified/created successfully.")
    except Exception as ex:
        logger.critical(f"Failed to create database tables: {ex}")

# Get Session dependency
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
