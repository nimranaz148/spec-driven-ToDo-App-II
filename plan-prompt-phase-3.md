# Implementation Plan: Todo AI Chatbot - Phase 3

**Project**: Todo AI Chatbot Application
**Phase**: Phase 3 - AI-Powered Todo Chatbot
**Branch**: `phase3/ai-chatbot`
**Date**: 2025-12-31
**Spec**: [spec-prompt-phase-3.md](./spec-prompt-phase-3.md)
**Constitution**: [constitution-prompt-phase-3.md](./constitution-prompt-phase-3.md)
**Due Date**: December 21, 2025 (8:00 PM Zoom presentation)

---

## Executive Summary

Build an AI-powered chatbot interface that allows users to manage their todos through natural language conversation. The implementation follows a staged approach: **Database Models → MCP Server → AI Agent → Chat API → Frontend UI → Integration Testing**.

**Primary Requirement**: Create a conversational AI interface using **OpenAI Agents SDK** with Gemini model, **Official MCP SDK** server for task operations, and **OpenAI ChatKit** for the frontend.

**Technical Approach**:
- **Stateless architecture** with database-persisted conversations
- **Official MCP SDK** server exposing 5 task operation tools
- **OpenAI Agents SDK** with Gemini model (via LiteLLM)
- **ChatKit UI** with Tailwind CSS fallback (90% ChatKit, 10% custom)
- **Simple request/response** (no SSE streaming for Phase 3 simplicity)
- **Single conversation** (no sidebar for Phase 3 scope)

**Architecture Pattern**: Frontend → FastAPI Chat Endpoint → OpenAI Agent → MCP Server → Database

---

## Implementation Phases

### Phase 1: Research & Environment Setup (Day 1)

**Goal**: Understand the technology stack and set up development environment.

**Tasks**:

1. **Review Documentation**
   - Read Phase 3 Constitution (`constitution-prompt-phase-3.md`)
   - Read Phase 3 Specification (`spec-prompt-phase-3.md`)
   - Review hackathon requirements for Phase 3
   - Study OpenAI Agents SDK documentation
   - Study Official MCP SDK documentation
   - Review OpenAI ChatKit documentation

2. **Install Dependencies**
   - Backend: `uv pip install openai-agents litellm mcp`
   - Frontend: Verify ChatKit package name from OpenAI docs
   - Update requirements.txt / package.json

3. **Set Up Environment Variables**
   - Add `GEMINI_API_KEY` to backend/.env
   - Add `GEMINI_MODEL=gemini-2.5-flash` to backend/.env
   - Update .env.example files

4. **Verify Phase 2 Setup**
   - Ensure Phase 2 is fully functional
   - Test JWT authentication
   - Verify task CRUD operations
   - Check database connection

**Deliverables**:
- [ ] All documentation reviewed
- [ ] Dependencies installed
- [ ] Environment variables configured
- [ ] Phase 2 verified working

**Estimated Time**: 2-3 hours

---

### Phase 2: Database Schema Extension (Day 1-2)

**Goal**: Create database models for conversations and messages.

**Tasks**:

1. **Create SQLModel Models**
   - Create `backend/models.py` (or update existing)
   - Add `Conversation` model
   - Add `Message` model
   - Keep existing `Task` model unchanged

   ```python
   # backend/models.py
   from sqlmodel import SQLModel, Field
   from datetime import datetime

   class Conversation(SQLModel, table=True):
       __tablename__ = "conversations"

       id: int | None = Field(default=None, primary_key=True)
       user_id: str = Field(index=True)
       created_at: datetime = Field(default_factory=datetime.utcnow)
       updated_at: datetime = Field(default_factory=datetime.utcnow)

   class Message(SQLModel, table=True):
       __tablename__ = "messages"

       id: int | None = Field(default=None, primary_key=True)
       user_id: str = Field(index=True)
       conversation_id: int = Field(foreign_key="conversations.id")
       role: str = Field()  # "user" | "assistant"
       content: str = Field()
       created_at: datetime = Field(default_factory=datetime.utcnow)
   ```

2. **Create Alembic Migration**
   - Generate migration: `alembic revision --autogenerate -m "Add conversations and messages tables"`
   - Review migration script
   - Test migration locally
   - Apply migration: `alembic upgrade head`

