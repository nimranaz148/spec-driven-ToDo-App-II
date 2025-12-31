# Todo App - Phase 3 Constitution

**Project**: Todo AI Chatbot Application
**Phase**: Phase 3 - AI-Powered Todo Chatbot
**Version**: 1.0.0
**Ratified**: 2025-12-31
**Status**: Active
**Builds Upon**: Phase 2 Constitution (Full-Stack Web Application)

---

## CLAUDE.md Integration (READ FIRST)

**This constitution is coupled with the CLAUDE.md hierarchy. Before any work:**

1. **Read CLAUDE.md files in order:**
   - `CLAUDE.md` (root) - Master project rules and Context7 MCP integration
   - `frontend/CLAUDE.md` - Frontend-specific guidelines
   - `backend/CLAUDE.md` - Backend-specific guidelines

2. **Use Context7 MCP BEFORE implementation:**
   - Always fetch latest library documentation via Context7
   - Required lookups: `openai-agents-sdk`, `mcp` (Official MCP SDK), `openai-chatkit`
   - Context7 URL: `https://mcp.context7.com/mcp`
   - Never assume API patterns - verify first

3. **Reference existing architecture:**
   - Check Phase 2 implementation patterns
   - Reuse existing JWT auth system
   - Extend existing database models
   - Follow established API conventions

**Coupling:** All CLAUDE.md files reference this constitution. This constitution references all CLAUDE.md files. They work together as a unified system.

---

## Project Overview

This is the constitution for the Todo App Hackathon Phase 3, where we transform the Phase 2 web application into an AI-powered chatbot interface for managing todos through natural language. This document defines the principles, standards, and practices that govern how AI agents manage tasks through conversational interfaces using MCP (Model Context Protocol) server architecture.

**Phase 3 Core Objectives:**
1. Implement conversational interface for all Basic Level features
2. Use OpenAI Agents SDK for AI logic
3. Build MCP server with Official MCP SDK that exposes task operations as tools
4. Create stateless chat endpoint that persists conversation state to database
5. AI agents use MCP tools to manage tasks (stateless with database persistence)

---

## Technology Stack

### Frontend
- **Framework**: Next.js 16+ (App Router)
- **UI Library**: OpenAI ChatKit
- **State Management**: React Context / Zustand (for conversation state)
- **Styling**: Tailwind CSS
- **Authentication**: Better Auth (existing from Phase 2)

### Backend
- **API Framework**: Python FastAPI
- **AI Framework**: OpenAI Agents SDK
- **MCP Server**: Official MCP SDK (Python)
- **ORM**: SQLModel
- **Database**: Neon Serverless PostgreSQL
- **Authentication**: JWT verification (existing from Phase 2)

### Infrastructure
- **Frontend Hosting**: Vercel
- **Database**: Neon Serverless PostgreSQL (existing)
- **Environment**: Python 3.13+, Node.js 18+

---

## Core Principles

### 1. Stateless Architecture
**Description**: The chat endpoint and MCP server must be completely stateless. All conversation state persists in the database.

**Benefits**:
- Scalability: Any server instance can handle any request
- Resilience: Server restarts don't lose conversation state
- Horizontal scaling: Load balancer can route to any backend
- Testability: Each request is independent and reproducible

**Implementation**:
```python
# GOOD: Stateless chat endpoint
@app.post("/api/{user_id}/chat")
async def chat(user_id: str, request: ChatRequest):
    # 1. Fetch conversation history from database
    conversation = await get_or_create_conversation(user_id, request.conversation_id)
    history = await get_messages(conversation.id)

    # 2. Build message array (history + new message)
    messages = [{"role": msg.role, "content": msg.content} for msg in history]
    messages.append({"role": "user", "content": request.message})

    # 3. Store user message
    await store_message(conversation.id, "user", request.message)

    # 4. Run agent
    response = await agent.run(messages)

    # 5. Store assistant response
    await store_message(conversation.id, "assistant", response.content)

    # 6. Return response (no server state)
    return {"conversation_id": conversation.id, "response": response.content}
```

**Rationale**: Stateless servers are essential for cloud-native, scalable applications. Conversations can resume after server restarts.

---

