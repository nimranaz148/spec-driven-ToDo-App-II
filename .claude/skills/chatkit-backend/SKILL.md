# ChatKit Backend - SSE and Conversation Persistence

## Overview
This skill sets up the backend infrastructure for ChatKit, including Server-Sent Events (SSE) streaming endpoint for real-time AI responses and database models for conversation and message persistence.

## When to Use This Skill
- Use when implementing the backend SSE endpoint for streaming AI responses
- Use when creating database models for conversations and messages
- Use when building conversation persistence logic
- Use when integrating agent streaming with database storage

## Prerequisites
- Python 3.11+ installed
- FastAPI backend running
- SQLModel database models configured
- PostgreSQL database accessible
- OpenAI Agents SDK set up (openai-agents-setup skill)
- FastMCP server running (fastmcp-server-setup skill)

## Setup Steps

### 1. Create Database Models
Add to `backend/models.py`:
```python
from sqlmodel import SQLModel, Field, Relationship
from datetime import datetime
from typing import Optional
import uuid

class Conversation(SQLModel, table=True):
    id: str = Field(default_factory=lambda: str(uuid.uuid4()), primary_key=True)
    user_id: str = Field(foreign_key="user.id", index=True)
    title: str = Field(default="New Conversation")
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)

    # Relationships
    messages: list["Message"] = Relationship(back_populates="conversation")

class Message(SQLModel, table=True):
    id: str = Field(default_factory=lambda: str(uuid.uuid4()), primary_key=True)
    conversation_id: str = Field(foreign_key="conversation.id", index=True)
    role: str = Field(index=True)  # 'user' or 'assistant'
    content: str
    created_at: datetime = Field(default_factory=datetime.utcnow)

    # Relationships
    conversation: Optional[Conversation] = Relationship(back_populates="messages")
```

### 2. Create Database Migration
```bash
cd backend
alembic revision --autogenerate -m "Add conversation and message models"
alembic upgrade head
```

### 3. Create SSE Streaming Endpoint
Create `backend/routes/chat.py`:
```python
from fastapi import APIRouter, Depends, Query
from fastapi.responses import StreamingResponse
from sqlmodel import Session, select
from typing import AsyncIterator
from agent import create_agent_response
from mcp_server import get_agent_tools
from models import Conversation, Message
from db import get_session
from auth import get_current_user
import json

router = APIRouter()

async def stream_agent_response(
    message: str,
    conversation_id: str,
    user_id: str,
    session: Session
) -> AsyncIterator[str]:
    """
    Stream agent response and save to database.

    Args:
        message: User message
        conversation_id: Conversation ID
        user_id: Authenticated user ID
        session: Database session

    Yields:
        SSE formatted chunks
    """
    # Load conversation history
    statement = select(Message).where(
        Message.conversation_id == conversation_id
    ).order_by(Message.created_at)

    history = session.exec(statement).all()

    # Build message list
    messages = [
        {"role": msg.role, "content": msg.content}
        for msg in history
    ]
    messages.append({"role": "user", "content": message})

    # Save user message
    user_msg = Message(
        conversation_id=conversation_id,
        role="user",
        content=message
    )
    session.add(user_msg)
    session.commit()

    # Get MCP tools
    tools = await get_agent_tools(user_id)

    # Stream agent response
    assistant_content = ""

    try:
        response = await create_agent_response(
            messages=messages,
            tools=tools,
            stream=True
        )

        for chunk in response:
            if chunk.choices[0].delta.content:
                content = chunk.choices[0].delta.content
                assistant_content += content
                yield f"data: {content}\n\n"

            # Handle tool calls
            if chunk.choices[0].delta.tool_calls:
                # Execute tool and continue streaming
                # (Implementation depends on OpenAI SDK version)
                pass

        yield "data: [DONE]\n\n"

        # Save assistant message
        assistant_msg = Message(
            conversation_id=conversation_id,
            role="assistant",
            content=assistant_content
        )
        session.add(assistant_msg)

        # Update conversation timestamp
        conversation = session.get(Conversation, conversation_id)
        if conversation:
            conversation.updated_at = datetime.utcnow()
            session.add(conversation)

        session.commit()

    except Exception as e:
        yield f"data: Error: {str(e)}\n\n"
        yield "data: [DONE]\n\n"

@router.post("/chat/stream")
async def chat_stream(
    message: str = Query(...),
    conversation_id: str = Query(None),
    user_id: str = Depends(get_current_user),
    session: Session = Depends(get_session)
):
    """
    Stream chat response via SSE.

    Args:
        message: User message
        conversation_id: Optional conversation ID (creates new if not provided)
        user_id: Authenticated user ID
        session: Database session

    Returns:
        StreamingResponse with SSE events
    """
    # Create new conversation if not provided
    if not conversation_id:
        conversation = Conversation(
            user_id=user_id,
            title=message[:50]  # Use first 50 chars as title
        )
        session.add(conversation)
        session.commit()
        session.refresh(conversation)
        conversation_id = conversation.id

    # Verify conversation belongs to user
    conversation = session.get(Conversation, conversation_id)
    if not conversation or conversation.user_id != user_id:
        return {"error": "Conversation not found"}

    return StreamingResponse(
        stream_agent_response(message, conversation_id, user_id, session),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
            "X-Accel-Buffering": "no"
        }
    )
```

