# ChatKit Backend - Examples

## Example 1: Basic SSE Streaming

### Simple Stream Handler
```python
from fastapi import FastAPI
from fastapi.responses import StreamingResponse
import asyncio

app = FastAPI()

async def simple_stream():
    """Simple SSE stream example"""
    for i in range(10):
        yield f"data: Message {i}\n\n"
        await asyncio.sleep(0.5)
    yield "data: [DONE]\n\n"

@app.get("/stream")
async def stream():
    return StreamingResponse(
        simple_stream(),
        media_type="text/event-stream"
    )
```

### Testing with curl
```bash
curl -N http://localhost:8000/stream
```

## Example 2: SSE with Agent Integration

### Streaming Agent Response
```python
from agent import create_agent_response

async def stream_agent(message: str):
    """Stream agent response via SSE"""
    messages = [{"role": "user", "content": message}]

    response = await create_agent_response(
        messages=messages,
        stream=True
    )

    for chunk in response:
        if chunk.choices[0].delta.content:
            content = chunk.choices[0].delta.content
            # Escape newlines for SSE format
            content = content.replace('\n', '\\n')
            yield f"data: {content}\n\n"

    yield "data: [DONE]\n\n"

@router.post("/chat/stream")
async def chat_stream(message: str):
    return StreamingResponse(
        stream_agent(message),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "Connection": "keep-alive"
        }
    )
```

## Example 3: Conversation with History

### Loading and Using History
```python
from sqlmodel import Session, select
from models import Conversation, Message

async def stream_with_history(
    message: str,
    conversation_id: str,
    session: Session
):
    """Stream response with conversation history"""

    # Load history
    statement = select(Message).where(
        Message.conversation_id == conversation_id
    ).order_by(Message.created_at)

    history = session.exec(statement).all()

    # Build context
    messages = []
    for msg in history[-10:]:  # Last 10 messages for context
        messages.append({
            "role": msg.role,
            "content": msg.content
        })

    # Add new message
    messages.append({"role": "user", "content": message})

    # Stream response
    response = await create_agent_response(messages, stream=True)

    assistant_content = ""
    for chunk in response:
        if chunk.choices[0].delta.content:
            content = chunk.choices[0].delta.content
            assistant_content += content
            yield f"data: {content}\n\n"

    yield "data: [DONE]\n\n"

    # Save messages
    user_msg = Message(
        conversation_id=conversation_id,
        role="user",
        content=message
    )
    assistant_msg = Message(
        conversation_id=conversation_id,
        role="assistant",
        content=assistant_content
    )

    session.add(user_msg)
    session.add(assistant_msg)
    session.commit()
```

## Example 4: Error Handling in SSE

### Robust Stream Handler
```python
import logging
from datetime import datetime

logger = logging.getLogger(__name__)

async def safe_stream_agent(
    message: str,
    conversation_id: str,
    user_id: str,
    session: Session
):
    """Stream with comprehensive error handling"""
    try:
        # Validate conversation
        conversation = session.get(Conversation, conversation_id)
        if not conversation or conversation.user_id != user_id:
            yield "data: Error: Unauthorized\n\n"
            yield "data: [DONE]\n\n"
            return

        # Save user message
        user_msg = Message(
            conversation_id=conversation_id,
            role="user",
            content=message
        )
        session.add(user_msg)
        session.commit()

        # Stream response
        messages = [{"role": "user", "content": message}]
        assistant_content = ""

        response = await create_agent_response(messages, stream=True)

        for chunk in response:
            if chunk.choices[0].delta.content:
                content = chunk.choices[0].delta.content
                assistant_content += content
                yield f"data: {content}\n\n"

        # Save assistant message
        if assistant_content:
            assistant_msg = Message(
                conversation_id=conversation_id,
                role="assistant",
                content=assistant_content
            )
            session.add(assistant_msg)
            session.commit()

        yield "data: [DONE]\n\n"

    except Exception as e:
        logger.error(f"Stream error: {e}", exc_info=True)
        yield f"data: I apologize, but I encountered an error. Please try again.\n\n"
        yield "data: [DONE]\n\n"
```

## Example 5: Conversation Management

### Complete CRUD Operations
```python
from typing import Optional
from pydantic import BaseModel

class ConversationCreate(BaseModel):
    title: Optional[str] = "New Conversation"

class ConversationUpdate(BaseModel):
    title: str

@router.post("/conversations", response_model=ConversationResponse)
async def create_conversation(
    data: ConversationCreate,
    user_id: str = Depends(get_current_user),
    session: Session = Depends(get_session)
):
    """Create new conversation"""
    conversation = Conversation(
        user_id=user_id,
        title=data.title
    )
    session.add(conversation)
    session.commit()
    session.refresh(conversation)

    return conversation

@router.get("/conversations", response_model=list[ConversationResponse])
async def list_conversations(
    limit: int = 50,
    offset: int = 0,
    user_id: str = Depends(get_current_user),
    session: Session = Depends(get_session)
):
    """List user conversations with pagination"""
    statement = select(Conversation).where(
        Conversation.user_id == user_id
    ).order_by(
        Conversation.updated_at.desc()
    ).limit(limit).offset(offset)

    conversations = session.exec(statement).all()
    return conversations

@router.patch("/conversations/{conversation_id}")
async def update_conversation(
    conversation_id: str,
    data: ConversationUpdate,
    user_id: str = Depends(get_current_user),
    session: Session = Depends(get_session)
):
    """Update conversation title"""
    conversation = session.get(Conversation, conversation_id)

    if not conversation or conversation.user_id != user_id:
        raise HTTPException(404, "Conversation not found")

    conversation.title = data.title
    conversation.updated_at = datetime.utcnow()

    session.add(conversation)
    session.commit()
    session.refresh(conversation)

    return conversation

@router.get("/conversations/{conversation_id}")
async def get_conversation(
    conversation_id: str,
    user_id: str = Depends(get_current_user),
    session: Session = Depends(get_session)
):
    """Get conversation details with message count"""
    conversation = session.get(Conversation, conversation_id)

    if not conversation or conversation.user_id != user_id:
        raise HTTPException(404, "Conversation not found")

    # Count messages
    message_count = session.exec(
        select(func.count(Message.id)).where(
            Message.conversation_id == conversation_id
        )
    ).one()

    return {
        **conversation.dict(),
        "message_count": message_count
    }
```