3. **Create Conversation Service**
   - Create `backend/services/conversation_service.py`
   - Methods: `get_or_create_conversation`, `get_messages`, `add_message`

   ```python
   # backend/services/conversation_service.py
   from sqlmodel import Session, select
   from backend.models import Conversation, Message

   class ConversationService:
       def __init__(self, session: Session):
           self.session = session

       async def get_or_create_conversation(
           self, user_id: str, conversation_id: int | None = None
       ) -> Conversation:
           """Get existing conversation or create new one."""
           if conversation_id:
               statement = select(Conversation).where(
                   Conversation.id == conversation_id,
                   Conversation.user_id == user_id
               )
               conversation = await self.session.exec(statement).first()
               if conversation:
                   return conversation

           # Create new conversation
           conversation = Conversation(user_id=user_id)
           self.session.add(conversation)
           await self.session.commit()
           await self.session.refresh(conversation)
           return conversation

       async def get_messages(self, conversation_id: int) -> list[Message]:
           """Get all messages for a conversation."""
           statement = select(Message).where(
               Message.conversation_id == conversation_id
           ).order_by(Message.created_at)
           messages = await self.session.exec(statement).all()
           return list(messages)

       async def add_message(
           self, conversation_id: int, user_id: str, role: str, content: str
       ) -> Message:
           """Add a message to a conversation."""
           message = Message(
               conversation_id=conversation_id,
               user_id=user_id,
               role=role,
               content=content
           )
           self.session.add(message)
           await self.session.commit()
           await self.session.refresh(message)
           return message
   ```

4. **Test Database Operations**
   - Write unit tests for conversation service
   - Test CRUD operations locally
   - Verify indexes are created

**Deliverables**:
- [ ] Conversation and Message models created
- [ ] Alembic migration created and applied
- [ ] Conversation service implemented
- [ ] Unit tests passing

**Estimated Time**: 3-4 hours

**Use Agents**:
- `@database-designer` - For schema design and migrations

---

### Phase 3: MCP Server Implementation (Day 2-3)

**Goal**: Build MCP server with Official MCP SDK exposing 5 task operation tools.

**Tasks**:

1. **Create MCP Server Structure**
   - Create `backend/mcp_server.py`
   - Initialize MCP server with Official SDK
   - Set up database connection for MCP server

   ```python
   # backend/mcp_server.py
   from mcp.server import Server
   from mcp.types import Tool, TextContent
   from sqlmodel import Session, select
   from backend.models import Task
   from backend.db import get_session

   mcp = Server("todo-mcp-server")
   ```

2. **Implement MCP Tool: add_task**
   ```python
   @mcp.tool()
   async def add_task(user_id: str, title: str, description: str = "") -> list[TextContent]:
       """
       Create a new task for the user.

       Args:
           user_id: The user's unique identifier
           title: Task title (required, max 200 chars)
           description: Task description (optional, max 1000 chars)

       Returns:
           Success message with task details
       """
       async with get_session() as session:
           task = Task(user_id=user_id, title=title, description=description)
           session.add(task)
           await session.commit()
           await session.refresh(task)
           return [TextContent(
               type="text",
               text=f"Created task #{task.id}: {task.title}"
           )]
   ```

3. **Implement MCP Tool: list_tasks**
   ```python
   @mcp.tool()
   async def list_tasks(user_id: str, status: str = "all") -> list[TextContent]:
       """
       List tasks for the user.

       Args:
           user_id: The user's unique identifier
           status: Filter by status ("all", "pending", "completed")

       Returns:
           List of tasks
       """
       async with get_session() as session:
           statement = select(Task).where(Task.user_id == user_id)

           if status == "pending":
               statement = statement.where(Task.completed == False)
           elif status == "completed":
               statement = statement.where(Task.completed == True)

           tasks = await session.exec(statement).all()

           if not tasks:
               return [TextContent(type="text", text="No tasks found.")]

           task_list = "\n".join([
               f"#{task.id}: {task.title} {'✓' if task.completed else '○'}"
               for task in tasks
           ])
           return [TextContent(type="text", text=f"Your tasks:\n{task_list}")]
   ```

4. **Implement MCP Tool: complete_task**
   ```python
   @mcp.tool()
   async def complete_task(user_id: str, task_id: int) -> list[TextContent]:
       """
       Mark a task as complete.

       Args:
           user_id: The user's unique identifier
           task_id: The task ID to complete

       Returns:
           Confirmation message
       """
       async with get_session() as session:
           statement = select(Task).where(
               Task.id == task_id,
               Task.user_id == user_id
           )
           task = await session.exec(statement).first()

           if not task:
               return [TextContent(
                   type="text",
                   text=f"Task #{task_id} not found."
               )]

           task.completed = True
           session.add(task)
           await session.commit()
           await session.refresh(task)

           return [TextContent(
               type="text",
               text=f"Completed task #{task.id}: {task.title}"
           )]
   ```

