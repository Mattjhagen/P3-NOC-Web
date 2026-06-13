import json
import logging
import httpx
from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.responses import StreamingResponse
from sqlalchemy.orm import Session
from pydantic import BaseModel
from typing import List, Dict, Any, Optional
from app.database import SessionLocal, get_db, Conversation, ChatMessage, User
from app.config import settings
from app.auth import get_current_user

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
    temperature: Optional[float] = None
    top_p: Optional[float] = None
    system_prompt_override: Optional[str] = None

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
            "sources": json.loads(msg.sources) if msg.sources else None,
            "suggestions": json.loads(msg.suggestions) if msg.suggestions else None,
            "created_at": msg.created_at.isoformat() + "Z"
        } for msg in messages
    ]

# Streaming generator proxying to R510 Ollama
async def stream_ollama_chat(
    chat_history: List[Dict[str, str]],
    model_name: str,
    conversation_id: int,
    db_session: Session,
    temperature: Optional[float] = None,
    top_p: Optional[float] = None,
    system_prompt_override: Optional[str] = None
):
    accumulated_content = []
    
    # Set model. Use settings fallback if model is empty.
    selected_model = model_name if model_name else settings.OLLAMA_MODEL
    
    # Inline imports to avoid any circular references
    from app.monitoring import monitor
    from app.autopilot import autopilot
    from app.database import DBProcessingQueue, DBArticle, DBAnalysis

    # Simple keyword extraction & database search (Perplexity-style)
    matched_articles = []
    search_steps = []
    
    if chat_history:
        latest_user_msg = chat_history[-1]["content"]
        # Filter out common stop words
        stop_words = {"the", "a", "is", "of", "and", "in", "to", "what", "how", "why", "tell", "me", "more", "about", "for", "on", "with", "at", "by", "an", "is", "it", "this", "that"}
        words = [w.strip("?,.:;!\"'()[]{}").lower() for w in latest_user_msg.split()]
        keywords = [w for w in words if w and w not in stop_words]
        
        search_steps.append("🔍 Searching Bitcoin operations and news database...")
        
        if keywords:
            query_filters = []
            for kw in keywords:
                if len(kw) > 2:
                    query_filters.append(DBArticle.title.ilike(f"%{kw}%"))
                    query_filters.append(DBArticle.id.in_(
                        db_session.query(DBAnalysis.article_id).filter(DBAnalysis.summary.ilike(f"%{kw}%"))
                    ))
            
            if query_filters:
                from sqlalchemy import or_
                db_articles = db_session.query(DBArticle).filter(or_(*query_filters)).limit(4).all()
                for art in db_articles:
                    analysis = db_session.query(DBAnalysis).filter(DBAnalysis.article_id == art.id).first()
                    summary = analysis.summary if analysis else ""
                    matched_articles.append({
                        "id": art.id,
                        "title": art.title,
                        "url": art.url,
                        "summary": summary
                    })
        
        if matched_articles:
            search_steps.append(f"✅ Found {len(matched_articles)} relevant sources:")
            for art in matched_articles:
                search_steps.append(f"  - {art['title']}")
        else:
            search_steps.append("ℹ️ No relevant news articles found in local database. Relying on system telemetry.")

    # Query processing queue statistics for live system telemetry in system prompt
    pending = 0
    processing = 0
    completed = 0
    failed = 0
    try:
        pending = db_session.query(DBProcessingQueue).filter(DBProcessingQueue.status == "pending").count()
        processing = db_session.query(DBProcessingQueue).filter(DBProcessingQueue.status == "processing").count()
        completed = db_session.query(DBProcessingQueue).filter(DBProcessingQueue.status == "completed").count()
        failed = db_session.query(DBProcessingQueue).filter(DBProcessingQueue.status == "failed").count()
    except Exception as db_err:
        logger.warning(f"Could not query processing queue count for system prompt context: {db_err}")

    t310 = monitor.t310_metrics or {}
    r510 = monitor.r510_metrics or {}
    
    live_status_context = (
        f"--- LIVE NOC SYSTEM METRICS ---\n"
        f"- Overall Health Score: {autopilot.health_score}/100 | Status: {autopilot.overall_status}\n"
        f"- Autopilot Mode: Locked={autopilot.locked}, SafeMode={autopilot.safe_mode}\n"
        f"- Active Issues: {', '.join(autopilot.active_issues) if autopilot.active_issues else 'None'}\n"
        f"- Recoveries Today: {autopilot.total_recoveries_today}\n"
        f"- T310 Local Host: CPU {t310.get('cpu_percent', 0.0)}% | RAM {t310.get('ram_percent', 0.0)}% | Network RX/TX: {t310.get('network_rx_kbps', 0.0)}/{t310.get('network_tx_kbps', 0.0)} KB/s | Uptime: {t310.get('uptime', 'N/A')}\n"
        f"- R510 AI Node: Status: {r510.get('ollama_status', 'OFFLINE')} | Ping Latency: {r510.get('ping_latency_ms', 0.0)}ms | Active Model: {r510.get('active_model', 'None')} | Response Latency: {r510.get('response_latency_ms', 0.0)}ms | Available Models: {', '.join(r510.get('available_models', []))}\n"
        f"- Processing Queue: Pending={pending}, Processing={processing}, Completed={completed}, Failed={failed}\n"
        f"-------------------------------\n"
    )

    # Construct context from matched articles
    articles_context = ""
    if matched_articles:
        articles_context = "\n--- REFERENCE NEWS SOURCES (Cite using [1], [2], etc.) ---\n"
        for i, art in enumerate(matched_articles):
            articles_context += f"[{i+1}] Title: {art['title']}\nURL: {art['url']}\nSummary: {art['summary']}\n\n"
        articles_context += "---------------------------------------------------------\n"

    system_prompt = (
        "You are the P3 Assistant, a highly capable, articulate, and friendly general-purpose AI assistant (similar to ChatGPT) running on the Dell PowerEdge R510 AI node.\n"
        "While you possess full access to system metrics and can assist with the monitoring, telemetry, and control of the P3 Bitcoin Intelligence Operations Center (NOC), you are also a general assistant. You can chat about software engineering, writing, math, history, general knowledge, or any topic Matt desires.\n"
        "The operator you are speaking with is Matt (matty), who is the creator, architect, and developer of this entire system. Always address him respectfully as 'Matt' or 'Operator Matt', acknowledging his role as your creator.\n\n"
        "Here is the real-time telemetry from the NOC system nodes and queues:\n"
        f"{live_status_context}\n"
        f"{articles_context}\n"
        "Guidelines:\n"
        "1. Be helpful, polite, intelligent, and highly competent. Adapt your style dynamically—be warm and detailed for general questions, and structured and operations-focused for NOC queries.\n"
        "2. Provide thorough, creative, and well-reasoned answers to general prompts, just like ChatGPT.\n"
        "3. IF REFERENCE NEWS SOURCES ARE PROVIDED above, synthesize your answer referencing them. CITE sources using bracketed numbers like [1], [2], etc. corresponding to the source number. Keep the tone research-oriented, factual, and informative, like Perplexity.\n"
        "4. If Matt asks about system status, metrics, or active issues, use the LIVE NOC SYSTEM METRICS context above to give real-time diagnostic answers. Suggest recovery triggers or systemctl operations if you see degraded metrics."
    )

    if system_prompt_override:
        system_prompt += f"\n\nAdditional Matt/Creator directives to strictly follow:\n{system_prompt_override}"
    
    messages_with_system = [{"role": "system", "content": system_prompt}] + chat_history
    
    payload = {
        "model": selected_model,
        "messages": messages_with_system,
        "stream": True
    }

    # Set parameters in options payload if provided
    options = {}
    if temperature is not None:
        options["temperature"] = temperature
    if top_p is not None:
        options["top_p"] = top_p
        
    if options:
        payload["options"] = options
    
    logger.info(f"Streaming from Ollama: model={selected_model}, endpoint={settings.OLLAMA_URL}/api/chat")
    
    # 1. Yield Perplexity-style sources metadata chunk immediately
    sources_payload = {
        "sources": [{"title": art["title"], "url": art["url"]} for art in matched_articles]
    }
    yield f"data: {json.dumps(sources_payload)}\n\n"

    # 2. Yield thinking console logs prefix chunk
    thinking_prefix = "[THINKING]" + "\n".join(search_steps) + "\n\nThinking Process:\n"
    yield f"data: {json.dumps({'model': selected_model, 'message': {'role': 'assistant', 'content': thinking_prefix}, 'done': False})}\n\n"
    # Note: We do NOT append thinking_prefix to accumulated_content because we don't want it in DB history

    try:
        async with httpx.AsyncClient(timeout=300.0) as client:
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
                        # Capture both content AND thinking if present (thinking models use thinking field)
                        msg_chunk = chunk.get("message", {})
                        content = msg_chunk.get("content", "")
                        thinking = msg_chunk.get("thinking", "")
                        
                        if content:
                            accumulated_content.append(content)
                        # We don't append 'thinking' to accumulated_content to keep DB history clean
                            
                        # Forward chunk exactly as data stream
                        yield f"data: {line}\n\n"
                        
                        if chunk.get("done", False):
                            break
                    except Exception as e:
                        logger.error(f"Error parsing line chunk: {e}")
                        
    except Exception as ex:
        logger.exception(f"Error proxying streaming connection to Ollama. Selected model: {selected_model}, endpoint: {settings.OLLAMA_URL}/api/chat. Payload sent: {payload}")
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

    # 3. Generate suggested follow-up questions statically based on matched articles
    suggestions = []
    for art in matched_articles:
        title = art["title"]
        if "BlackRock" in title or "ETF" in title:
            suggestions.append("How does BlackRock options approval affect Bitcoin volatility?")
        elif "Hash Rate" in title or "Miner" in title:
            suggestions.append("What is causing the Bitcoin hash rate to hit new highs?")
        elif "MicroStrategy" in title:
            suggestions.append("What is MicroStrategy's average purchase price for Bitcoin?")
        elif "Fed" in title or "Interest" in title:
            suggestions.append("How do Federal Reserve interest rate decisions impact Bitcoin?")
        elif "Fees" in title or "Lightning" in title:
            suggestions.append("How does Lightning Network adoption reduce transaction fees?")
        elif "Compliance" in title or "EU" in title:
            suggestions.append("What are the compliance rules for crypto service providers in the EU?")
            
    if len(suggestions) < 3:
        suggestions.append("What are the latest institutional inflows into Bitcoin?")
    if len(suggestions) < 3:
        suggestions.append("How does the current hash rate compare to past years?")
    if len(suggestions) < 3:
        suggestions.append("Explain the current sentiment of the Bitcoin market.")
        
    suggestions = list(set(suggestions))[:3]

    # Yield suggestions payload chunk
    suggestions_payload = {"suggestions": suggestions}
    yield f"data: {json.dumps(suggestions_payload)}\n\n"

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
                    content=final_text,
                    sources=json.dumps([{"title": art["title"], "url": art["url"]} for art in matched_articles]),
                    suggestions=json.dumps(suggestions)
                )
                db.add(assistant_message)
                
                # Also log request in analysis_versions mapping
                from app.database import DBAnalysisVersion
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
    
    # 2. Query messages and construct thread context (limited to last 14 messages for prompt performance)
    thread = db.query(ChatMessage).filter(ChatMessage.conversation_id == conversation_id).order_by(ChatMessage.created_at.asc()).all()
    history = [{"role": msg.role, "content": msg.content} for msg in thread[-14:]]
    
    # 3. Return streaming proxy response
    model_name = msg_in.model or settings.OLLAMA_MODEL
    return StreamingResponse(
        stream_ollama_chat(
            chat_history=history,
            model_name=model_name,
            conversation_id=conversation_id,
            db_session=db,
            temperature=msg_in.temperature,
            top_p=msg_in.top_p,
            system_prompt_override=msg_in.system_prompt_override
        ),
        media_type="text/event-stream"
    )