### 2. MCP-First Tool Design
**Description**: All task operations must be exposed as MCP tools, following the Official MCP SDK patterns.

**MCP Tool Structure**:
```python
from mcp.server import Server
from mcp.types import Tool, TextContent

mcp = Server("todo-mcp-server")

@mcp.tool()
async def add_task(user_id: str, title: str, description: str = "") -> list[TextContent]:
    """
    Create a new task for the user.

    Args:
        user_id: The user's unique identifier
        title: Task title (required)
        description: Optional task description

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

**Required MCP Tools**:
1. `add_task(user_id, title, description)` - Create new task
2. `list_tasks(user_id, status)` - Retrieve tasks (all/pending/completed)
3. `complete_task(user_id, task_id)` - Mark task as complete
4. `delete_task(user_id, task_id)` - Remove task
5. `update_task(user_id, task_id, title, description)` - Modify task

**Tool Design Principles**:
- Tools are thin wrappers around database operations
- Tools handle their own error responses
- Tools validate user ownership of resources
- Never expose raw database errors to AI agent
- Return structured, human-readable responses

**Rationale**: MCP provides a standardized interface for AI agents to interact with your application. This decouples the AI logic from business logic.

---

### 3. OpenAI Agents SDK Integration
**Description**: Use OpenAI Agents SDK (with Gemini model via LiteLLM) to orchestrate tool calls and manage conversation flow.

**Agent Configuration**:
```python
from agents import Agent, Runner
from agents.extensions.models.litellm import LitellmModel

# Model setup
model = LitellmModel(
    model="gemini/gemini-2.5-flash",
    api_key=os.getenv("GEMINI_API_KEY")
)

# Agent definition
agent = Agent(
    name="TodoBot",
    instructions="""You are a helpful todo assistant. You help users manage their tasks through natural conversation.

When users want to:
- Add a task: Use add_task tool
- See tasks: Use list_tasks tool (filter by status if specified)
- Complete a task: Use complete_task tool
- Delete a task: Use delete_task tool
- Update a task: Use update_task tool

Always confirm actions with friendly responses. Be conversational and helpful.""",
    model=model,
    tools=[add_task_tool, list_tasks_tool, complete_task_tool, delete_task_tool, update_task_tool]
)

# Agent execution
async def run_agent(messages: list[dict]) -> str:
    runner = Runner(agent)
    result = await runner.run(messages=messages)
    return result.content
```

**Agent Behavior Requirements**:
| User Intent | Tool to Call | Example Phrase |
|-------------|--------------|----------------|
| Task Creation | `add_task` | "Add a task to buy groceries" |
| Task Listing | `list_tasks` | "Show me all my tasks", "What's pending?" |
| Task Completion | `complete_task` | "Mark task 3 as complete", "I finished that" |
| Task Deletion | `delete_task` | "Delete the meeting task" |
| Task Update | `update_task` | "Change task 1 to 'Call mom tonight'" |

**Rationale**: OpenAI Agents SDK provides robust conversation management and tool orchestration, reducing boilerplate code.

---

### 4. Database Schema Extension
**Description**: Extend Phase 2 database schema with conversation and message models.

**New Database Models**:

```python
from sqlmodel import SQLModel, Field
from datetime import datetime

class Conversation(SQLModel, table=True):
    """Represents a chat session for a user."""
    __tablename__ = "conversations"

    id: int | None = Field(default=None, primary_key=True)
    user_id: str = Field(index=True)
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)

class Message(SQLModel, table=True):
    """Represents a single message in a conversation."""
    __tablename__ = "messages"

    id: int | None = Field(default=None, primary_key=True)
    user_id: str = Field(index=True)
    conversation_id: int = Field(foreign_key="conversations.id")
    role: str = Field()  # "user" or "assistant"
    content: str = Field()
    created_at: datetime = Field(default_factory=datetime.utcnow)