5. **Implement MCP Tool: delete_task**
   ```python
   @mcp.tool()
   async def delete_task(user_id: str, task_id: int) -> list[TextContent]:
       """
       Delete a task.

       Args:
           user_id: The user's unique identifier
           task_id: The task ID to delete

       Returns:
           Confirmation message
       """
       async with get_session() as session:
           statement = select(Task).where(
               Task.id == task_id,
               Task.user_id == user_id
           )
           task = await session.exec(statement).first()

           if not task:
               return [TextContent(
                   type="text",
                   text=f"Task #{task_id} not found."
               )]

           task_title = task.title
           await session.delete(task)
           await session.commit()

           return [TextContent(
               type="text",
               text=f"Deleted task #{task_id}: {task_title}"
           )]
   ```

6. **Implement MCP Tool: update_task**
   ```python
   @mcp.tool()
   async def update_task(
       user_id: str,
       task_id: int,
       title: str | None = None,
       description: str | None = None
   ) -> list[TextContent]:
       """
       Update a task's title or description.

       Args:
           user_id: The user's unique identifier
           task_id: The task ID to update
           title: New title (optional)
           description: New description (optional)

       Returns:
           Confirmation message
       """
       async with get_session() as session:
           statement = select(Task).where(
               Task.id == task_id,
               Task.user_id == user_id
           )
           task = await session.exec(statement).first()

           if not task:
               return [TextContent(
                   type="text",
                   text=f"Task #{task_id} not found."
               )]

           if title:
               task.title = title
           if description:
               task.description = description

           session.add(task)
           await session.commit()
           await session.refresh(task)

           return [TextContent(
               type="text",
               text=f"Updated task #{task.id}: {task.title}"
           )]
   ```

7. **Test MCP Server**
   - Write unit tests for each MCP tool
   - Test with sample user_id and task data
   - Verify error handling (task not found, unauthorized access)

**Deliverables**:
- [ ] MCP server created with Official SDK
- [ ] All 5 MCP tools implemented (add, list, complete, delete, update)
- [ ] Unit tests passing for all tools
- [ ] Error handling verified

**Estimated Time**: 4-5 hours

**Use Agents**:
- `@mcp-server-builder` - For MCP server implementation

---

### Phase 4: OpenAI Agent Implementation (Day 3-4)

**Goal**: Configure OpenAI Agent with Gemini model and connect to MCP tools.

**Tasks**:

1. **Set Up LiteLLM with Gemini**
   - Install `litellm` package
   - Configure Gemini API key
   - Test basic LiteLLM connection

2. **Create Agent Configuration**
   - Create `backend/agent/config.py`
   - Define agent instructions
   - Configure model settings

   ```python
   # backend/agent/config.py
   from agents.extensions.models.litellm import LitellmModel
   import os

   def get_model():
       return LitellmModel(
           model="gemini/gemini-2.5-flash",
           api_key=os.getenv("GEMINI_API_KEY")
       )

   AGENT_INSTRUCTIONS = """You are TodoBot, a helpful AI assistant that helps users manage their todo tasks through natural conversation.

   You have access to these tools:
   - add_task: Create a new task
   - list_tasks: Show tasks (all, pending, or completed)
   - complete_task: Mark a task as done
   - delete_task: Remove a task
   - update_task: Change task title or description

   Guidelines:
   1. Be conversational and friendly
   2. Always confirm actions (e.g., "I've created task #5: Buy groceries")
   3. When users are vague, ask clarifying questions
   4. If a user mentions multiple tasks, handle them one at a time
   5. Use list_tasks to find tasks by name when users say "delete the meeting task"
   6. Gracefully handle errors (e.g., "I couldn't find task #99")

   Examples:
   - User: "Add a task to buy groceries"
     Response: Call add_task, then say "I've added 'Buy groceries' to your list!"

   - User: "What do I need to do?"
     Response: Call list_tasks(status="pending"), then list them

   - User: "I finished task 3"
     Response: Call complete_task(task_id=3), then say "Great job! I've marked task #3 as complete."
   """
   ```

