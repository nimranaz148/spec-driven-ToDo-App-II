# FastMCP Server Setup - Examples

## Example 1: Basic Tool Definition

### Simple Tool
```python
from fastmcp import FastMCP

mcp = FastMCP("My Tools")

@mcp.tool()
async def hello_world(name: str) -> str:
    """Say hello to someone"""
    return f"Hello, {name}!"

# Tool is automatically registered
```

### Usage
```python
result = await mcp.call_tool("hello_world", {"name": "Alice"})
print(result)  # "Hello, Alice!"
```

## Example 2: Tool with Database Access

### Task Query Tool
```python
from fastmcp import FastMCP
from sqlmodel import Session, select
from models import Task
from db import get_session

mcp = FastMCP("Task Tools")

@mcp.tool()
async def get_user_tasks(user_id: str) -> list[dict]:
    """Get all tasks for a user"""
    session = next(get_session())

    tasks = session.exec(
        select(Task).where(Task.user_id == user_id)
    ).all()

    return [
        {
            "id": str(task.id),
            "title": task.title,
            "completed": task.completed
        }
        for task in tasks
    ]
```

### Testing
```python
import pytest
from mcp_server import mcp

@pytest.mark.asyncio
async def test_get_user_tasks():
    result = await mcp.call_tool("get_user_tasks", {
        "user_id": "test-user-123"
    })

    assert isinstance(result, list)
    assert all("id" in task for task in result)
```

## Example 3: Tool with Optional Parameters

### Update Tool
```python
from typing import Optional

@mcp.tool()
async def update_task(
    task_id: str,
    title: Optional[str] = None,
    description: Optional[str] = None,
    completed: Optional[bool] = None
) -> dict:
    """
    Update task fields.

    Args:
        task_id: Task ID (required)
        title: New title (optional)
        description: New description (optional)
        completed: New completion status (optional)
    """
    session = next(get_session())

    task = session.get(Task, task_id)
    if not task:
        raise ValueError(f"Task {task_id} not found")

    if title is not None:
        task.title = title
    if description is not None:
        task.description = description
    if completed is not None:
        task.completed = completed

    session.add(task)
    session.commit()
    session.refresh(task)

    return {"id": task.id, "title": task.title}
```

## Example 4: Tool Discovery Endpoint

### FastAPI Route
```python
from fastapi import APIRouter, Depends
from mcp_server import mcp
from auth import get_current_user

router = APIRouter()

@router.get("/mcp/tools")
async def list_tools(user_id: str = Depends(get_current_user)):
    """
    List all available MCP tools with schemas.

    Returns:
        List of tools with name, description, and parameters
    """
    tools = mcp.list_tools()

    return {
        "tools": [
            {
                "name": tool.name,
                "description": tool.description,
                "parameters": tool.parameters.model_json_schema()
            }
            for tool in tools
        ]
    }
```

### Response
```json
{
  "tools": [
    {
      "name": "get_tasks",
      "description": "Get all tasks for the authenticated user",
      "parameters": {
        "type": "object",
        "properties": {
          "user_id": {"type": "string"},
          "completed": {"type": "boolean"}
        },
        "required": ["user_id"]
      }
    }
  ]
}
```

## Example 5: Tool Execution Endpoint

### Execution Route
```python
@router.post("/mcp/tools/{tool_name}")
async def execute_tool(
    tool_name: str,
    parameters: dict,
    user_id: str = Depends(get_current_user)
):
    """
    Execute an MCP tool with parameters.

    Args:
        tool_name: Name of the tool to execute
        parameters: Tool parameters as JSON
        user_id: Authenticated user ID (from JWT)

    Returns:
        Tool execution result
    """
    # Inject authenticated user_id
    parameters["user_id"] = user_id

    try:
        result = await mcp.call_tool(tool_name, parameters)
        return {"success": True, "result": result}
    except ValueError as e:
        return {"success": False, "error": str(e)}
    except Exception as e:
        return {"success": False, "error": "Internal error"}
```

### Request
```bash
curl -X POST http://localhost:8000/api/mcp/tools/create_task \
  -H "Authorization: Bearer <jwt_token>" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Buy groceries",
    "description": "Milk, eggs, bread"
  }'
```

### Response
```json
{
  "success": true,
  "result": {
    "id": "task-123",
    "title": "Buy groceries",
    "description": "Milk, eggs, bread",
    "completed": false,
    "user_id": "user-456"
  }
}
```

## Example 6: Agent Integration

### Get Tools for Agent
```python
from mcp_server import mcp

async def get_agent_tools() -> list[dict]:
    """
    Format MCP tools for OpenAI Agents SDK.

    Returns:
        List of tools in OpenAI function calling format
    """
    tools = mcp.list_tools()

    return [
        {
            "type": "function",
            "function": {
                "name": tool.name,
                "description": tool.description,
                "parameters": tool.parameters.model_json_schema()
            }
        }
        for tool in tools
    ]
```