```

**Existing Model (unchanged)**:
```python
class Task(SQLModel, table=True):
    """Todo task (from Phase 2)."""
    __tablename__ = "tasks"

    id: int | None = Field(default=None, primary_key=True)
    user_id: str = Field(index=True)
    title: str = Field()
    description: str = Field(default="")
    completed: bool = Field(default=False)
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)
```

**Migration Strategy**:
- Create new tables (conversations, messages)
- Do NOT modify existing tasks table
- Use Alembic for migration scripts

**Rationale**: Conversation persistence enables stateless server design and allows users to resume chats after server restarts.

---

### 5. ChatKit Frontend Integration
**Description**: Use OpenAI ChatKit for the chat interface, with fallback to custom implementation if needed.

**ChatKit Setup**:
```typescript
// Note: Verify exact ChatKit package and API from OpenAI documentation
// Use Context7 MCP to fetch latest ChatKit patterns before implementation

'use client';

import { useState } from 'react';

interface Message {
  role: 'user' | 'assistant';
  content: string;
}

export function ChatInterface() {
  const [messages, setMessages] = useState<Message[]>([]);
  const [isLoading, setIsLoading] = useState(false);

  const handleSendMessage = async (content: string) => {
    setIsLoading(true);

    // Add user message
    setMessages(prev => [...prev, { role: 'user', content }]);

    // Call backend
    const response = await fetch('/api/chat', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${getAuthToken()}`
      },
      body: JSON.stringify({ message: content })
    });

    const data = await response.json();

    // Add assistant response
    setMessages(prev => [...prev, { role: 'assistant', content: data.response }]);
    setIsLoading(false);
  };

  return (
    <div className="flex flex-col h-full">
      {/* Message list */}
      <div className="flex-1 overflow-y-auto p-4 space-y-4">
        {messages.map((msg, i) => (
          <div key={i} className={`flex ${msg.role === 'user' ? 'justify-end' : 'justify-start'}`}>
            <div className={`max-w-[70%] rounded-lg p-3 ${
              msg.role === 'user' ? 'bg-blue-500 text-white' : 'bg-gray-200 text-gray-900'
            }`}>
              {msg.content}
            </div>
          </div>
        ))}
      </div>

      {/* Input area */}
      <div className="border-t p-4">
        <form onSubmit={(e) => {
          e.preventDefault();
          const input = e.currentTarget.elements.namedItem('message') as HTMLInputElement;
          handleSendMessage(input.value);
          input.value = '';
        }}>
          <input
            name="message"
            type="text"
            placeholder="Type a message..."
            disabled={isLoading}
            className="w-full p-2 border rounded-lg"
          />
        </form>
      </div>
    </div>
  );
}
```

**ChatKit Domain Allowlist Configuration**:
- **Local Development**: `localhost` works without configuration
- **Production Deployment**:
  1. Deploy frontend to get URL (e.g., `https://your-app.vercel.app`)
  2. Add domain to OpenAI allowlist: https://platform.openai.com/settings/organization/security/domain-allowlist
  3. Get ChatKit domain key and add to environment variables

**Environment Variable**:
```env
NEXT_PUBLIC_OPENAI_DOMAIN_KEY=your-domain-key-here
```

**UI Strategy**: 90% ChatKit (if available), 10% Custom Fallback
- Primary: Use OpenAI ChatKit components
- Fallback: If ChatKit doesn't work, implement custom chat UI with Tailwind

**Rationale**: ChatKit provides production-ready chat UI with minimal setup. Custom fallback ensures project completion even if ChatKit has issues.

---

## Architecture Diagram

```
┌───────────────────────────────────────────────────────────────────────┐
│                        Next.js Frontend                                │
│  ┌─────────────────────────────────────────────────────────────┐      │
│  │              ChatKit UI / Custom Chat UI                     │      │
│  │  - Message display                                           │      │
│  │  - Input field                                               │      │
│  │  - Conversation management                                   │      │
│  └─────────────────────────────────────────────────────────────┘      │
└───────────────────────────┬───────────────────────────────────────────┘
                            │ POST /api/{user_id}/chat
                            ▼
┌───────────────────────────────────────────────────────────────────────┐
│                        FastAPI Backend                                 │
│  ┌─────────────────────────────────────────────────────────────┐      │
│  │                    Chat Endpoint                             │      │
│  │  - JWT validation                                            │      │
│  │  - Fetch conversation history from DB                        │      │
│  │  - Build message array                                       │      │
│  │  - Store user message                                        │      │
│  └─────────────────────────────────────────────────────────────┘      │
│                            │                                           │
│                            ▼                                           │
│  ┌─────────────────────────────────────────────────────────────┐      │
│  │              OpenAI Agents SDK (Agent + Runner)              │      │
│  │  - Gemini model via LiteLLM                                  │      │
│  │  - System prompt defining behavior                           │      │
│  │  - Tool orchestration                                        │      │
│  └─────────────────────────────────────────────────────────────┘      │
│                            │                                           │
│                            ▼                                           │
│  ┌─────────────────────────────────────────────────────────────┐      │
│  │                MCP Server (Official SDK)                     │      │
│  │  - add_task, list_tasks, complete_task                       │      │
│  │  - delete_task, update_task                                  │      │
│  │  - Direct database operations via SQLModel                   │      │
│  └─────────────────────────────────────────────────────────────┘      │
└───────────────────────────┬───────────────────────────────────────────┘
                            │
                            ▼
┌───────────────────────────────────────────────────────────────────────┐
│                    Neon PostgreSQL Database                            │
│  - tasks (existing from Phase 2)                                       │
│  - conversations (new)                                                 │
│  - messages (new)                                                      │
└───────────────────────────────────────────────────────────────────────┘
```

---

## API Specifications

### Chat Endpoint

**Endpoint**: `POST /api/{user_id}/chat`

**Request**:
```json
{
  "conversation_id": 123,  // optional, creates new if not provided
  "message": "Add a task to buy groceries"
}
```

**Response**:
```json
{
  "conversation_id": 123,
  "response": "I've created a new task: Buy groceries (Task #5)",
  "tool_calls": [
    {
      "tool": "add_task",
      "parameters": {
        "user_id": "user123",
        "title": "Buy groceries"
      }
    }
  ]
}
```

**Authentication**: Requires JWT token in `Authorization: Bearer <token>` header

**Validation**:
- `user_id` in URL must match user_id in JWT token
- `message` is required, max 2000 characters
- `conversation_id` if provided must belong to the authenticated user

---

## Natural Language Commands

The chatbot must understand and respond to:

| User Says | Agent Should Do |
|-----------|-----------------|
| "Add a task to buy groceries" | Call `add_task` with title "Buy groceries" |
| "Show me all my tasks" | Call `list_tasks` with status "all" |
| "What's pending?" | Call `list_tasks` with status "pending" |
| "Mark task 3 as complete" | Call `complete_task` with task_id 3 |
| "Delete the meeting task" | Call `list_tasks` first, then `delete_task` |
| "Change task 1 to 'Call mom tonight'" | Call `update_task` with new title |
| "I need to remember to pay bills" | Call `add_task` with title "Pay bills" |
| "What have I completed?" | Call `list_tasks` with status "completed" |

---

## Code Quality Standards

### Agent Code (Python)
```python
# GOOD: Clear agent definition with typed tools
from agents import Agent, Runner
from agents.extensions.models.litellm import LitellmModel

model = LitellmModel(model="gemini/gemini-2.5-flash", api_key=GEMINI_API_KEY)

# Define agent
agent = Agent(
    name="TodoBot",
    instructions="You are a helpful todo assistant...",
    model=model,
    tools=[add_task_tool, list_tasks_tool, complete_task_tool, delete_task_tool, update_task_tool]
)

# Run agent
async def chat(messages: list[dict]) -> str:
    runner = Runner(agent)
    result = await runner.run(messages=messages)
    return result.content
```

### MCP Server Code (Python)
```python
# GOOD: Clean MCP tool definition with Official SDK
from mcp.server import Server
from mcp.types import Tool, TextContent
from sqlmodel import Session, select

mcp = Server("todo-mcp-server")

@mcp.tool()
async def add_task(user_id: str, title: str, description: str = "") -> list[TextContent]:
    """Create a new task for the user."""
    async with get_session() as session:
        task = Task(user_id=user_id, title=title, description=description)
        session.add(task)
        await session.commit()
        await session.refresh(task)
        return [TextContent(type="text", text=f"Created task #{task.id}: {task.title}")]
```

### ChatKit Frontend (TypeScript)
```typescript
// GOOD: Chat interface with proper state management
'use client';

import { useState } from 'react';

export function ChatInterface() {
  const [messages, setMessages] = useState<Message[]>([]);
  const [isLoading, setIsLoading] = useState(false);

  const handleSendMessage = async (content: string) => {
    setIsLoading(true);
    setMessages(prev => [...prev, { role: 'user', content }]);

    const response = await fetch('/api/chat', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${getAuthToken()}`
      },
      body: JSON.stringify({ message: content })
    });

    const data = await response.json();
    setMessages(prev => [...prev, { role: 'assistant', content: data.response }]);
    setIsLoading(false);
  };

  return (
    <div className="flex flex-col h-full">
      {/* Message list */}
      <div className="flex-1 overflow-y-auto">
        {messages.map((msg, i) => (
          <MessageBubble key={i} message={msg} />
        ))}
      </div>

      {/* Input area */}
      <ChatInput onSend={handleSendMessage} disabled={isLoading} />
    </div>
  );
}
```

---

## Environment Variables (Phase 3 Additions)

```env
# AI/Agent Configuration
GEMINI_API_KEY=your_gemini_api_key
GEMINI_MODEL=gemini-2.5-flash

