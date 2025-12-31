# Official MCP SDK Server Setup with Task Tools

## Overview
This skill sets up an **Official MCP (Model Context Protocol) SDK server** with tool definitions for task operations. These tools enable AI agents to perform CRUD operations on tasks using the official Python MCP SDK from modelcontextprotocol.

## When to Use This Skill
- Use when creating MCP tools for AI agent integration using official SDK
- Use when exposing backend task operations as callable tools
- Use when building tool servers for OpenAI Agents SDK
- Use when implementing authenticated tool handlers with MCP standard

## Prerequisites
- Python 3.11+ installed
- FastAPI backend running
- SQLModel database models set up
- Better Auth JWT authentication configured
- OpenAI Agents SDK installed

## Setup Steps

### 1. Install Official MCP SDK
```bash
cd backend
pip install mcp
```

**Note**: This is the official Model Context Protocol SDK from `modelcontextprotocol/python-sdk`.

### 2. Create MCP Server Instance
Create `backend/mcp_server.py`:
```python
from mcp.server import Server
from mcp.types import Tool, TextContent, ImageContent, EmbeddedResource
from sqlmodel import Session, select
from models import Task
from db import get_session
from typing import Optional
import json

# Initialize MCP server with official SDK
mcp_server = Server("todo-mcp-server")

@mcp_server.tool()
async def add_task(
    user_id: str,
    title: str,
    description: str = ""
) -> list[TextContent]:
    """
    Create a new task for the authenticated user.

    Args:
        user_id: Authenticated user ID (required)
        title: Task title (required)
        description: Task description (optional)

    Returns:
        Success message with task details as TextContent
    """
    try:
        session = next(get_session())

        # Create new task
        task = Task(
            user_id=user_id,
            title=title,
            description=description,
            completed=False
        )

        session.add(task)
        session.commit()
        session.refresh(task)

        # Return as TextContent (MCP standard format)
        return [TextContent(
            type="text",
            text=f"✓ Created task #{task.id}: {task.title}"
        )]

    except Exception as e:
        return [TextContent(
            type="text",
            text=f"✗ Failed to create task: {str(e)}"
        )]

@mcp_server.tool()
async def list_tasks(
    user_id: str,
    status: str = "all"
) -> list[TextContent]:
    """
    Retrieve tasks for the authenticated user.

    Args:
        user_id: Authenticated user ID (required)
        status: Filter by status - "all", "pending", or "completed" (optional)

    Returns:
        List of tasks as TextContent
    """
    try:
        session = next(get_session())

        # Build query
        statement = select(Task).where(Task.user_id == user_id)

        if status == "pending":
            statement = statement.where(Task.completed == False)
        elif status == "completed":
            statement = statement.where(Task.completed == True)

        tasks = session.exec(statement).all()

        # Format response
        if not tasks:
            return [TextContent(
                type="text",
                text=f"No {status} tasks found."
            )]

        # Build task list
        task_list = []
        for task in tasks:
            status_icon = "✓" if task.completed else "○"
            task_list.append(
                f"{status_icon} Task #{task.id}: {task.title}"
                + (f" - {task.description}" if task.description else "")
            )

        result_text = f"Found {len(tasks)} {status} task(s):\n" + "\n".join(task_list)

        return [TextContent(
            type="text",
            text=result_text
        )]

    except Exception as e:
        return [TextContent(
            type="text",
            text=f"✗ Failed to list tasks: {str(e)}"
        )]

@mcp_server.tool()
async def complete_task(
    user_id: str,
    task_id: int
) -> list[TextContent]:
    """
    Mark a task as complete.

    Args:
        user_id: Authenticated user ID (required)
        task_id: Task ID to mark as complete (required)

    Returns:
        Success message as TextContent
    """
    try:
        session = next(get_session())

        # Find task
        task = session.exec(
            select(Task).where(
                Task.id == task_id,
                Task.user_id == user_id
            )
        ).first()

        if not task:
            return [TextContent(
                type="text",
                text=f"✗ Task #{task_id} not found or unauthorized"
            )]

        # Mark as complete
        task.completed = True
        session.add(task)
        session.commit()
        session.refresh(task)

        return [TextContent(
            type="text",
            text=f"✓ Marked task #{task.id} as complete: {task.title}"
        )]

    except Exception as e:
        return [TextContent(
            type="text",
            text=f"✗ Failed to complete task: {str(e)}"
        )]

@mcp_server.tool()
async def delete_task(
    user_id: str,
    task_id: int
) -> list[TextContent]:
    """
    Remove a task from the list.

    Args:
        user_id: Authenticated user ID (required)
        task_id: Task ID to delete (required)

    Returns:
        Success message as TextContent
    """
    try:
        session = next(get_session())

        # Find task
        task = session.exec(
            select(Task).where(
                Task.id == task_id,
                Task.user_id == user_id
            )
        ).first()

        if not task:
            return [TextContent(
                type="text",
                text=f"✗ Task #{task_id} not found or unauthorized"
            )]

        task_title = task.title

        # Delete task
        session.delete(task)
        session.commit()

        return [TextContent(
            type="text",
            text=f"✓ Deleted task #{task_id}: {task_title}"
        )]

    except Exception as e:
        return [TextContent(
            type="text",
            text=f"✗ Failed to delete task: {str(e)}"
        )]

@mcp_server.tool()
async def update_task(
    user_id: str,
    task_id: int,
    title: Optional[str] = None,
    description: Optional[str] = None
) -> list[TextContent]:
    """
    Modify task title or description.

    Args:
        user_id: Authenticated user ID (required)
        task_id: Task ID to update (required)
        title: New task title (optional)
        description: New task description (optional)

    Returns:
        Success message with updated task details as TextContent
    """
    try:
        session = next(get_session())

        # Find task
        task = session.exec(
            select(Task).where(
                Task.id == task_id,
                Task.user_id == user_id
            )
        ).first()

        if not task:
            return [TextContent(
                type="text",
                text=f"✗ Task #{task_id} not found or unauthorized"
            )]

        # Update fields
        if title is not None:
            task.title = title
        if description is not None:
            task.description = description

        session.add(task)
        session.commit()
        session.refresh(task)

        return [TextContent(
            type="text",
            text=f"✓ Updated task #{task.id}: {task.title}"
        )]

    except Exception as e:
        return [TextContent(
            type="text",
            text=f"✗ Failed to update task: {str(e)}"
        )]
```

