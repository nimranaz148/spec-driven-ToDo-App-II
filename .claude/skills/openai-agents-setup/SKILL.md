# OpenAI Agents Setup with Gemini Integration

## Overview
This skill sets up the OpenAI Agents SDK with Google's Gemini model via the LiteLLM extension (agents.extensions.models.litellm). It enables AI-powered conversational agents that can reason about tasks and invoke MCP tools for task management.

## When to Use This Skill
- Use when adding AI conversational capabilities to the Todo app
- Use when integrating Gemini model for task reasoning
- Use when building agents that can invoke MCP tools
- Use when implementing streaming AI responses

## Prerequisites
- Python 3.11+ installed
- FastAPI backend running
- Google AI Studio API key (for Gemini access)
- Official MCP server set up with task tools

## Setup Steps

### 1. Install Dependencies
```bash
cd backend
pip install agents litellm python-dotenv
```

**Note**: The package is `agents` (OpenAI Agents SDK), not `openai-agents-sdk`.

### 2. Configure Environment Variables
Add to `backend/.env`:
```env
# Gemini API Key
GEMINI_API_KEY=your_gemini_api_key_here

# Agent Configuration
AGENT_MODEL=gemini-2.0-flash-exp
AGENT_TEMPERATURE=0.7
AGENT_MAX_TOKENS=2000
```

### 3. Create Agent Configuration
Create `backend/agent_config.py`:
```python
import os
from dotenv import load_dotenv

load_dotenv()

AGENT_CONFIG = {
    "model": os.getenv("AGENT_MODEL", "gemini-2.0-flash-exp"),
    "temperature": float(os.getenv("AGENT_TEMPERATURE", "0.7")),
    "max_tokens": int(os.getenv("AGENT_MAX_TOKENS", "2000")),
    "system_prompt": """You are a helpful task management assistant.
You can help users manage their tasks by creating, listing, updating,
and completing tasks. Always be concise and helpful."""
}

GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")
```

### 4. Create Agent Instance with LiteLLM Extension
Create `backend/agent.py`:
```python
from agents import Agent, Runner
from agents.extensions.models.litellm import LitellmModel
from agent_config import AGENT_CONFIG, GEMINI_API_KEY
import os

# Create LiteLLM model instance for Gemini
model = LitellmModel(
    model=f"gemini/{AGENT_CONFIG['model']}",  # Format: gemini/gemini-2.0-flash-exp
    api_key=GEMINI_API_KEY,
    temperature=AGENT_CONFIG["temperature"],
    max_tokens=AGENT_CONFIG["max_tokens"]
)

# Create agent with LiteLLM model
agent = Agent(
    name="TodoBot",
    instructions=AGENT_CONFIG["system_prompt"],
    model=model,
    tools=[]  # Will be populated with MCP tools later
)

async def create_agent_response(
    messages: list[dict],
    tools: list = None
) -> str:
    """
    Create agent response using OpenAI Agents SDK.

    Args:
        messages: Conversation history
        tools: MCP tools available to agent

    Returns:
        Agent's response content
    """
    # Update agent tools if provided
    if tools:
        agent.tools = tools

    # Run agent with messages
    runner = Runner(agent)
    result = await runner.run(messages=messages)

    return result.content
```

### 5. Create Streaming Endpoint
Add to `backend/routes/chat.py`:
```python
from fastapi import APIRouter, Depends
from fastapi.responses import StreamingResponse
from agent import create_agent_response, agent, Runner
from auth import get_current_user
from mcp_server import get_agent_tools

router = APIRouter()

@router.post("/chat/stream")
async def chat_stream(
    message: str,
    user_id: str = Depends(get_current_user)
):
    """Stream agent responses via SSE"""
    # Build message history
    messages = [{"role": "user", "content": message}]

    # Get MCP tools
    tools = await get_agent_tools(user_id)
    agent.tools = tools

    async def generate():
        try:
            # Run agent
            runner = Runner(agent)
            result = await runner.run(messages=messages)

            # Stream response
            # Note: OpenAI Agents SDK doesn't directly support streaming
            # For streaming, yield the full response or implement chunking
            content = result.content

            # Chunk the response for streaming effect
            chunk_size = 10
            for i in range(0, len(content), chunk_size):
                chunk = content[i:i+chunk_size]
                yield f"data: {chunk}\n\n"

            yield "data: [DONE]\n\n"

        except Exception as e:
            yield f"data: Error: {str(e)}\n\n"
            yield "data: [DONE]\n\n"

    return StreamingResponse(
        generate(),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "Connection": "keep-alive"
        }
    )

@router.post("/chat")
async def chat(
    message: str,
    user_id: str = Depends(get_current_user)
):
    """Non-streaming chat endpoint"""
    messages = [{"role": "user", "content": message}]

    # Get MCP tools
    tools = await get_agent_tools(user_id)

    # Get agent response
    response = await create_agent_response(messages, tools)

    return {
        "response": response,
        "user_id": user_id
    }
```