### Agent with Tools
```python
from openai import OpenAI
from mcp_server import mcp

client = OpenAI(base_url="http://localhost:4000")

async def chat_with_tools(message: str, user_id: str):
    # Get tools
    tools = await get_agent_tools()

    # Call agent
    response = client.chat.completions.create(
        model="gemini-2.0-flash-exp",
        messages=[{"role": "user", "content": message}],
        tools=tools
    )

    # Check if tool was called
    if response.choices[0].message.tool_calls:
        tool_call = response.choices[0].message.tool_calls[0]

        # Execute tool
        arguments = json.loads(tool_call.function.arguments)
        arguments["user_id"] = user_id

        result = await mcp.call_tool(
            tool_call.function.name,
            arguments
        )

        # Send result back to agent
        response = client.chat.completions.create(
            model="gemini-2.0-flash-exp",
            messages=[
                {"role": "user", "content": message},
                response.choices[0].message,
                {
                    "role": "tool",
                    "tool_call_id": tool_call.id,
                    "content": json.dumps(result)
                }
            ],
            tools=tools
        )

    return response.choices[0].message.content
```

## Example 7: Error Handling in Tools

### Robust Tool Handler
```python
from fastapi import HTTPException

@mcp.tool()
async def delete_task(user_id: str, task_id: str) -> dict:
    """
    Delete a task with comprehensive error handling.

    Args:
        user_id: Authenticated user ID
        task_id: Task ID to delete

    Returns:
        Success message

    Raises:
        ValueError: If task not found or unauthorized
    """
    try:
        session = next(get_session())

        task = session.exec(
            select(Task).where(
                Task.id == task_id,
                Task.user_id == user_id
            )
        ).first()

        if not task:
            raise ValueError(
                f"Task {task_id} not found or you don't have permission"
            )

        session.delete(task)
        session.commit()

        return {
            "message": f"Task '{task.title}' deleted successfully",
            "task_id": task_id
        }

    except ValueError:
        raise
    except Exception as e:
        raise ValueError(f"Failed to delete task: {str(e)}")
```

## Example 8: Batch Operations Tool

### Multi-Task Tool
```python
@mcp.tool()
async def batch_complete_tasks(
    user_id: str,
    task_ids: list[str]
) -> dict:
    """
    Mark multiple tasks as complete.

    Args:
        user_id: Authenticated user ID
        task_ids: List of task IDs to complete

    Returns:
        Summary of completed tasks
    """
    session = next(get_session())

    tasks = session.exec(
        select(Task).where(
            Task.id.in_(task_ids),
            Task.user_id == user_id
        )
    ).all()

    completed_count = 0
    for task in tasks:
        if not task.completed:
            task.completed = True
            session.add(task)
            completed_count += 1

    session.commit()

    return {
        "completed_count": completed_count,
        "total_requested": len(task_ids),
        "task_ids": [str(task.id) for task in tasks]
    }
```

## Example 9: Tool with Complex Parameters

### Advanced Tool Schema
```python
from pydantic import BaseModel, Field
from typing import Literal

class TaskFilter(BaseModel):
    completed: Optional[bool] = None
    priority: Optional[Literal["low", "medium", "high"]] = None
    due_date: Optional[str] = Field(None, description="ISO date string")

@mcp.tool()
async def search_tasks(
    user_id: str,
    filters: TaskFilter,
    limit: int = 10
) -> list[dict]:
    """
    Search tasks with advanced filtering.

    Args:
        user_id: Authenticated user ID
        filters: Task filter criteria
        limit: Maximum number of results

    Returns:
        Filtered list of tasks
    """
    session = next(get_session())

    statement = select(Task).where(Task.user_id == user_id)

    if filters.completed is not None:
        statement = statement.where(Task.completed == filters.completed)

    if filters.priority:
        statement = statement.where(Task.priority == filters.priority)

    statement = statement.limit(limit)

    tasks = session.exec(statement).all()

    return [
        {
            "id": str(task.id),
            "title": task.title,
            "completed": task.completed,
            "priority": task.priority
        }
        for task in tasks
    ]
```

## Testing Examples

### Unit Tests
```python
import pytest
from mcp_server import mcp

@pytest.mark.asyncio
async def test_create_task():
    result = await mcp.call_tool("create_task", {
        "user_id": "test-user",
        "title": "Test Task",
        "description": "Test description"
    })

    assert result["title"] == "Test Task"
    assert result["completed"] is False

@pytest.mark.asyncio
async def test_tool_not_found():
    with pytest.raises(ValueError):
        await mcp.call_tool("nonexistent_tool", {})
```

### Integration Tests
```python
from fastapi.testclient import TestClient
from main import app

client = TestClient(app)

def test_list_tools():
    response = client.get("/api/mcp/tools")
    assert response.status_code == 200
    assert "tools" in response.json()
    assert len(response.json()["tools"]) > 0

def test_execute_tool():
    response = client.post(
        "/api/mcp/tools/get_tasks",
        json={},
        headers={"Authorization": "Bearer test-token"}
    )
    assert response.status_code == 200
    assert "result" in response.json()
```