3. **Create Agent Tool Wrappers**
   - Create `backend/agent/tools.py`
   - Wrap each MCP tool as an agent function_tool

   ```python
   # backend/agent/tools.py
   from agents import function_tool
   from backend.mcp_server import (
       add_task as mcp_add_task,
       list_tasks as mcp_list_tasks,
       complete_task as mcp_complete_task,
       delete_task as mcp_delete_task,
       update_task as mcp_update_task
   )

   @function_tool
   async def add_task(user_id: str, title: str, description: str = "") -> str:
       """Create a new task for the user."""
       result = await mcp_add_task(user_id, title, description)
       return result[0].text

   @function_tool
   async def list_tasks(user_id: str, status: str = "all") -> str:
       """List tasks for the user."""
       result = await mcp_list_tasks(user_id, status)
       return result[0].text

   @function_tool
   async def complete_task(user_id: str, task_id: int) -> str:
       """Mark a task as complete."""
       result = await mcp_complete_task(user_id, task_id)
       return result[0].text

   @function_tool
   async def delete_task(user_id: str, task_id: int) -> str:
       """Delete a task."""
       result = await mcp_delete_task(user_id, task_id)
       return result[0].text

   @function_tool
   async def update_task(
       user_id: str,
       task_id: int,
       title: str | None = None,
       description: str | None = None
   ) -> str:
       """Update a task's title or description."""
       result = await mcp_update_task(user_id, task_id, title, description)
       return result[0].text
   ```

4. **Create Agent Runner**
   - Create `backend/agent/runner.py`
   - Initialize agent with tools
   - Create run function

   ```python
   # backend/agent/runner.py
   from agents import Agent, Runner
   from backend.agent.config import get_model, AGENT_INSTRUCTIONS
   from backend.agent.tools import (
       add_task, list_tasks, complete_task, delete_task, update_task
   )

   def create_agent(user_id: str) -> Agent:
       """Create an agent instance for a user."""
       model = get_model()

       # Bind user_id to tools
       tools = [
           lambda title, description="": add_task(user_id, title, description),
           lambda status="all": list_tasks(user_id, status),
           lambda task_id: complete_task(user_id, task_id),
           lambda task_id: delete_task(user_id, task_id),
           lambda task_id, title=None, description=None: update_task(user_id, task_id, title, description)
       ]

       return Agent(
           name="TodoBot",
           instructions=AGENT_INSTRUCTIONS,
           model=model,
           tools=tools
       )

   async def run_agent(user_id: str, messages: list[dict]) -> str:
       """Run the agent with a conversation history."""
       agent = create_agent(user_id)
       runner = Runner(agent)
       result = await runner.run(messages=messages)
       return result.content
   ```

5. **Test Agent Locally**
   - Write integration tests for agent
   - Test with sample conversations
   - Verify tool calls are made correctly
   - Test error handling

**Deliverables**:
- [ ] LiteLLM configured with Gemini
- [ ] Agent configuration created
- [ ] Tool wrappers implemented
- [ ] Agent runner created
- [ ] Integration tests passing

**Estimated Time**: 4-5 hours

**Use Agents**:
- `@ai-agent-builder` - For OpenAI Agents SDK integration

---

### Phase 5: Chat API Endpoint (Day 4)

**Goal**: Create FastAPI chat endpoint that orchestrates the full flow.

**Tasks**:

1. **Create Chat Request/Response Models**
   - Create `backend/schemas/chat.py`
   - Define Pydantic models for request and response

   ```python
   # backend/schemas/chat.py
   from pydantic import BaseModel, Field

   class ChatRequest(BaseModel):
       conversation_id: int | None = Field(default=None)
       message: str = Field(..., min_length=1, max_length=4000)

   class ToolCall(BaseModel):
       tool: str
       parameters: dict
       result: dict

   class ChatResponse(BaseModel):
       conversation_id: int
       response: str
       tool_calls: list[ToolCall] = []
   ```

2. **Create Chat Router**
   - Create `backend/routes/chat.py`
   - Implement POST /api/{user_id}/chat endpoint

   ```python
   # backend/routes/chat.py
   from fastapi import APIRouter, Depends, HTTPException
   from backend.schemas.chat import ChatRequest, ChatResponse
   from backend.services.conversation_service import ConversationService
   from backend.agent.runner import run_agent
   from backend.auth import get_current_user, CurrentUser
   from backend.db import get_session

   router = APIRouter(prefix="/api", tags=["chat"])

   @router.post("/{user_id}/chat", response_model=ChatResponse)
   async def chat(
       user_id: str,
       request: ChatRequest,
       current_user: CurrentUser = Depends(get_current_user),
       session = Depends(get_session)
   ):
       # 1. Validate user_id matches JWT token
       if user_id != current_user.id:
           raise HTTPException(status_code=403, detail="Unauthorized")

       # 2. Get or create conversation
       conversation_service = ConversationService(session)
       conversation = await conversation_service.get_or_create_conversation(
           user_id, request.conversation_id
       )

       # 3. Load conversation history
       history = await conversation_service.get_messages(conversation.id)
       messages = [{"role": msg.role, "content": msg.content} for msg in history]

       # 4. Add new user message
       messages.append({"role": "user", "content": request.message})

       # 5. Store user message in database
       await conversation_service.add_message(
           conversation.id, user_id, "user", request.message
       )

       # 6. Run agent
       try:
           response_content = await run_agent(user_id, messages)
       except Exception as e:
           raise HTTPException(status_code=500, detail=f"Agent error: {str(e)}")

       # 7. Store assistant response
       await conversation_service.add_message(
           conversation.id, user_id, "assistant", response_content
       )

       # 8. Return response
       return ChatResponse(
           conversation_id=conversation.id,
           response=response_content,
           tool_calls=[]  # Can be populated if agent returns tool call info
       )
   ```