### 6. Integrate MCP Tools
Create `backend/mcp_integration.py`:
```python
from mcp_server import (
    add_task,
    list_tasks,
    complete_task,
    delete_task,
    update_task
)

async def get_agent_tools(user_id: str) -> list:
    """
    Convert MCP tools to OpenAI Agents SDK tool format.

    Args:
        user_id: Authenticated user ID to inject into tools

    Returns:
        List of tool definitions for the agent
    """
    tools = [
        {
            "type": "function",
            "function": {
                "name": "add_task",
                "description": "Create a new task for the user",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "title": {
                            "type": "string",
                            "description": "Task title (required)"
                        },
                        "description": {
                            "type": "string",
                            "description": "Task description (optional)"
                        }
                    },
                    "required": ["title"]
                }
            }
        },
        {
            "type": "function",
            "function": {
                "name": "list_tasks",
                "description": "Retrieve tasks from the list",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "status": {
                            "type": "string",
                            "enum": ["all", "pending", "completed"],
                            "description": "Filter by status"
                        }
                    }
                }
            }
        },
        {
            "type": "function",
            "function": {
                "name": "complete_task",
                "description": "Mark a task as complete",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "task_id": {
                            "type": "integer",
                            "description": "Task ID to complete"
                        }
                    },
                    "required": ["task_id"]
                }
            }
        },
        {
            "type": "function",
            "function": {
                "name": "delete_task",
                "description": "Remove a task from the list",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "task_id": {
                            "type": "integer",
                            "description": "Task ID to delete"
                        }
                    },
                    "required": ["task_id"]
                }
            }
        },
        {
            "type": "function",
            "function": {
                "name": "update_task",
                "description": "Modify task title or description",
                "parameters": {
                    "type": "object",
                    "properties": {
                        "task_id": {
                            "type": "integer",
                            "description": "Task ID to update"
                        },
                        "title": {
                            "type": "string",
                            "description": "New task title (optional)"
                        },
                        "description": {
                            "type": "string",
                            "description": "New task description (optional)"
                        }
                    },
                    "required": ["task_id"]
                }
            }
        }
    ]

    return tools
```

## Key Files Created

| File | Purpose |
|------|---------|
| backend/agent_config.py | Agent configuration and settings |
| backend/agent.py | Agent instance with LiteLLM model |
| backend/routes/chat.py | Chat streaming and non-streaming endpoints |
| backend/mcp_integration.py | MCP tools integration with agent |
| backend/.env | Environment variables for API keys |

## Dependencies

| Dependency | Version | Purpose |
|------------|---------|---------|
| agents | ^0.1.0 | OpenAI Agents SDK framework |
| litellm | ^1.0.0 | LiteLLM extension for Gemini |
| python-dotenv | ^1.0.0 | Environment variable management |

## Validation
Run: `.claude/skills/openai-agents-setup/validation.sh`

Expected output:
```
✓ OpenAI Agents SDK (agents) installed
✓ LiteLLM installed
✓ GEMINI_API_KEY configured
✓ Agent config file exists
✓ Agent with LiteLLM model initializes correctly
✓ Agent responds to test query
```

## Troubleshooting

### Issue: "agents" package not found
**Solution**: Ensure you install the correct package:
```bash
pip install agents  # NOT openai-agents-sdk
```

### Issue: Gemini API authentication error
**Solution**: Verify GEMINI_API_KEY is set correctly in .env:
```bash
echo $GEMINI_API_KEY
```

### Issue: LitellmModel import error
**Solution**: Ensure litellm is installed and you're using the correct import:
```python
from agents.extensions.models.litellm import LitellmModel
```

### Issue: Agent not calling MCP tools
**Solution**: Ensure tools are properly formatted in OpenAI function calling schema and passed to agent:
```python
agent.tools = tools  # Set tools before running
```

### Issue: Model name format error
**Solution**: Use the correct format for Gemini models:
```python
model = LitellmModel(
    model="gemini/gemini-2.0-flash-exp",  # Must include "gemini/" prefix
    api_key=GEMINI_API_KEY
)
```

## Integration with MCP Tools
Complete integration example:

```python
from agents import Agent, Runner
from agents.extensions.models.litellm import LitellmModel
from mcp_server import add_task, list_tasks, complete_task, delete_task, update_task

# Initialize model
model = LitellmModel(
    model="gemini/gemini-2.0-flash-exp",
    api_key=GEMINI_API_KEY
)

# Create agent
agent = Agent(
    name="TodoBot",
    instructions="You are a helpful task management assistant...",
    model=model,
    tools=[]
)

# Get MCP tools in agent format
tools = await get_agent_tools(user_id)
agent.tools = tools

# Run agent
messages = [{"role": "user", "content": "Add a task to buy groceries"}]
runner = Runner(agent)
result = await runner.run(messages=messages)

print(result.content)  # Agent's response after calling add_task
```

## Architecture Benefits

### Using agents.extensions.models.litellm
✅ **Direct Integration**: No separate LiteLLM proxy server needed
✅ **Simplified Deployment**: One less service to manage
✅ **Native Agent Support**: Full OpenAI Agents SDK features
✅ **Model Flexibility**: Easy to switch between Gemini versions
✅ **Type Safety**: Proper Python typing and IDE support

### vs. LiteLLM Proxy Approach
❌ Requires separate proxy server
❌ Additional network hop (latency)
❌ More complex deployment
❌ Extra configuration file

## Next Steps
After completing this skill:
1. Set up Official MCP server with task tools (mcp-server-setup skill)
2. Integrate MCP tools with agent using get_agent_tools()
3. Build ChatKit frontend for chat UI (chatkit-frontend skill)
4. Implement conversation persistence (chatkit-backend skill)
5. Test end-to-end chat flow with tool calling
