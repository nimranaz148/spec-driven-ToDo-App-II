# Feature Specification: Todo AI Chatbot - Phase 3

**Project**: Todo AI Chatbot Application
**Phase**: Phase 3 - AI-Powered Todo Chatbot
**Feature Branch**: `phase3/ai-chatbot`
**Created**: 2025-12-31
**Status**: Active
**Priority**: P1 (Critical - Foundation for AI capabilities)
**Builds Upon**: Phase 2 - Full-Stack Web Application

---

## Executive Summary

Transform the Phase 2 web application into an AI-powered chatbot interface that allows users to manage their todos through natural language conversation. This phase introduces the conversational AI layer using **OpenAI Agents SDK**, **Official MCP SDK**, and **OpenAI ChatKit**.

**Key Deliverables**:
- AI Agent using OpenAI Agents SDK with Gemini model (via LiteLLM)
- MCP Server using Official MCP SDK exposing task operations as tools
- ChatKit-based conversational interface (with custom fallback)
- Stateless chat endpoint with conversation persistence
- Database extensions (conversations, messages)
- Comprehensive natural language command support

**Architecture Philosophy**: Stateless servers, persistent state in database, MCP-first tool design, conversational interface.

---

## Problem Statement

### Current State (Phase 2)
Users interact with tasks through traditional web forms:
- Click "Add Task" button
- Fill out form fields
- Submit form
- View tasks in table/list

**Limitations**:
- Requires multiple clicks and form interactions
- Not intuitive for quick task management
- No conversational context
- Limited accessibility

### Desired State (Phase 3)
Users interact with tasks through natural language:
- Type: "Add a task to buy groceries"
- System: "I've added 'Buy groceries' to your list (Task #5)"
- Type: "What's pending?"
- System: Shows pending tasks in conversational format

**Benefits**:
- Natural language interaction
- Faster task management
- Conversational context maintained
- More accessible (can be extended to voice in future)

---

## User Stories

### US-001: Chat with Todo Assistant
**As a** logged-in user
**I want to** interact with an AI chatbot to manage my tasks
**So that** I can use natural language instead of forms

**Acceptance Criteria**:
- ✅ Given I'm on the chat page
- ✅ When I type a message and press send
- ✅ Then the AI responds within 3 seconds
- ✅ And my message and the response are saved to conversation history

**Technical Notes**:
- Use OpenAI ChatKit for UI
- POST to `/api/{user_id}/chat` endpoint
- Store messages in database

---

### US-002: Add Tasks via Natural Language
**As a** user
**I want to** create tasks by typing natural language commands
**So that** I don't have to fill out forms

**Acceptance Criteria**:
- ✅ Given I type "Add a task to buy groceries"
- ✅ When the AI processes the message
- ✅ Then a new task "Buy groceries" is created
- ✅ And I receive confirmation with the task ID

**Examples**:
| User Input | Expected Behavior |
|------------|-------------------|
| "Add a task to buy groceries" | Creates task "Buy groceries" |
| "Remind me to call mom" | Creates task "Call mom" |
| "I need to buy milk, eggs, and bread" | Creates task "Buy milk, eggs, and bread" |

**Technical Notes**:
- Agent calls MCP `add_task` tool
- MCP tool creates Task in database
- Returns structured response to agent

---

### US-003: View Tasks via Natural Language
**As a** user
**I want to** see my tasks by asking the chatbot
**So that** I can quickly check what I need to do

**Acceptance Criteria**:
- ✅ Given I type "Show me all my tasks"
- ✅ When the AI processes the message
- ✅ Then I see a formatted list of all my tasks
- ✅ And tasks are grouped by completion status

**Examples**:
| User Input | Expected Behavior |
|------------|-------------------|
| "Show me all my tasks" | Lists all tasks |
| "What's pending?" | Lists only pending tasks |
| "What have I completed?" | Lists only completed tasks |

**Technical Notes**:
- Agent calls MCP `list_tasks` tool with status filter
- MCP tool queries database with user_id filter
- Agent formats response conversationally

---

### US-004: Complete Tasks via Natural Language
**As a** user
**I want to** mark tasks complete by telling the chatbot
**So that** I can update task status quickly

**Acceptance Criteria**:
- ✅ Given I have a task with ID 3
- ✅ When I type "Mark task 3 as complete"
- ✅ Then task 3 is marked as complete
- ✅ And I receive confirmation