3. **Add Chat Router to Main App**
   - Update `backend/main.py`
   - Include chat router

   ```python
   # backend/main.py
   from backend.routes.chat import router as chat_router

   app.include_router(chat_router)
   ```

4. **Add Rate Limiting (Optional but Recommended)**
   - Install `slowapi` package
   - Configure rate limiter (30 requests/minute per user)

5. **Test Chat Endpoint**
   - Write integration tests
   - Test with Postman/curl
   - Verify JWT authentication
   - Verify conversation persistence

**Deliverables**:
- [ ] Chat request/response models created
- [ ] Chat endpoint implemented
- [ ] Chat router added to main app
- [ ] JWT authentication enforced
- [ ] Integration tests passing

**Estimated Time**: 3-4 hours

**Use Agents**:
- `@backend-api-builder` - For endpoint implementation

---

### Phase 6: Frontend Chat UI (Day 5-6)

**Goal**: Build chat interface using OpenAI ChatKit (with Tailwind fallback).

**Tasks**:

1. **Verify ChatKit Package**
   - Check OpenAI documentation for ChatKit
   - Verify package name and installation
   - If ChatKit not available, plan custom UI with Tailwind

2. **Create Chat Page**
   - Create `frontend/app/chat/page.tsx`
   - Set up protected route (require authentication)

3. **Implement Chat Interface (Option A: ChatKit)**
   ```typescript
   // frontend/app/chat/page.tsx
   'use client';

   // NOTE: Verify exact ChatKit package and imports from OpenAI docs
   // This is a placeholder - adjust based on actual ChatKit API

   import { ChatInterface } from '@openai/chatkit'; // Verify package name
   import { useState } from 'react';
   import { api } from '@/lib/api';

   export default function ChatPage() {
     const [conversationId, setConversationId] = useState<number | null>(null);

     const handleSendMessage = async (message: string) => {
       const response = await api.sendChatMessage({
         conversation_id: conversationId,
         message
       });

       if (!conversationId) {
         setConversationId(response.conversation_id);
       }

       return response.response;
     };

     return (
       <div className="flex flex-col h-screen">
         <div className="flex-1 overflow-hidden">
           <ChatInterface
             onSendMessage={handleSendMessage}
             className="h-full"
           />
         </div>
       </div>
     );
   }
   ```