# MCP Server (if running separately)
MCP_SERVER_URL=http://localhost:8001

# ChatKit (Frontend - for production deployment)
NEXT_PUBLIC_OPENAI_DOMAIN_KEY=your-domain-key-here

# Existing Phase 2 variables remain unchanged
DATABASE_URL=postgresql+asyncpg://...
BETTER_AUTH_SECRET=...
CORS_ORIGINS=http://localhost:3000
```

---

## Conversation Flow (Stateless Request Cycle)

1. **Receive user message** - Chat endpoint receives POST request
2. **Validate authentication** - Verify JWT token and user_id
3. **Fetch conversation history** - Load messages from database
4. **Build message array** - Combine history + new user message
5. **Store user message** - Persist to database
6. **Run agent** - Execute OpenAI Agents SDK with MCP tools
7. **Agent invokes tools** - MCP server executes task operations
8. **Store assistant response** - Persist to database
9. **Return response** - Send JSON response to client
10. **Server holds NO state** - Ready for next request

**Key Insight**: The database is the source of truth. The server is completely stateless.

---

## Security Checklist (Phase 3 Additions)

- [ ] Chat endpoints validate JWT tokens
- [ ] User can only access their own conversations
- [ ] MCP tools validate user_id ownership of tasks
- [ ] Message content length is limited (max 2000 chars)
- [ ] Rate limiting on chat endpoints (e.g., 10 requests/minute)
- [ ] Tool calls are logged for audit
- [ ] No sensitive data in agent responses
- [ ] Error messages don't expose internal details

---

## Testing Strategy

### Unit Tests
- Agent tool function wrappers
- MCP tool handlers
- Conversation service methods (create, fetch, store messages)

### Integration Tests
- Full chat flow (message → agent → tools → response)
- Conversation CRUD operations
- Tool execution with database operations

### E2E Tests
- User journey: login → chat → create task via chat → verify task in database
- Conversation history persistence
- Error handling scenarios (invalid task_id, unauthorized access)

**Test Coverage Goals**:
- Backend: 80%
- Frontend: 70%
- Critical paths (chat flow, tool execution): 100%

---

## Development Workflow (Spec-Driven)

### Step 1: Constitution (This Document)
Defines WHY and HOW for Phase 3.

### Step 2: Specification
Create detailed specs in `/specs/features/`:
- `specs/features/chat-interface.md` - Chat UI requirements
- `specs/features/mcp-tools.md` - MCP tool specifications
- `specs/features/conversation-management.md` - Conversation persistence

### Step 3: Plan
Design implementation approach:
- Database migration plan
- MCP server architecture
- Agent configuration
- Frontend integration strategy

### Step 4: Tasks
Break plan into actionable tasks:
- T-001: Create database migration for conversations and messages
- T-002: Implement MCP server with 5 tools
- T-003: Configure OpenAI Agents SDK with Gemini model
- T-004: Create chat endpoint in FastAPI
- T-005: Integrate ChatKit in Next.js frontend

### Step 5: Implement
Execute tasks following this constitution.

---

## Deliverables

1. **GitHub Repository**:
   - `/frontend` - ChatKit-based UI
   - `/backend` - FastAPI + Agents SDK + MCP
   - `/specs` - Specification files for agent and MCP tools
   - Database migration scripts
   - README with setup instructions
   - CLAUDE.md updated with Phase 3 guidelines

2. **Working Chatbot**:
   - Manage tasks through natural language via MCP tools
   - Maintain conversation context via database (stateless server)
   - Provide helpful responses with action confirmations
   - Handle errors gracefully
   - Resume conversations after server restart

3. **Deployment**:
   - Frontend deployed to Vercel
   - Backend deployed (or local for demo)
   - Database migrations applied to Neon
   - ChatKit domain allowlist configured (if using hosted ChatKit)

---

## Governance

### Constitution Authority
- This constitution supersedes all other practices for Phase 3
- Phase 2 constitution remains valid for non-chat features (task CRUD, auth)
- All code reviews must verify compliance with this constitution
- Violations must be justified and documented

### Change Management
- Constitution changes require new version number
- Document rationale for all amendments
- Update CLAUDE.md to reflect changes
- Notify all team members of constitution updates

### Conflict Resolution
If conflicts arise between Phase 2 and Phase 3 constitutions:
1. Phase 3 constitution takes precedence for chat-related features
2. Phase 2 constitution governs task CRUD and authentication
3. Consult CLAUDE.md hierarchy for clarification

---

## References

- [Hackathon II Documentation](./Hackathon%20II%20-%20Todo%20Spec-Driven%20Development%20(1).md)
- [OpenAI Agents SDK Documentation](https://openai.github.io/openai-agents-python/)
- [Official MCP SDK Documentation](https://github.com/modelcontextprotocol/python-sdk)
- [OpenAI ChatKit Documentation](https://platform.openai.com/docs/guides/chatkit)
- [LiteLLM Documentation](https://docs.litellm.ai/)
- [SQLModel Documentation](https://sqlmodel.tiangolo.com/)
- [FastAPI Documentation](https://fastapi.tiangolo.com/)

---

## Appendix: Example Agent Instructions

```python
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