**Examples**:
| User Input | Expected Behavior |
|------------|-------------------|
| "Mark task 3 as complete" | Marks task 3 complete |
| "I finished task 5" | Marks task 5 complete |
| "Task 2 is done" | Marks task 2 complete |

**Technical Notes**:
- Agent calls MCP `complete_task` tool with task_id
- MCP tool updates Task.completed = true
- Returns confirmation with task title

---

### US-005: Delete Tasks via Natural Language
**As a** user
**I want to** delete tasks by telling the chatbot
**So that** I can remove unwanted tasks quickly

**Acceptance Criteria**:
- ✅ Given I have a task with ID 7
- ✅ When I type "Delete task 7"
- ✅ Then task 7 is removed from the database
- ✅ And I receive confirmation

**Examples**:
| User Input | Expected Behavior |
|------------|-------------------|
| "Delete task 7" | Deletes task 7 |
| "Remove the meeting task" | Lists tasks, then deletes matching task |
| "Cancel task 3" | Deletes task 3 |

**Technical Notes**:
- Agent calls MCP `delete_task` tool with task_id
- For vague requests ("the meeting task"), agent first calls `list_tasks` to find task_id
- MCP tool deletes from database

---

### US-006: Update Tasks via Natural Language
**As a** user
**I want to** update task details by telling the chatbot
**So that** I can modify tasks without forms

**Acceptance Criteria**:
- ✅ Given I have a task with ID 1
- ✅ When I type "Change task 1 to 'Call mom tonight'"
- ✅ Then task 1's title is updated
- ✅ And I receive confirmation

**Examples**:
| User Input | Expected Behavior |
|------------|-------------------|
| "Change task 1 to 'Call mom tonight'" | Updates task 1 title |
| "Update task 5 description to include phone number" | Updates task 5 description |
| "Rename task 3 to 'Team meeting'" | Updates task 3 title |

**Technical Notes**:
- Agent calls MCP `update_task` tool with task_id and new values
- MCP tool updates Task in database
- Returns confirmation with updated title

---

### US-007: Maintain Conversation History
**As a** user
**I want to** see my previous chat messages
**So that** I have context for my conversations

**Acceptance Criteria**:
- ✅ Given I have an existing conversation
- ✅ When I navigate away and return to the chat
- ✅ Then I see my previous messages
- ✅ And I can continue the conversation

**Technical Notes**:
- Conversations stored in `conversations` table
- Messages stored in `messages` table
- Chat endpoint loads history before running agent

---

## Functional Requirements

### FR-001: Chat Endpoint (Stateless)
**Description**: FastAPI endpoint that receives user messages, runs AI agent with MCP tools, and returns responses.

**Specifications**:
- **Method**: POST
- **Path**: `/api/{user_id}/chat`
- **Authentication**: JWT token required
- **Validation**: user_id in URL must match JWT token

**Request Body**:
```json
{
  "conversation_id": 123,  // optional - creates new if not provided
  "message": "Add a task to buy groceries"
}
```

**Response Body**:
```json
{
  "conversation_id": 123,
  "response": "I've added 'Buy groceries' to your list (Task #5)",
  "tool_calls": [
    {
      "tool": "add_task",
      "parameters": {
        "user_id": "user123",
        "title": "Buy groceries"
      },
      "result": {
        "task_id": 5,
        "status": "created",
        "title": "Buy groceries"
      }
    }
  ]
}
```

**Processing Flow**:
1. Validate JWT token and user_id
2. Fetch or create conversation
3. Load conversation history from database
4. Build message array (history + new user message)
5. Store user message in database
6. Run OpenAI Agent with MCP tools
7. Agent invokes appropriate MCP tools
8. Store assistant response in database
9. Return response to client
10. Server holds NO state (ready for next request)

**Error Handling**:
- 401: Invalid JWT token
- 403: user_id mismatch
- 400: Invalid message format
- 500: Agent execution error

---

### FR-002: MCP Server with Official SDK
**Description**: MCP server exposing task operations as tools using the Official MCP SDK.