## Example 6: Testing SSE Endpoints

### Python Test Client
```python
import pytest
from httpx import AsyncClient
from main import app

@pytest.mark.asyncio
async def test_sse_stream():
    """Test SSE streaming endpoint"""
    async with AsyncClient(app=app, base_url="http://test") as client:
        async with client.stream(
            "POST",
            "/api/chat/stream?message=Hello",
            headers={"Authorization": "Bearer test-token"}
        ) as response:
            assert response.status_code == 200
            assert response.headers["content-type"] == "text/event-stream"

            chunks = []
            async for line in response.aiter_lines():
                if line.startswith("data: "):
                    data = line[6:]  # Remove "data: " prefix
                    chunks.append(data)
                    if data == "[DONE]":
                        break

            assert len(chunks) > 0
            assert chunks[-1] == "[DONE]"

@pytest.mark.asyncio
async def test_conversation_crud():
    """Test conversation CRUD operations"""
    async with AsyncClient(app=app, base_url="http://test") as client:
        # Create conversation
        response = await client.post(
            "/api/conversations",
            json={"title": "Test Chat"},
            headers={"Authorization": "Bearer test-token"}
        )
        assert response.status_code == 200
        conv_id = response.json()["id"]

        # List conversations
        response = await client.get(
            "/api/conversations",
            headers={"Authorization": "Bearer test-token"}
        )
        assert response.status_code == 200
        assert len(response.json()["conversations"]) > 0

        # Delete conversation
        response = await client.delete(
            f"/api/conversations/{conv_id}",
            headers={"Authorization": "Bearer test-token"}
        )
        assert response.status_code == 200
```

## Example 7: Message Pagination

### Paginated Message Retrieval
```python
@router.get("/conversations/{conversation_id}/messages")
async def get_messages(
    conversation_id: str,
    limit: int = 50,
    before: Optional[str] = None,  # Message ID
    user_id: str = Depends(get_current_user),
    session: Session = Depends(get_session)
):
    """
    Get messages with pagination.

    Args:
        conversation_id: Conversation ID
        limit: Maximum messages to return
        before: Get messages before this message ID
        user_id: Authenticated user ID

    Returns:
        Paginated list of messages
    """
    # Verify ownership
    conversation = session.get(Conversation, conversation_id)
    if not conversation or conversation.user_id != user_id:
        raise HTTPException(404, "Conversation not found")

    # Build query
    statement = select(Message).where(
        Message.conversation_id == conversation_id
    )

    # Add cursor pagination
    if before:
        before_msg = session.get(Message, before)
        if before_msg:
            statement = statement.where(
                Message.created_at < before_msg.created_at
            )

    statement = statement.order_by(
        Message.created_at.desc()
    ).limit(limit)

    messages = session.exec(statement).all()

    # Reverse to chronological order
    messages = list(reversed(messages))

    return {
        "messages": [
            {
                "id": msg.id,
                "role": msg.role,
                "content": msg.content,
                "created_at": msg.created_at.isoformat()
            }
            for msg in messages
        ],
        "has_more": len(messages) == limit
    }
```

## Example 8: Real-time Updates with WebSocket (Alternative to SSE)

### WebSocket Chat Endpoint
```python
from fastapi import WebSocket, WebSocketDisconnect

@router.websocket("/chat/ws")
async def websocket_chat(
    websocket: WebSocket,
    user_id: str = Depends(get_current_user)
):
    """WebSocket endpoint for bidirectional chat"""
    await websocket.accept()

    try:
        while True:
            # Receive message from client
            data = await websocket.receive_json()
            message = data.get("message")
            conversation_id = data.get("conversation_id")

            # Stream response
            messages = [{"role": "user", "content": message}]
            response = await create_agent_response(messages, stream=True)

            # Send chunks via WebSocket
            for chunk in response:
                if chunk.choices[0].delta.content:
                    await websocket.send_json({
                        "type": "chunk",
                        "content": chunk.choices[0].delta.content
                    })

            # Send completion signal
            await websocket.send_json({"type": "done"})

    except WebSocketDisconnect:
        print(f"Client {user_id} disconnected")
```

## Example 9: Conversation Search

### Search in Conversation History
```python
@router.get("/conversations/search")
async def search_conversations(
    query: str,
    user_id: str = Depends(get_current_user),
    session: Session = Depends(get_session)
):
    """Search conversations by content"""
    # Search in messages
    statement = select(Message).join(Conversation).where(
        Conversation.user_id == user_id,
        Message.content.ilike(f"%{query}%")
    ).limit(50)

    messages = session.exec(statement).all()

    # Group by conversation
    results = {}
    for msg in messages:
        conv_id = msg.conversation_id
        if conv_id not in results:
            results[conv_id] = {
                "conversation_id": conv_id,
                "matches": []
            }
        results[conv_id]["matches"].append({
            "message_id": msg.id,
            "role": msg.role,
            "content": msg.content,
            "created_at": msg.created_at.isoformat()
        })

    return {"results": list(results.values())}
```