---

---

## Implementation Notes (Critical)

### 1. OpenAI Agents SDK with LiteLLM Extension
**CORRECT APPROACH**: Use direct LiteLLM extension integration (no proxy server)

```python
from agents import Agent, Runner
from agents.extensions.models.litellm import LitellmModel

# Direct integration - simplified deployment
model = LitellmModel(
    model="gemini/gemini-2.0-flash-exp",  # Note: Use gemini/ prefix
    api_key=GEMINI_API_KEY,
    temperature=0.7,
    max_tokens=2000
)

agent = Agent(
    name="TodoBot",
    instructions="You are a helpful task management assistant...",
    model=model,
    tools=[]  # Populated from MCP tool schemas
)
```

**INCORRECT APPROACH**: ❌ Do not use LiteLLM proxy server
```python
# ❌ AVOID THIS - Adds unnecessary complexity
litellm --config litellm_config.yaml --port 4000
client = OpenAI(base_url="http://localhost:4000")
```

**Benefits of Direct Integration**:
- ✅ No separate proxy server to manage
- ✅ Simplified deployment (one less service)
- ✅ Reduced latency (no intermediate hop)
- ✅ Native Agents SDK features

### 2. OpenAI Official ChatKit with Domain Allowlist
**CORRECT PACKAGE**: `openai-chatkit` (or `@openai/chatkit`)