### 4. Create Conversation CRUD Endpoints
Add to `backend/routes/chat.py`:
```python
from pydantic import BaseModel

class ConversationResponse(BaseModel):
    id: str
    title: str
    created_at: datetime
    updated_at: datetime

@router.get("/conversations")
async def list_conversations(
    user_id: str = Depends(get_current_user),
    session: Session = Depends(get_session)
):
    """List all conversations for user"""
    statement = select(Conversation).where(
        Conversation.user_id == user_id
    ).order_by(Conversation.updated_at.desc())

    conversations = session.exec(statement).all()

    return {
        "conversations": [
            ConversationResponse(
                id=conv.id,
                title=conv.title,
                created_at=conv.created_at,
                updated_at=conv.updated_at
            )
            for conv in conversations
        ]
    }

@router.post("/conversations")
async def create_conversation(
    title: str = "New Conversation",
    user_id: str = Depends(get_current_user),
    session: Session = Depends(get_session)
):
    """Create a new conversation"""
    conversation = Conversation(
        user_id=user_id,
        title=title
    )
    session.add(conversation)
    session.commit()
    session.refresh(conversation)

    return ConversationResponse(
        id=conversation.id,
        title=conversation.title,
        created_at=conversation.created_at,
        updated_at=conversation.updated_at
    )

@router.delete("/conversations/{conversation_id}")
async def delete_conversation(
    conversation_id: str,
    user_id: str = Depends(get_current_user),
    session: Session = Depends(get_session)
):
    """Delete a conversation and its messages"""
    conversation = session.get(Conversation, conversation_id)

    if not conversation or conversation.user_id != user_id:
        return {"error": "Conversation not found"}

    # Delete messages first
    statement = select(Message).where(
        Message.conversation_id == conversation_id
    )
    messages = session.exec(statement).all()
    for msg in messages:
        session.delete(msg)

    # Delete conversation
    session.delete(conversation)
    session.commit()

    return {"message": "Conversation deleted"}

@router.get("/conversations/{conversation_id}/messages")
async def get_messages(
    conversation_id: str,
    user_id: str = Depends(get_current_user),
    session: Session = Depends(get_session)
):
    """Get all messages for a conversation"""
    conversation = session.get(Conversation, conversation_id)

    if not conversation or conversation.user_id != user_id:
        return {"error": "Conversation not found"}

    statement = select(Message).where(
        Message.conversation_id == conversation_id
    ).order_by(Message.created_at)

    messages = session.exec(statement).all()

    return {
        "messages": [
            {
                "id": msg.id,
                "role": msg.role,
                "content": msg.content,
                "created_at": msg.created_at.isoformat()
            }
            for msg in messages
        ]
    }
```

### 5. Register Chat Routes
Update `backend/main.py`:
```python
from routes import chat

app.include_router(chat.router, prefix="/api", tags=["chat"])
```

## Key Files Created

| File | Purpose |
|------|---------|
| backend/models.py | Conversation and Message database models |
| backend/routes/chat.py | SSE streaming and conversation CRUD endpoints |
| backend/alembic/versions/*.py | Database migration for new models |

## Dependencies

| Dependency | Version | Purpose |
|------------|---------|---------|
| fastapi | ^0.109.0 | Web framework for SSE endpoint |
| sqlmodel | ^0.0.14 | ORM for conversation persistence |
| asyncpg | ^0.29.0 | PostgreSQL async driver |
| alembic | ^1.13.0 | Database migrations |

## Validation
Run: `.claude/skills/chatkit-backend/validation.sh`

Expected output:
```
✓ Conversation and Message models defined
✓ Database migration exists
✓ Chat routes registered
✓ SSE endpoint accessible
✓ Conversation CRUD endpoints working
✓ Messages persisted to database
```

## Troubleshooting

### Issue: SSE connection drops immediately
**Solution**: Ensure proper SSE headers are set (Cache-Control, Connection, X-Accel-Buffering)

### Issue: Messages not saving to database
**Solution**: Verify database session is committed after adding messages

### Issue: "Conversation not found" error
**Solution**: Check that conversation_id exists and belongs to authenticated user

### Issue: Agent streaming timeout
**Solution**: Increase timeout settings and add proper error handling in stream

## SSE Response Format

### Successful Stream
```
data: Hello

data:  there

data: ! How

data:  can

data:  I

data:  help

data: ?

data: [DONE]
```

### Error Response
```
data: Error: Failed to generate response

data: [DONE]
```

## Next Steps
After completing this skill:
1. Test SSE endpoint: `POST /api/chat/stream?message=Hello`
2. Test conversation creation: `POST /api/conversations`
3. Test message retrieval: `GET /api/conversations/{id}/messages`
4. Integrate with frontend (chatkit-frontend skill)
5. Add conversation sidebar (conversation-management skill)