**Implementation**:
```python
from mcp.server import Server
from mcp.types import Tool, TextContent
from sqlmodel import select

mcp = Server("todo-mcp-server")

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

**Required MCP Tools**:

#### Tool 1: add_task
- **Parameters**: user_id (str), title (str), description (str, optional)
- **Returns**: {task_id, status, title}
- **Example Input**: `{"user_id": "user123", "title": "Buy groceries", "description": "Milk, eggs, bread"}`
- **Example Output**: `{"task_id": 5, "status": "created", "title": "Buy groceries"}`

#### Tool 2: list_tasks
- **Parameters**: user_id (str), status (str, optional: "all", "pending", "completed")
- **Returns**: Array of task objects
- **Example Input**: `{"user_id": "user123", "status": "pending"}`
- **Example Output**: `[{"id": 1, "title": "Buy groceries", "completed": false}, ...]`

#### Tool 3: complete_task
- **Parameters**: user_id (str), task_id (int)
- **Returns**: {task_id, status, title}
- **Example Input**: `{"user_id": "user123", "task_id": 3}`
- **Example Output**: `{"task_id": 3, "status": "completed", "title": "Call mom"}`

#### Tool 4: delete_task
- **Parameters**: user_id (str), task_id (int)
- **Returns**: {task_id, status, title}
- **Example Input**: `{"user_id": "user123", "task_id": 2}`
- **Example Output**: `{"task_id": 2, "status": "deleted", "title": "Old task"}`

#### Tool 5: update_task
- **Parameters**: user_id (str), task_id (int), title (str, optional), description (str, optional)
- **Returns**: {task_id, status, title}
- **Example Input**: `{"user_id": "user123", "task_id": 1, "title": "Buy groceries and fruits"}`
- **Example Output**: `{"task_id": 1, "status": "updated", "title": "Buy groceries and fruits"}`

**Tool Design Principles**:
- All tools validate user_id ownership
- All tools handle database errors gracefully
- All tools return structured, parseable responses
- Never expose raw SQL errors to agent

---

### FR-003: OpenAI Agents SDK Integration
**Description**: Configure OpenAI Agent with Gemini model via LiteLLM to orchestrate tool calls.

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
- Add a task: Use add_task tool with extracted title and description
- See tasks: Use list_tasks tool (filter by status if user specifies)
- Complete a task: Use complete_task tool with task_id
- Delete a task: Use delete_task tool with task_id (list first if vague)
- Update a task: Use update_task tool with task_id and new values

Guidelines:
1. Be conversational and friendly
2. Always confirm actions (e.g., "I've created task #5: Buy groceries")
3. When users are vague, ask clarifying questions
4. If user mentions task by name (not ID), list tasks first to find ID
5. Gracefully handle errors (e.g., "I couldn't find task #99")
6. Keep responses concise but helpful

Examples:
- User: "Add a task to buy groceries"
  Response: Call add_task(title="Buy groceries"), then say "I've added 'Buy groceries' to your list!"

- User: "What do I need to do?"
  Response: Call list_tasks(status="pending"), then format and display tasks

- User: "I finished task 3"
  Response: Call complete_task(task_id=3), then say "Great job! I've marked task #3 as complete."
""",
    model=model,
    tools=[add_task_tool, list_tasks_tool, complete_task_tool, delete_task_tool, update_task_tool]
)

# Agent execution
async def run_agent(messages: list[dict]) -> str:
    runner = Runner(agent)
    result = await runner.run(messages=messages)
    return result.content
```

**Agent Behavior Specification**:
| User Intent | Tool to Call | Example Phrase |
|-------------|--------------|----------------|
| **Task Creation** | `add_task` | "Add a task to buy groceries", "Remind me to call mom" |
| **Task Listing** | `list_tasks` | "Show me all my tasks", "What's pending?", "What have I completed?" |
| **Task Completion** | `complete_task` | "Mark task 3 as complete", "I finished that", "Task 2 is done" |
| **Task Deletion** | `delete_task` | "Delete task 7", "Remove the meeting task", "Cancel task 3" |
| **Task Update** | `update_task` | "Change task 1 to 'Call mom tonight'", "Update task 5 description" |
| **Confirmation** | N/A | Always confirm actions with friendly response |
| **Error Handling** | N/A | Gracefully handle task not found and other errors |

