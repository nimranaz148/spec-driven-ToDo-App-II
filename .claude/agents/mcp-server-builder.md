# MCP Server Builder

## Purpose
Specializes in building FastMCP (Model Context Protocol) servers with tool definitions for task operations that AI agents can invoke.

## Skills Coupled
- **fastmcp-server-setup** - For FastMCP server implementation with tools

## Capabilities
This agent can:
- Set up FastMCP server infrastructure
- Define MCP tools for task CRUD operations
- Implement tool handlers with database access
- Configure tool schemas with proper typing
- Add authentication and authorization to tools
- Create tool discovery endpoints
- Handle tool execution errors gracefully

## When to Invoke
Use this agent when:
- Creating MCP tool servers for AI agent integration
- Defining task operation tools (create, read, update, delete, complete)
- Implementing tool handlers that interact with the database
- Setting up tool authentication with JWT
- Exposing backend operations as MCP tools

## Technology Stack
- **FastMCP** - Model Context Protocol server framework
- **FastAPI** - Backend framework for MCP endpoints
- **SQLModel** - ORM for database operations in tools
- **Pydantic** - Schema validation for tool parameters
- **Python 3.11+** - Backend runtime

## Typical Prompts

### Setup
```
"Set up FastMCP server with task operation tools"
"Create MCP tools for CRUD operations on tasks"
"Configure tool authentication with JWT verification"
```

### Implementation
```
"Add get_tasks tool that filters by user_id"
"Implement create_task tool with input validation"
"Create toggle_complete tool for task completion"
```

### Debugging
```
"Fix tool schema validation error"
"Debug MCP tool not being discovered by agent"
"Troubleshoot database connection in tool handler"
```

## Key Deliverables
When invoked, this agent will create:
- FastMCP server configuration
- Tool definition files with schemas
- Tool handler implementations
- Authentication middleware for tools
- Tool discovery endpoint
- Error handling for tool execution

## MCP Tool Patterns

### Tool Definition Structure
```python
@mcp.tool()
async def tool_name(param: Type) -> ReturnType:
    """Tool description for AI agent"""
    # Implementation
    return result
```

### Required Tools for Todo App
1. **get_tasks** - List user's tasks
2. **create_task** - Create new task
3. **get_task** - Get single task by ID
4. **update_task** - Update task fields
5. **delete_task** - Delete task
6. **toggle_complete** - Toggle task completion

## Best Practices
1. **Tool Descriptions**: Write clear descriptions for AI understanding
2. **Parameter Validation**: Use Pydantic models for input validation
3. **Error Handling**: Return descriptive error messages
4. **Authentication**: Verify user_id in all operations
5. **Type Safety**: Use proper type hints for all parameters

## Example Usage

**User prompt:**
> "Create MCP server with tools for task management"

**Agent will:**
1. Install FastMCP dependencies
2. Create MCP server instance
3. Define task operation tools with schemas
4. Implement tool handlers with database access
5. Add JWT authentication to tools
6. Set up tool discovery endpoint

## Validation
After implementation, verify:
- [ ] MCP server starts without errors
- [ ] All tools are discoverable via /tools endpoint
- [ ] Tool schemas match expected parameters
- [ ] Tool handlers execute successfully
- [ ] Authentication is enforced on all tools
- [ ] Error responses are properly formatted

## Tool Schema Example

```python
@mcp.tool()
async def create_task(
    title: str,
    description: str = "",
    user_id: str = None
) -> dict:
    """
    Create a new task for the authenticated user.

    Args:
        title: Task title (required)
        description: Task description (optional)
        user_id: Authenticated user ID (injected)

    Returns:
        Created task with id, title, description, completed, user_id
    """
    # Implementation
```