```bash
npm install openai-chatkit
```

```typescript
import { Chat, ChatInput, ChatMessage } from 'openai-chatkit';

<Chat domainKey={process.env.NEXT_PUBLIC_OPENAI_DOMAIN_KEY}>
  <ChatMessage role={msg.role} content={msg.content} />
  <ChatInput onSend={sendMessage} />
</Chat>
```

**INCORRECT PACKAGE**: ❌ Do not use third-party alternatives
```bash
# ❌ AVOID - Not OpenAI's official ChatKit
npm install @chatscope/chat-ui-kit-react
```

**Domain Allowlist Setup (REQUIRED for Production)**:
1. Deploy frontend to Vercel to get URL
2. Add domain to: https://platform.openai.com/settings/organization/security/domain-allowlist
3. Copy domain key from OpenAI dashboard
4. Set environment variable: `NEXT_PUBLIC_OPENAI_DOMAIN_KEY`
5. Redeploy with environment variable

**Note**: `localhost` works without domain configuration for development.

**Fallback Strategy**: Provide custom Tailwind-based chat UI if ChatKit is unavailable.

### 3. Official MCP SDK (NOT FastMCP)
**CORRECT SDK**: Official MCP SDK from modelcontextprotocol

```python
from mcp.server import Server
from mcp.types import Tool, TextContent

mcp_server = Server("todo-mcp-server")

@mcp_server.tool()
async def add_task(user_id: str, title: str, description: str = "") -> list[TextContent]:
    """Create a new task for the user."""
    # Implementation
    return [TextContent(
        type="text",
        text=f"✓ Created task #{task.id}: {task.title}"
    )]
```