4. **Implement Chat Interface (Option B: Custom Fallback)**
   ```typescript
   // frontend/app/chat/page.tsx
   'use client';

   import { useState, useEffect, useRef } from 'react';
   import { api } from '@/lib/api';

   interface Message {
     id: number;
     role: 'user' | 'assistant';
     content: string;
     created_at: string;
   }

   export default function ChatPage() {
     const [messages, setMessages] = useState<Message[]>([]);
     const [input, setInput] = useState('');
     const [isLoading, setIsLoading] = useState(false);
     const [conversationId, setConversationId] = useState<number | null>(null);
     const messagesEndRef = useRef<HTMLDivElement>(null);

     const scrollToBottom = () => {
       messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
     };

     useEffect(() => {
       scrollToBottom();
     }, [messages]);

     const handleSendMessage = async (e: React.FormEvent) => {
       e.preventDefault();
       if (!input.trim() || isLoading) return;

       setIsLoading(true);

       // Add user message optimistically
       const userMessage: Message = {
         id: Date.now(),
         role: 'user',
         content: input,
         created_at: new Date().toISOString()
       };
       setMessages(prev => [...prev, userMessage]);
       setInput('');

       try {
         // Call backend
         const response = await api.sendChatMessage({
           conversation_id: conversationId,
           message: input
         });

         // Add assistant response
         const assistantMessage: Message = {
           id: Date.now() + 1,
           role: 'assistant',
           content: response.response,
           created_at: new Date().toISOString()
         };
         setMessages(prev => [...prev, assistantMessage]);

         // Update conversation ID
         if (!conversationId) {
           setConversationId(response.conversation_id);
         }
       } catch (error) {
         console.error('Failed to send message:', error);
         // Show error message
       } finally {
         setIsLoading(false);
       }
     };

     return (
       <div className="flex flex-col h-screen bg-gray-50">
         {/* Header */}
         <div className="bg-white border-b px-4 py-3">
           <h1 className="text-xl font-semibold">Todo Assistant</h1>
         </div>

         {/* Messages */}
         <div className="flex-1 overflow-y-auto p-4 space-y-4">
           {messages.map((msg) => (
             <div
               key={msg.id}
               className={`flex ${msg.role === 'user' ? 'justify-end' : 'justify-start'}`}
             >
               <div
                 className={`max-w-[70%] rounded-lg p-3 ${
                   msg.role === 'user'
                     ? 'bg-blue-500 text-white'
                     : 'bg-white text-gray-900 border'
                 }`}
               >
                 <p className="whitespace-pre-wrap">{msg.content}</p>
               </div>
             </div>
           ))}
           <div ref={messagesEndRef} />
         </div>

         {/* Input */}
         <div className="bg-white border-t p-4">
           <form onSubmit={handleSendMessage} className="flex gap-2">
             <input
               type="text"
               value={input}
               onChange={(e) => setInput(e.target.value)}
               placeholder="Type a message..."
               disabled={isLoading}
               className="flex-1 px-4 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
             />
             <button
               type="submit"
               disabled={isLoading || !input.trim()}
               className="px-6 py-2 bg-blue-500 text-white rounded-lg hover:bg-blue-600 disabled:opacity-50 disabled:cursor-not-allowed"
             >
               {isLoading ? 'Sending...' : 'Send'}
             </button>
           </form>
         </div>
       </div>
     );
   }
   ```

5. **Create API Client Method**
   - Update `frontend/lib/api.ts`
   - Add `sendChatMessage` method

   ```typescript
   // frontend/lib/api.ts
   export const api = {
     // ... existing methods ...

     async sendChatMessage(data: { conversation_id: number | null; message: string }) {
       const userId = getUserIdFromSession(); // Get from Better Auth session
       const response = await fetch(`/api/${userId}/chat`, {
         method: 'POST',
         headers: {
           'Content-Type': 'application/json',
           'Authorization': `Bearer ${getAuthToken()}`
         },
         body: JSON.stringify(data)
       });

       if (!response.ok) {
         throw new Error('Failed to send message');
       }

       return response.json();
     }
   };
   ```

6. **Add Navigation Link**
   - Update main navigation to include "Chat" link
   - Add to header/sidebar

7. **Style and Polish**
   - Ensure responsive design (mobile-friendly)
   - Add loading indicators
   - Add error handling UI
   - Test on different screen sizes

**Deliverables**:
- [ ] Chat page created
- [ ] ChatKit integrated (or custom fallback implemented)
- [ ] API client method added
- [ ] Navigation link added
- [ ] Responsive design verified
- [ ] Error handling implemented

**Estimated Time**: 5-6 hours

**Use Agents**:
- `@chatbot-ui-builder` - For chat UI implementation
- `@frontend-ui-builder` - For components

---

### Phase 7: Integration Testing (Day 6-7)

**Goal**: Test full conversation flow and fix issues.

**Tasks**:

1. **End-to-End Testing**
   - Test complete flow: login → chat → create task → verify task in task list
   - Test conversation persistence (reload page, verify messages remain)
   - Test multiple conversations
   - Test error handling (invalid task_id, network errors)

2. **Natural Language Command Testing**
   Test all command variations:
   - "Add a task to buy groceries"
   - "Show me all my tasks"
   - "What's pending?"
   - "Mark task 3 as complete"
   - "Delete task 7"
   - "Change task 1 to 'Call mom tonight'"
   - "I need to remember to pay bills"
   - "What have I completed?"

3. **Unit Tests**
   - Test agent tool functions
   - Test MCP tool handlers
   - Test conversation service methods

4. **Integration Tests**
   - Test chat API endpoint
   - Test JWT authentication and authorization
   - Test user isolation (can't access other users' conversations)

5. **Performance Testing**
   - Measure response time (should be < 5 seconds for simple commands)
   - Test concurrent sessions (at least 10 simultaneous users)
   - Measure database query performance

6. **Security Testing**
   - Test JWT validation
   - Test user isolation
   - Test input validation (max 4000 chars)
   - Test SQL injection prevention
   - Test XSS prevention

7. **Browser Testing**
   - Test on Chrome
   - Test on Firefox
   - Test on Safari (if available)
   - Test mobile responsiveness (iOS Safari, Android Chrome)