**Natural Language Command Support**:
| User Says | Agent Should Do |
|-----------|-----------------|
| "Add a task to buy groceries" | Call add_task with title "Buy groceries" |
| "Show me all my tasks" | Call list_tasks with status "all" |
| "What's pending?" | Call list_tasks with status "pending" |
| "Mark task 3 as complete" | Call complete_task with task_id 3 |
| "Delete the meeting task" | Call list_tasks first, then delete_task |
| "Change task 1 to 'Call mom tonight'" | Call update_task with new title |
| "I need to remember to pay bills" | Call add_task with title "Pay bills" |
| "What have I completed?" | Call list_tasks with status "completed" |

---

### FR-004: ChatKit Frontend
**Description**: Implement chat interface using OpenAI ChatKit (with custom fallback strategy).

**UI Strategy**: 90% ChatKit, 10% Custom Fallback
- **Primary**: Use OpenAI ChatKit components (if available and working)
- **Fallback**: If ChatKit doesn't work or has issues, implement custom chat UI with Tailwind CSS

**ChatKit Domain Allowlist Configuration**:
- **Local Development**: `localhost` works without domain allowlist configuration
- **Production Deployment**:
  1. Deploy frontend to get production URL (e.g., `https://your-app.vercel.app`)
  2. Add domain to OpenAI allowlist: https://platform.openai.com/settings/organization/security/domain-allowlist
  3. Click "Add domain" and enter frontend URL (without trailing slash)
  4. Get ChatKit domain key from OpenAI
  5. Set environment variable: `NEXT_PUBLIC_OPENAI_DOMAIN_KEY=your-domain-key-here`

**Environment Variable**:
```env
NEXT_PUBLIC_OPENAI_DOMAIN_KEY=your-domain-key-here
```

**Component Structure** (Custom Fallback):
```typescript
// app/chat/page.tsx
'use client';

import { useState, useEffect } from 'react';
import { MessageList } from '@/components/chat/MessageList';
import { MessageInput } from '@/components/chat/MessageInput';
import { api } from '@/lib/api';

interface Message {
  id: number;
  role: 'user' | 'assistant';
  content: string;
  created_at: string;
}

export default function ChatPage() {
  const [messages, setMessages] = useState<Message[]>([]);
  const [isLoading, setIsLoading] = useState(false);
  const [conversationId, setConversationId] = useState<number | null>(null);

  const handleSendMessage = async (content: string) => {
    setIsLoading(true);

    // Add user message optimistically
    const userMessage: Message = {
      id: Date.now(),
      role: 'user',
      content,
      created_at: new Date().toISOString()
    };
    setMessages(prev => [...prev, userMessage]);

    try {
      // Call backend
      const response = await api.sendChatMessage({
        conversation_id: conversationId,
        message: content
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
      // Show error message to user
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="flex flex-col h-screen">
      <div className="flex-1 overflow-y-auto p-4">
        <MessageList messages={messages} />
      </div>
      <div className="border-t p-4">
        <MessageInput onSend={handleSendMessage} disabled={isLoading} />
      </div>
    </div>
  );
}
```

**Rationale**: ChatKit provides production-ready chat UI with minimal setup. Custom fallback ensures project completion even if ChatKit has issues.

---

### FR-005: Database Schema Extensions
**Description**: Add conversations and messages tables to support chat history.

**New Tables**:

#### Conversations Table
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
```

#### Messages Table
```python
from sqlmodel import SQLModel, Field
from datetime import datetime

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

**Existing Table (unchanged)**:
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
- Create Alembic migration script
- Add new tables (conversations, messages)
- Do NOT modify existing tasks table
- Add indexes for performance (user_id, conversation_id)

---

## Non-Functional Requirements

### NFR-001: Performance
- First token response within 2 seconds
- Full response within 5 seconds for simple commands
- MCP tool execution within 500ms
- Database queries within 100ms

### NFR-002: Scalability
- Support 100 concurrent chat sessions
- Handle 1000 messages per conversation
- Support 10,000 total conversations in database

### NFR-003: Security
- JWT authentication on all chat endpoints
- User isolation (can't access other users' conversations)
- Input sanitization (prevent SQL injection, XSS)
- Rate limiting (30 messages per minute per user)
- Message content length limit (4000 characters)

### NFR-004: Reliability
- Stateless server design (horizontal scaling)
- Conversation persistence (survive server restarts)
- Graceful error handling (no 500 errors exposed)
- Database connection pooling