**INCORRECT SDK**: ❌ Do not use FastMCP
```python
# ❌ AVOID - Not official, not standards-compliant
from fastmcp import FastMCP
mcp = FastMCP("Task Management Tools")
```

**Critical Differences**:
| Aspect | Official MCP SDK ✅ | FastMCP ❌ |
|--------|-------------------|------------|
| Import | `from mcp.server import Server` | `from fastmcp import FastMCP` |
| Return Type | `list[TextContent]` | `dict` or `list[dict]` |
| Standards | MCP Specification | Custom |
| Type Safety | Full typing | Limited |

**Why Official SDK**:
- ✅ Standards-compliant (follows MCP spec)
- ✅ Type-safe with TextContent
- ✅ Future-proof (official updates)
- ✅ Interoperable with any MCP client
- ✅ Community support

---

## Package Installation Summary

### Backend Dependencies
```bash
cd backend
pip install agents          # OpenAI Agents SDK
pip install litellm         # LiteLLM extension for Gemini
pip install mcp             # Official MCP SDK
pip install fastapi         # Web framework (existing)
pip install sqlmodel        # ORM (existing)
pip install python-dotenv   # Environment variables
```

### Frontend Dependencies
```bash
cd frontend
npm install openai-chatkit  # OpenAI's official ChatKit
# OR
npm install @openai/chatkit # Alternative package name
```

---

## Critical Configuration Checklist

### Backend (.env)
```env
# ✅ REQUIRED
GEMINI_API_KEY=your_gemini_api_key_here
GEMINI_MODEL=gemini-2.0-flash-exp
AGENT_TEMPERATURE=0.7
AGENT_MAX_TOKENS=2000

# Existing from Phase 2
DATABASE_URL=postgresql+asyncpg://...
BETTER_AUTH_SECRET=...
```

### Frontend (.env.local)
```env
# ✅ REQUIRED for production (not needed for localhost)
NEXT_PUBLIC_OPENAI_DOMAIN_KEY=your-domain-key-here

# API URL
NEXT_PUBLIC_API_URL=http://localhost:8000

# Optional: Feature flag for ChatKit fallback
NEXT_PUBLIC_USE_OPENAI_CHATKIT=true
```

---

## Architecture Flow (Updated with Correct Technologies)