### 3. Export Tool Schemas for OpenAI Agents SDK
Create `backend/mcp_integration.py`:
```python
from mcp_server import mcp_server
from typing import Any

def get_mcp_tool_schemas() -> list[dict[str, Any]]:
    """
    Convert MCP tools to OpenAI Agents SDK format.

    Returns:
        List of tool schemas in OpenAI function calling format
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
                        "user_id": {
                            "type": "string",
                            "description": "Authenticated user ID"
                        },
                        "title": {
                            "type": "string",
                            "description": "Task title (required)"
                        },
                        "description": {
                            "type": "string",
                            "description": "Task description (optional)"
                        }
                    },
                    "required": ["user_id", "title"]
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
                        "user_id": {
                            "type": "string",
                            "description": "Authenticated user ID"
                        },
                        "status": {
                            "type": "string",
                            "enum": ["all", "pending", "completed"],
                            "description": "Filter by status (default: all)"
                        }
                    },
                    "required": ["user_id"]
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
                        "user_id": {
                            "type": "string",
                            "description": "Authenticated user ID"
                        },
                        "task_id": {
                            "type": "integer",
                            "description": "Task ID to complete"
                        }
                    },
                    "required": ["user_id", "task_id"]
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
                        "user_id": {
                            "type": "string",
                            "description": "Authenticated user ID"
                        },
                        "task_id": {
                            "type": "integer",
                            "description": "Task ID to delete"
                        }
                    },
                    "required": ["user_id", "task_id"]
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
                        "user_id": {
                            "type": "string",
                            "description": "Authenticated user ID"
                        },
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
                    "required": ["user_id", "task_id"]
                }
            }
        }
    ]

    return tools

async def execute_mcp_tool(
    tool_name: str,
    arguments: dict[str, Any]
) -> str:
    """
    Execute an MCP tool by name with given arguments.

    Args:
        tool_name: Name of the tool to execute
        arguments: Tool parameters as dictionary

    Returns:
        Tool execution result as string
    """
    # Get the tool function from mcp_server
    tool_func = getattr(mcp_server, tool_name, None)

    if not tool_func:
        return f"Error: Tool '{tool_name}' not found"

    try:
        # Execute tool
        result = await tool_func(**arguments)

        # Extract text from TextContent
        if isinstance(result, list) and len(result) > 0:
            return result[0].text

        return str(result)

    except Exception as e:
        return f"Error executing {tool_name}: {str(e)}"
```