8. **Fix Issues**
   - Address bugs found in testing
   - Optimize performance bottlenecks
   - Improve error messages
   - Refine agent prompts if needed

**Deliverables**:
- [ ] E2E tests passing
- [ ] All natural language commands working
- [ ] Unit tests passing
- [ ] Integration tests passing
- [ ] Performance benchmarks met
- [ ] Security checklist verified
- [ ] Cross-browser compatibility verified
- [ ] All issues fixed

**Estimated Time**: 4-5 hours

---

### Phase 8: Documentation & Deployment (Day 7)

**Goal**: Complete documentation and deploy to production.

**Tasks**:

1. **Update README**
   - Add Phase 3 features description
   - Add setup instructions for Phase 3
   - Document environment variables:
     - `GEMINI_API_KEY`
     - `GEMINI_MODEL`
   - Add usage examples

2. **Update Environment Variables**
   - Update `.env.example` files (backend and frontend)
   - Document required variables
   - Add instructions for obtaining Gemini API key

3. **Create API Documentation**
   - Document chat endpoint: POST /api/{user_id}/chat
   - Add request/response examples
   - Document error codes

4. **Deploy Backend**
   - Deploy to Vercel/Railway/Render
   - Configure environment variables in deployment platform
   - Apply database migrations on production
   - Test chat endpoint in production

5. **Deploy Frontend**
   - Deploy to Vercel
   - Configure environment variables
   - If using ChatKit: Configure domain allowlist on OpenAI platform
   - Set `NEXT_PUBLIC_OPENAI_DOMAIN_KEY` if required
   - Test chat page in production

6. **Create Demo Video**
   - Record 90-second walkthrough (MAX)
   - Show:
     - Login to app
     - Open chat interface
     - Add task via natural language
     - List tasks via natural language
     - Complete task via natural language
     - Verify task updates in main task list
   - Keep under 90 seconds (judges only watch first 90 seconds)
   - Upload to YouTube or Google Drive

7. **Submit to Hackathon**
   - Fill out submission form: https://forms.gle/KMKEKaFUD6ZX4UtY8
   - Submit:
     - Public GitHub repo link
     - Deployed app link (Vercel)
     - Demo video link (under 90 seconds)
     - WhatsApp number for presentation invitation

**Deliverables**:
- [ ] README updated with Phase 3 info
- [ ] Environment variables documented
- [ ] API documentation created
- [ ] Backend deployed to production
- [ ] Frontend deployed to production
- [ ] ChatKit domain allowlist configured (if applicable)
- [ ] Demo video created (<90 seconds)
- [ ] Hackathon submission completed

**Estimated Time**: 3-4 hours

---

## Testing Strategy

### Unit Tests
- **Agent Tool Wrappers**: Test each @function_tool
- **MCP Tools**: Test each @mcp.tool handler
- **Conversation Service**: Test CRUD operations

**Coverage Goal**: 80% backend, 70% frontend

### Integration Tests
- **Chat API**: Test full chat flow
- **JWT Authentication**: Test token validation
- **User Isolation**: Test access control

**Coverage Goal**: 100% for critical paths

### E2E Tests
- **Full Flow**: Login → Chat → Create Task → Verify
- **Persistence**: Reload page, verify messages remain
- **Natural Language**: Test all command variations

**Coverage Goal**: 100% for user stories

---

## Security Considerations

### Authentication
- JWT validation on all chat endpoints
- Extract user_id from token payload
- Verify user_id in URL matches JWT token

### Data Isolation
- Filter conversations by user_id
- MCP tools enforce user_id ownership
- No cross-user data access

### Input Validation
- Limit message length: **max 4000 characters**
- Sanitize content before processing
- Validate conversation ownership

### Rate Limiting (Recommended)
- **30 messages/minute per user**
- Prevent API abuse
- Clear error messages when limit exceeded

---

## Performance Optimization

### Backend
- Connection pooling for database
- Async agent execution
- Efficient message history loading (load all for Phase 3 simplicity)

### Frontend
- Optimistic UI updates (show user message immediately)
- Loading indicators during processing
- Error handling with user-friendly messages

### Agent
- Efficient tool execution
- Clear agent instructions to reduce token usage

---

## Risk Mitigation

| Risk | Mitigation Strategy |
|------|---------------------|
| Gemini API latency | Show loading indicators, set user expectations |
| MCP integration complexity | Use Official MCP SDK patterns, thorough testing |
| ChatKit unavailability | Implement custom fallback UI with Tailwind (90% ChatKit, 10% custom) |
| Prompt injection | Sanitize inputs (max 4000 chars), clear agent boundaries |
| Rate limit abuse | 30 messages/minute per user with clear error messages |
| Database connection issues | Connection pooling, retry logic |