### NFR-005: Usability
- Conversational, friendly AI responses
- Clear error messages
- Loading indicators during processing
- Responsive mobile design

---

## System Architecture

### Architecture Diagram

```
┌───────────────────────────────────────────────────────────────────────┐
│                        Next.js Frontend (Port 3000)                    │
│  ┌─────────────────────────────────────────────────────────────┐      │
│  │              ChatKit UI / Custom Chat UI                     │      │
│  │  - Message display (user/assistant bubbles)                  │      │
│  │  - Input field with send button                              │      │
│  │  - Loading indicators                                        │      │
│  │  - Error handling                                            │      │
│  └─────────────────────────────────────────────────────────────┘      │
└───────────────────────────┬───────────────────────────────────────────┘
                            │ POST /api/{user_id}/chat
                            │ Authorization: Bearer <JWT>
                            ▼
┌───────────────────────────────────────────────────────────────────────┐
│                    FastAPI Backend (Port 8000)                         │
│  ┌─────────────────────────────────────────────────────────────┐      │
│  │  JWT Middleware (validate token, extract user_id)           │      │
│  │  Rate Limiting: 30 messages/minute per user                 │      │
│  └─────────────────────────────────────────────────────────────┘      │
│  ┌─────────────────────────────────────────────────────────────┐      │
│  │  Chat Router (/api/{user_id}/chat)                          │      │
│  │  - Fetch/create conversation from DB                        │      │
│  │  - Load message history                                     │      │
│  │  - Store user message                                       │      │
│  │  - Input validation (max 4000 chars)                        │      │
│  └─────────────────────────────────────────────────────────────┘      │
│  ┌─────────────────────────────────────────────────────────────┐      │
│  │  OpenAI Agents SDK (Agent + Runner)                         │      │
│  │  - Gemini model via LiteLLM                                 │      │
│  │  - System prompt defining todo assistant behavior           │      │
│  │  - Tool orchestration                                       │      │
│  └─────────────────────────────────────────────────────────────┘      │
│  ┌─────────────────────────────────────────────────────────────┐      │
│  │  MCP Client → Official MCP Server                           │      │
│  │  - Calls MCP tools via standard MCP protocol                │      │
│  │  - Receives structured responses                            │      │
│  └─────────────────────────────────────────────────────────────┘      │
└───────────────────────────┬───────────────────────────────────────────┘
                            │
┌───────────────────────────▼───────────────────────────────────────────┐
│                    MCP Server (Official SDK)                           │
│  - @mcp.tool() decorators for each task operation                     │
│  - add_task, list_tasks, complete_task, delete_task, update_task      │
│  - Direct SQLModel database operations                                │
│  - Returns structured TextContent responses                           │
└───────────────────────────┬───────────────────────────────────────────┘
                            │
                            ▼
┌───────────────────────────────────────────────────────────────────────┐
│                    Neon Serverless PostgreSQL                          │
│  - tasks (existing from Phase 2)                                       │
│  - conversations (new)                                                 │
│  - messages (new)                                                      │
│  - users, sessions (Better Auth - existing from Phase 2)               │
└───────────────────────────────────────────────────────────────────────┘
```

---

## Data Models

### Conversation Model (SQLModel)
```python
from sqlmodel import SQLModel, Field
from datetime import datetime

class Conversation(SQLModel, table=True):
    __tablename__ = "conversations"

    id: int | None = Field(default=None, primary_key=True)
    user_id: str = Field(index=True)
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)
```

### Message Model (SQLModel)
```python
from sqlmodel import SQLModel, Field
from datetime import datetime

class Message(SQLModel, table=True):
    __tablename__ = "messages"

    id: int | None = Field(default=None, primary_key=True)
    user_id: str = Field(index=True)
    conversation_id: int = Field(foreign_key="conversations.id")
    role: str = Field()  # "user" | "assistant"
    content: str = Field()
    created_at: datetime = Field(default_factory=datetime.utcnow)
```

### Task Model (Existing - No Changes)
```python
from sqlmodel import SQLModel, Field
from datetime import datetime

class Task(SQLModel, table=True):
    __tablename__ = "tasks"

    id: int | None = Field(default=None, primary_key=True)
    user_id: str = Field(index=True)
    title: str = Field()
    description: str = Field(default="")
    completed: bool = Field(default=False)
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)
```