```
┌─────────────────────────────────────────────────────────────┐
│                    Next.js Frontend                          │
│  ┌───────────────────────────────────────────────────┐      │
│  │         OpenAI ChatKit (openai-chatkit)            │      │
│  │  - Chat component with domain key                  │      │
│  │  - ChatInput for user messages                     │      │
│  │  - ChatMessage for display                         │      │
│  │  - SSE streaming via EventSource                   │      │
│  └───────────────────────────────────────────────────┘      │
└─────────────────────────┬───────────────────────────────────┘
                          │ POST /api/chat/stream
                          │ (with JWT token)
                          ▼
┌─────────────────────────────────────────────────────────────┐
│                    FastAPI Backend                           │
│  ┌───────────────────────────────────────────────────┐      │
│  │              Chat Endpoint (SSE)                   │      │
│  │  - JWT validation                                  │      │
│  │  - Fetch conversation history from DB              │      │
│  │  - Build message array                             │      │
│  │  - Store user message                              │      │
│  └───────────────────────┬───────────────────────────┘      │
│                          ▼                                   │
│  ┌───────────────────────────────────────────────────┐      │
│  │    OpenAI Agents SDK + LiteLLM Extension          │      │
│  │    from agents.extensions.models.litellm          │      │
│  │                                                    │      │
│  │  model = LitellmModel(                            │      │
│  │      model="gemini/gemini-2.0-flash-exp",         │      │
│  │      api_key=GEMINI_API_KEY                       │      │
│  │  )                                                 │      │
│  │                                                    │      │
│  │  agent = Agent(name="TodoBot", model=model, ...)  │      │
│  │  runner = Runner(agent)                           │      │
│  │  result = await runner.run(messages=messages)     │      │
│  └───────────────────────┬───────────────────────────┘      │
│                          ▼                                   │
│  ┌───────────────────────────────────────────────────┐      │
│  │       Official MCP Server (mcp.server)            │      │
│  │                                                    │      │
│  │  from mcp.server import Server                    │      │
│  │  from mcp.types import TextContent                │      │
│  │                                                    │      │
│  │  @mcp_server.tool()                               │      │
│  │  async def add_task(...) -> list[TextContent]:    │      │
│  │      return [TextContent(type="text", text="...")] │      │
│  └───────────────────────┬───────────────────────────┘      │
└─────────────────────────┼───────────────────────────────────┘
                          ▼
┌─────────────────────────────────────────────────────────────┐
│              Neon PostgreSQL Database                        │
│  - tasks (Phase 2)                                           │
│  - conversations (Phase 3)                                   │
│  - messages (Phase 3)                                        │
└─────────────────────────────────────────────────────────────┘
```

---

## What NOT to Use (Common Mistakes)

### ❌ Incorrect Packages
```bash
# ❌ DO NOT USE
pip install openai-agents-sdk  # Wrong package name
pip install fastmcp            # Not official MCP SDK
npm install @chatscope/chat-ui-kit-react  # Not OpenAI ChatKit
```

### ❌ Incorrect Patterns
```python
# ❌ DO NOT USE - LiteLLM Proxy approach
litellm --config config.yaml --port 4000
client = OpenAI(base_url="http://localhost:4000")

# ❌ DO NOT USE - Wrong MCP SDK
from fastmcp import FastMCP
mcp = FastMCP("tools")

# ❌ DO NOT USE - Wrong return type
@mcp.tool()
async def add_task(...) -> dict:  # Should be list[TextContent]
    return {"task_id": 5, "status": "created"}
```

### ✅ Correct Packages
```bash
# ✅ USE THESE
pip install agents      # OpenAI Agents SDK
pip install litellm     # For LiteLLM extension
pip install mcp         # Official MCP SDK
npm install openai-chatkit  # OpenAI ChatKit
```

### ✅ Correct Patterns
```python
# ✅ USE THESE
from agents import Agent, Runner
from agents.extensions.models.litellm import LitellmModel
from mcp.server import Server
from mcp.types import TextContent

model = LitellmModel(model="gemini/...", api_key=KEY)
agent = Agent(name="TodoBot", model=model, tools=[])

@mcp_server.tool()
async def add_task(...) -> list[TextContent]:
    return [TextContent(type="text", text="Success")]
```

---

## Quick Reference: Critical Imports

### Backend (Python)
```python
# OpenAI Agents SDK
from agents import Agent, Runner
from agents.extensions.models.litellm import LitellmModel

# Official MCP SDK
from mcp.server import Server
from mcp.types import Tool, TextContent, ImageContent, EmbeddedResource

# Database & API (existing from Phase 2)
from sqlmodel import SQLModel, Field, Session, select
from fastapi import FastAPI, APIRouter, Depends, HTTPException
from fastapi.responses import StreamingResponse
```

### Frontend (TypeScript)
```typescript
// OpenAI ChatKit
import { Chat, ChatInput, ChatMessage } from 'openai-chatkit';

// React & Next.js (existing)
import { useState, useCallback } from 'react';
import { useRouter } from 'next/navigation';
```

---

**Version**: 1.1.0 | **Ratified**: 2025-12-31 | **Last Amended**: 2025-12-31 | **Amendment**: Added implementation notes for correct technology usage