---

## Timeline Estimate

**Total Duration**: 7 days (Due: December 21, 2025)

| Day | Phase | Estimated Time |
|-----|-------|----------------|
| Day 1 | Research & Setup + Database Models | 5-7 hours |
| Day 2 | MCP Server Implementation | 4-5 hours |
| Day 3 | OpenAI Agent Implementation | 4-5 hours |
| Day 4 | Chat API Endpoint | 3-4 hours |
| Day 5-6 | Frontend Chat UI | 5-6 hours |
| Day 6-7 | Integration Testing | 4-5 hours |
| Day 7 | Documentation & Deployment | 3-4 hours |

**Total Estimated Time**: 28-36 hours

---

## Success Metrics

Phase 3 is successful when:

1. ✅ Users can create tasks via natural language (90%+ success rate)
2. ✅ All 5 MCP tools working (add, list, complete, delete, update)
3. ✅ Conversation history persists across page refreshes
4. ✅ ChatKit UI (or custom fallback) responsive and functional
5. ✅ User isolation enforced (can't see others' conversations)
6. ✅ Response time < 5 seconds for simple commands
7. ✅ Deployed and accessible on Vercel
8. ✅ Demo video created (<90 seconds)
9. ✅ Hackathon submission completed

---

## Specialized Resources

### Agents to Use
- `@database-designer` - Database schema and migrations
- `@mcp-server-builder` - MCP server development
- `@ai-agent-builder` - OpenAI Agents SDK integration
- `@backend-api-builder` - Chat API endpoints
- `@chatbot-ui-builder` - ChatKit UI implementation
- `@frontend-ui-builder` - Frontend components

### Use Context7 MCP BEFORE Implementation
Always fetch latest library documentation via Context7:
- **OpenAI Agents SDK**: `context7://openai-agents/latest`
- **Official MCP SDK**: `context7://mcp/latest`
- **LiteLLM**: `context7://litellm/latest`
- **OpenAI ChatKit**: `context7://openai-chatkit/latest` (verify package)

**Example prompt**:
> "Use Context7 to fetch latest OpenAI Agents SDK documentation for agent configuration and tool integration"

---

## Key Simplifications for Phase 3

Compared to the reference file, Phase 3 has been simplified:

1. **No SSE Streaming**: Simple request/response for faster implementation
2. **No Conversation Sidebar**: Single conversation focus
3. **No Message Pagination**: Load full history (reasonable for Phase 3)
4. **No Conversation Management**: Create conversation on first message
5. **ChatKit Fallback**: Custom Tailwind UI if ChatKit unavailable (90% ChatKit, 10% custom)

**Rationale**: These simplifications allow focus on core functionality (natural language task management) while staying within the 7-day deadline.

---

## Next Steps

After completing this plan:

1. ✅ **Phase 1**: Start with Research & Environment Setup
2. ✅ **Phase 2**: Create Database Models and Migration
3. ✅ **Phase 3**: Implement MCP Server with Official SDK
4. ✅ **Phase 4**: Configure OpenAI Agent with Gemini
5. ✅ **Phase 5**: Create Chat API Endpoint
6. ✅ **Phase 6**: Build Frontend Chat UI
7. ✅ **Phase 7**: Integration Testing
8. ✅ **Phase 8**: Documentation & Deployment

---

## References

- [Phase 3 Specification](./spec-prompt-phase-3.md)
- [Phase 3 Constitution](./constitution-prompt-phase-3.md)
- [Hackathon II Documentation](./Hackathon%20II%20-%20Todo%20Spec-Driven%20Development%20(1).md)
- [OpenAI Agents SDK Documentation](https://openai.github.io/openai-agents-python/)
- [Official MCP SDK Documentation](https://github.com/modelcontextprotocol/python-sdk)
- [OpenAI ChatKit Documentation](https://platform.openai.com/docs/guides/chatkit)
- [OpenAI ChatKit Domain Allowlist](https://platform.openai.com/settings/organization/security/domain-allowlist)
- [LiteLLM Documentation](https://docs.litellm.ai/)
- [Gemini API Documentation](https://ai.google.dev/docs)

---

**Status**: Ready for implementation
**Next Step**: Begin Phase 1 - Research & Environment Setup
**Estimated Completion**: December 21, 2025 (7 days)
**Complexity**: High (AI integration, MCP server, stateless architecture)

---

**Version**: 1.0.0 | **Created**: 2025-12-31 | **Last Updated**: 2025-12-31