---

## API Specifications

### Chat Endpoint

**POST /api/{user_id}/chat**

**Authentication**: Requires JWT token in `Authorization: Bearer <token>` header

**Request Body**:
```json
{
  "conversation_id": 123,  // optional, creates new if not provided
  "message": "Add a task to buy groceries"
}
```

**Response Body** (Success):
```json
{
  "conversation_id": 123,
  "response": "I've added 'Buy groceries' to your list (Task #5)",
  "tool_calls": [
    {
      "tool": "add_task",
      "parameters": {
        "user_id": "user123",
        "title": "Buy groceries"
      },
      "result": {
        "task_id": 5,
        "status": "created",
        "title": "Buy groceries"
      }
    }
  ]
}
```

**Error Responses**:
- **401 Unauthorized**: Invalid JWT token
- **403 Forbidden**: user_id mismatch
- **400 Bad Request**: Invalid message format or missing required fields
- **429 Too Many Requests**: Rate limit exceeded
- **500 Internal Server Error**: Agent execution error

---

## Technical Stack

### Frontend
- **Framework**: Next.js 16+ (App Router)
- **UI Library**: OpenAI ChatKit (with Tailwind CSS fallback)
- **State Management**: React hooks (useState, useEffect)
- **Styling**: Tailwind CSS
- **API Client**: Fetch API with JWT auth
- **Authentication**: Better Auth (existing from Phase 2)

### Backend
- **API Framework**: Python FastAPI
- **AI Framework**: OpenAI Agents SDK
- **MCP Server**: Official MCP SDK (Python)
- **ORM**: SQLModel
- **Database**: Neon Serverless PostgreSQL
- **Authentication**: JWT verification (existing from Phase 2)
- **AI Model**: Gemini 2.5 Flash (via LiteLLM)

### New Libraries
- **openai-agents**: OpenAI Agents SDK (Python)
- **mcp**: Official MCP SDK (Python)
- **litellm**: Multi-LLM support (for Gemini)

### Existing Libraries (Preserved from Phase 2)
- FastAPI, SQLModel, Better Auth (backend)
- Next.js, Axios, Tailwind CSS (frontend)

---

## Out of Scope (Future Phases)

These features are explicitly OUT OF SCOPE for Phase 3:

- ❌ Voice input/output (Bonus feature)
- ❌ Multi-language support (Bonus feature)
- ❌ Streaming responses (SSE) - simple request/response for Phase 3
- ❌ Conversation sidebar (single conversation for Phase 3)
- ❌ Message pagination (load full history for Phase 3)
- ❌ Docker containerization (Phase 4)
- ❌ Kubernetes deployment (Phase 4)
- ❌ Advanced features: recurring tasks, reminders (Phase 5)
- ❌ Kafka event streaming (Phase 5)
- ❌ Dapr integration (Phase 5)
- ❌ Real-time collaboration between users

---

## Dependencies

### External Services
- **Gemini API**: AI model provider (via Google AI Studio)
- **Neon**: PostgreSQL database (existing from Phase 2)
- **Vercel**: Hosting (existing from Phase 2)

### New Python Libraries
```bash
# Install with uv
uv pip install openai-agents litellm mcp
```

### New Node.js Libraries (if using ChatKit)
```bash
# Install with npm (verify exact package name from OpenAI docs)
npm install @openai/chatkit  # or equivalent package
```

### Phase 2 Dependencies (Preserved)
- FastAPI, SQLModel, Better Auth, Alembic (backend)
- Next.js, React, Tailwind CSS (frontend)

---

## Risks & Mitigation

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| Gemini API latency | High | Medium | Show loading indicators, set expectations |
| MCP integration complexity | High | Medium | Use Official MCP SDK, follow documentation |
| ChatKit unavailability | Medium | Medium | Implement custom fallback UI with Tailwind |
| Prompt injection attacks | High | Low | Sanitize inputs, validate outputs |
| Rate limiting from Gemini | Medium | Medium | Implement request queuing, backoff |
| Database connection issues | High | Low | Use connection pooling, retry logic |

---

## Success Criteria

### Measurable Outcomes