### 4. Integrate with Agent
Update `backend/agent.py` to use MCP tools:
```python
from agents import Agent, Runner
from agents.extensions.models.litellm import LitellmModel
from agent_config import AGENT_CONFIG, GEMINI_API_KEY
from mcp_integration import get_mcp_tool_schemas, execute_mcp_tool

# Create model
model = LitellmModel(
    model=f"gemini/{AGENT_CONFIG['model']}",
    api_key=GEMINI_API_KEY,
    temperature=AGENT_CONFIG["temperature"],
    max_tokens=AGENT_CONFIG["max_tokens"]
)

# Create agent with MCP tools
agent = Agent(
    name="TodoBot",
    instructions=AGENT_CONFIG["system_prompt"],
    model=model,
    tools=get_mcp_tool_schemas()
)

async def run_agent_with_mcp_tools(
    messages: list[dict],
    user_id: str
) -> str:
    """
    Run agent with MCP tool execution.

    Args:
        messages: Conversation history
        user_id: Authenticated user ID

    Returns:
        Agent's response content
    """
    runner = Runner(agent)

    # Run agent
    result = await runner.run(messages=messages)

    # Handle tool calls if any
    if result.tool_calls:
        for tool_call in result.tool_calls:
            # Inject user_id into tool arguments
            arguments = tool_call.arguments
            arguments['user_id'] = user_id

            # Execute MCP tool
            tool_result = await execute_mcp_tool(
                tool_call.function.name,
                arguments
            )

            # Add tool result to messages
            messages.append({
                "role": "tool",
                "tool_call_id": tool_call.id,
                "content": tool_result
            })

        # Re-run agent with tool results
        result = await runner.run(messages=messages)

    return result.content
```

## Key Files Created

| File | Purpose |
|------|---------|
| backend/mcp_server.py | MCP server with official SDK and tool definitions |
| backend/mcp_integration.py | Tool schema export and execution wrapper |
| backend/agent.py | Agent integration with MCP tools |

## Dependencies

| Dependency | Version | Purpose |
|------------|---------|---------|
| mcp | ^1.0.0 | Official Model Context Protocol SDK |
| sqlmodel | ^0.0.14 | Database ORM for tool handlers |
| fastapi | ^0.109.0 | Web framework (if exposing via API) |

## Validation
Run: `.claude/skills/fastmcp-server-setup/validation.sh`

Expected output:
```
✓ Official MCP SDK installed
✓ MCP server file exists
✓ All 5 task tools defined
✓ Tools return TextContent format
✓ Tool schemas exported correctly
✓ Agent integration working
```

## Troubleshooting

### Issue: "mcp" package not found
**Solution**: Install the official MCP SDK:
```bash
pip install mcp
```

### Issue: ImportError: cannot import name 'Server'
**Solution**: Ensure you're using the correct import:
```python
from mcp.server import Server
from mcp.types import Tool, TextContent
```

### Issue: Tool execution fails with type error
**Solution**: Ensure tools return `list[TextContent]`:
```python
return [TextContent(type="text", text="Result message")]
```

### Issue: Agent not calling MCP tools
**Solution**: Verify tool schemas match OpenAI function calling format:
```python
tools = get_mcp_tool_schemas()
agent.tools = tools
```

### Issue: User ID not being injected
**Solution**: Inject user_id in tool execution wrapper:
```python
arguments['user_id'] = user_id
result = await execute_mcp_tool(tool_name, arguments)
```

## MCP Tool Return Format

### Correct Format (Official SDK)
```python
@mcp_server.tool()
async def add_task(...) -> list[TextContent]:
    return [TextContent(
        type="text",
        text="Task created successfully"
    )]
```

### Alternative Content Types
```python
# Image content
ImageContent(
    type="image",
    data="base64_encoded_image",
    mimeType="image/png"
)

# Embedded resource
EmbeddedResource(
    type="resource",
    resource={
        "uri": "file:///path/to/resource",
        "mimeType": "text/plain"
    }
)
```

## Architecture Benefits

### Using Official MCP SDK
✅ **Standards Compliant**: Follows official MCP specification
✅ **Type Safety**: Proper typing with TextContent, ImageContent
✅ **Future Proof**: Updates come from official source
✅ **Interoperability**: Works with any MCP-compatible client
✅ **Community Support**: Official documentation and examples

### vs. FastMCP (Third-Party)
❌ Not standards compliant
❌ Custom return types (dict instead of TextContent)
❌ May diverge from official spec
❌ Limited community support

## Next Steps
After completing this skill:
1. Test MCP tools individually
2. Integrate with OpenAI Agents SDK (openai-agents-setup skill)
3. Test tool calling from agent
4. Implement chat endpoint (chatkit-backend skill)
5. Build frontend UI (chatkit-frontend skill)

## References
- Official MCP SDK: https://github.com/modelcontextprotocol/python-sdk
- MCP Specification: https://modelcontextprotocol.io/
- OpenAI Agents SDK: https://openai.github.io/openai-agents-python/
