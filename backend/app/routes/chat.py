import json
import logging
import httpx
from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.responses import StreamingResponse
from sqlalchemy.orm import Session
from pydantic import BaseModel
from typing import List, Dict, Any, Optional
from backend.app.database import SessionLocal, get_db, Conversation, ChatMessage, User
from backend.app.config import settings
from backend.app.auth import get_current_user

logger = logging.getLogger("backend.chat")

router = APIRouter(prefix="/chat", tags=["chat"])

# --- Pydantic Schemas ---

class ConversationCreate(BaseModel):
    title: str

class ConversationResponse(BaseModel):
    id: int
    title: str
    created_at: str
    user_id: int

    class Config:
        from_attributes = True

class MessageCreate(BaseModel):
    content: str
    model: Optional[str] = None

class MessageResponse(BaseModel):
    id: int
    role: str
    content: str
    created_at: str

    class Config:
        from_attributes = True

# --- API Endpoints ---

@router.get("/conversations", response_model=List[Dict[str, Any]])
def get_conversations(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    conversations = db.query(Conversation).filter(Conversation.user_id == current_user.id).order_by(Conversation.created_at.desc()).all()
    return [
        {
            "id": conv.id,
            "title": conv.title,
            "created_at": conv.created_at.isoformat() + "Z",
            "user_id": conv.user_id
        } for conv in conversations
    ]

@router.post("/conversations", response_model=Dict[str, Any])
def create_conversation(conv_in: ConversationCreate, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    conv = Conversation(title=conv_in.title, user_id=current_user.id)
    db.add(conv)
    db.commit()
    db.refresh(conv)
    return {
        "id": conv.id,
        "title": conv.title,
        "created_at": conv.created_at.isoformat() + "Z",
        "user_id": conv.user_id
    }

@router.delete("/conversations/{conversation_id}")
def delete_conversation(conversation_id: int, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    conv = db.query(Conversation).filter(Conversation.id == conversation_id, Conversation.user_id == current_user.id).first()
    if not conv:
        raise HTTPException(status_code=404, detail="Conversation not found")
    
    db.delete(conv)
    db.commit()
    return {"status": "success", "message": "Conversation deleted."}

@router.get("/conversations/{conversation_id}/messages", response_model=List[Dict[str, Any]])
def get_messages(conversation_id: int, current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    conv = db.query(Conversation).filter(Conversation.id == conversation_id, Conversation.user_id == current_user.id).first()
    if not conv:
        raise HTTPException(status_code=404, detail="Conversation not found")
        
    messages = db.query(ChatMessage).filter(ChatMessage.conversation_id == conversation_id).order_by(ChatMessage.created_at.asc()).all()
    return [
        {
            "id": msg.id,
            "role": msg.role,
            "content": msg.content,
            "created_at": msg.created_at.isoformat() + "Z"
        } for msg in messages
    ]

# Streaming generator proxying to R510 Ollama
async def stream_ollama_chat(chat_history: List[Dict[str, str]], model_name: str, conversation_id: int, db_session: Session):
    accumulated_content = []
    
    # 1. Prepare HTTPX Async Client
    # Set model. Use settings fallback if model is empty.
    selected_model = model_name if model_name else settings.OLLAMA_MODEL
    
    payload = {
        "model": selected_model,
        "messages": chat_history,
        "stream": True
    }
    
    logger.info(f"Streaming from Ollama: model={selected_model}, endpoint={settings.OLLAMA_URL}/api/chat")
    
    try:
        async with httpx.AsyncClient(timeout=60.0) as client:
            async with client.stream("POST", f"{settings.OLLAMA_URL}/api/chat", json=payload) as response:
                if response.status_code != 200:
                    error_text = await response.aread()
                    logger.error(f"Ollama server returned error status {response.status_code}: {error_text}")
                    yield f"data: {json.dumps({'error': 'Ollama connection failed'})}\n\n"
                    return

                async for line in response.aiter_lines():
                    if not line:
                        continue
                    try:
                        chunk = json.loads(line)
                        content = chunk.get("message", {}).get("content", "")
                        if content:
                            accumulated_content.append(content)
                            
                        # Forward chunk exactly as data stream
                        yield f"data: {line}\n\n"
                        
                        if chunk.get("done", False):
                            break
                    except Exception as e:
                        logger.error(f"Error parsing line chunk: {e}")
                        
    except Exception as ex:
        logger.error(f"Error proxying streaming connection to Ollama: {ex}")
        # Fallback simulation if R510 Ollama is offline/unreachable
        mock_response = (
            f"Greetings! I am your P3 Infrastructure AI Assistant. "
            f"I see that the Ollama instance at {settings.OLLAMA_HOST} is currently offline. "
            f"This is a simulated assistant response. How can I help you debug the NOC server?"
        )
        for char_chunk in [mock_response[i:i+8] for i in range(0, len(mock_response), 8)]:
            # Yield as mock chunks
            sim_chunk = {
                "model": selected_model,
                "message": {"role": "assistant", "content": char_chunk},
                "done": False
            }
            yield f"data: {json.dumps(sim_chunk)}\n\n"
            await asyncio_sleep(0.05) # Simulated latency
            accumulated_content.append(char_chunk)
            
        yield f"data: {json.dumps({'model': selected_model, 'done': True})}\n\n"

    # Save Assistant Response to Database
    try:
        final_text = "".join(accumulated_content)
        if final_text:
            # We must open a fresh database transaction block to avoid thread issues
            db = SessionLocal()
            try:
                assistant_message = ChatMessage(
                    conversation_id=conversation_id,
                    role="assistant",
                    content=final_text
                )
                db.add(assistant_message)
                
                # Also log request in analysis_versions mapping
                from backend.app.database import DBAnalysisVersion
                db.add(DBAnalysisVersion(
                    model_name=selected_model,
                    response_time_ms=500.0  # approximate
                ))
                
                db.commit()
            except Exception as dbe:
                logger.error(f"Failed to persist assistant chat response to DB: {dbe}")
                db.rollback()
            finally:
                db.close()
    except Exception as ex2:
        logger.error(f"Unexpected DB persistence error: {ex2}")

# Helper for simulated sleep
import asyncio
async def asyncio_sleep(sec: float):
    await asyncio.sleep(sec)

@router.post("/conversations/{conversation_id}/messages")
def post_message_to_conversation(
    conversation_id: int,
    msg_in: MessageCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    # Verify ownership of conversation
    conv = db.query(Conversation).filter(Conversation.id == conversation_id, Conversation.user_id == current_user.id).first()
    if not conv:
        raise HTTPException(status_code=404, detail="Conversation not found")
        
    # 1. Save user message to database
    user_msg = ChatMessage(
        conversation_id=conversation_id,
        role="user",
        content=msg_in.content
    )
    db.add(user_msg)
    db.commit()
    
    # 2. Query all messages to construct thread context
    thread = db.query(ChatMessage).filter(ChatMessage.conversation_id == conversation_id).order_by(ChatMessage.created_at.asc()).all()
    history = [{"role": msg.role, "content": msg.content} for msg in thread]
    
    # 3. Return streaming proxy response
    model_name = msg_in.model or settings.OLLAMA_MODEL
    return StreamingResponse(
        stream_ollama_chat(history, model_name, conversation_id, db),
        media_type="text/event-stream"
    )