- **SC-001**: Users can create tasks via natural language with 90%+ success rate
- **SC-002**: Users can list, complete, delete, update tasks via chat
- **SC-003**: AI responds within 5 seconds for simple commands
- **SC-004**: Conversation history persists across page refreshes
- **SC-005**: Zero unauthorized access to other users' conversations
- **SC-006**: System handles 100 concurrent chat sessions
- **SC-007**: All MCP tools complete within 500ms
- **SC-008**: Mobile-responsive chat interface works on iOS and Android

---

## Acceptance Checklist

Before Phase 3 is considered complete, verify:

- [ ] All 7 user stories have passing acceptance tests
- [ ] AI agent correctly interprets task commands (90%+ accuracy)
- [ ] MCP server exposes all 5 task tools (add, list, complete, delete, update)
- [ ] Chat endpoint works with proper JWT authentication
- [ ] Conversation history saves and loads correctly
- [ ] ChatKit UI renders messages properly (or custom fallback works)
- [ ] User isolation enforced (can't see others' conversations)
- [ ] Error handling shows friendly messages (no raw errors)
- [ ] Mobile responsive chat interface
- [ ] Rate limiting prevents abuse
- [ ] Database migrations applied successfully
- [ ] Security checklist complete
- [ ] API documentation updated for chat endpoint
- [ ] README updated with Phase 3 setup instructions

---

## Testing Strategy

### Unit Tests
- Agent tool function wrappers
- MCP tool handlers (add_task, list_tasks, complete_task, delete_task, update_task)
- Conversation service methods (create, fetch, store messages)

### Integration Tests
- Full chat flow (message → agent → tools → response)
- Conversation CRUD operations
- Tool execution with database operations
- JWT authentication and authorization

### E2E Tests
- User journey: login → chat → create task via chat → verify task in database
- Conversation history persistence
- Error handling scenarios (invalid task_id, unauthorized access)
- Natural language command variations

**Test Coverage Goals**:
- Backend: 80%
- Frontend: 70%
- Critical paths (chat flow, tool execution): 100%

---

## Implementation Plan (High-Level)

1. **Database Setup** (T-001)
   - Create Alembic migration for conversations and messages tables
   - Apply migration to Neon database

2. **MCP Server Development** (T-002)
   - Implement MCP server using Official MCP SDK
   - Create 5 MCP tools (add_task, list_tasks, complete_task, delete_task, update_task)
   - Test tools with sample data

3. **OpenAI Agent Configuration** (T-003)
   - Set up OpenAI Agents SDK with Gemini model (via LiteLLM)
   - Define agent instructions and behavior
   - Connect agent to MCP tools
   - Test agent with sample conversations

4. **Chat Endpoint Development** (T-004)
   - Create FastAPI route for /api/{user_id}/chat
   - Implement conversation management (fetch/create)
   - Integrate OpenAI Agent
   - Add error handling and validation

5. **Frontend Implementation** (T-005)
   - Implement ChatKit UI (or custom fallback)
   - Create message display components
   - Add input field with send functionality
   - Connect to chat endpoint with JWT auth

6. **Testing & Refinement** (T-006)
   - Write unit tests for all components
   - Perform integration testing
   - Conduct E2E testing with real user flows
   - Fix bugs and refine prompts

7. **Documentation & Deployment** (T-007)
   - Update README with Phase 3 setup
   - Document API endpoints
   - Deploy to Vercel
   - Configure ChatKit domain allowlist (if using)

---

## References

- [Phase 3 Constitution](./constitution-prompt-phase-3.md)
- [Hackathon II Documentation](./Hackathon%20II%20-%20Todo%20Spec-Driven%20Development%20(1).md)
- [OpenAI Agents SDK Documentation](https://openai.github.io/openai-agents-python/)
- [Official MCP SDK Documentation](https://github.com/modelcontextprotocol/python-sdk)
- [OpenAI ChatKit Documentation](https://platform.openai.com/docs/guides/chatkit)
- [LiteLLM Documentation](https://docs.litellm.ai/)
- [Gemini API Documentation](https://ai.google.dev/docs)

---

**Status**: Ready for implementation
**Next Step**: Create implementation plan with detailed tasks
**Estimated Effort**: 15-20 hours
**Complexity**: High (AI integration, MCP server, stateless architecture)

---

**Version**: 1.0.0 | **Created**: 2025-12-31 | **Last Updated**: 2025-12-31
