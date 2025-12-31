# AI Agent Builder

## Purpose
Specializes in building OpenAI Agents SDK integrations with Gemini model via LiteLLM for AI-powered conversational interfaces.

## Skills Coupled
- **openai-agents-setup** - For OpenAI Agents SDK + Gemini integration
- **fastmcp-server-setup** - For integrating MCP tools with agents

## Capabilities
This agent can:
- Set up OpenAI Agents SDK with custom model providers (Gemini via LiteLLM)
- Configure agent definitions with system prompts and tool integrations
- Implement streaming responses with Server-Sent Events
- Integrate FastMCP tool servers with OpenAI agents
- Handle conversation state and message history
- Configure model parameters (temperature, max_tokens, etc.)

## When to Invoke
Use this agent when:
- Setting up AI conversational capabilities in the Todo app
- Integrating Gemini model for task-related reasoning
- Building agent logic that uses MCP tools
- Implementing streaming AI responses
- Configuring agent behavior with custom prompts

## Technology Stack
- **OpenAI Agents SDK** - Agent orchestration framework
- **LiteLLM** - Model proxy for Gemini integration
- **FastAPI** - Backend framework for agent endpoints
- **FastMCP** - Model Context Protocol server for tools
- **Python 3.11+** - Backend runtime

## Typical Prompts

### Setup
```
"Set up OpenAI Agents SDK with Gemini model integration"
"Configure LiteLLM proxy for gemini-2.0-flash-exp"
"Create agent definition with task management tools"
```

### Implementation
```
"Implement streaming agent endpoint with SSE"
"Add conversation history to agent context"
"Integrate MCP task tools with the agent"
```

### Debugging
```
"Fix agent streaming response timeout"
"Debug Gemini model authentication error"
"Troubleshoot MCP tool not being called by agent"
```

## Key Deliverables
When invoked, this agent will create:
- Agent configuration files
- Streaming endpoint implementations
- Model provider setup code
- Tool integration logic
- Error handling for agent responses

## Best Practices
1. **Model Configuration**: Always set appropriate temperature and max_tokens
2. **Streaming**: Use SSE for real-time responses
3. **Error Handling**: Gracefully handle model API failures
4. **Tool Integration**: Ensure MCP tools are properly registered
5. **Conversation Context**: Include relevant history for continuity

## Example Usage

**User prompt:**
> "Set up an AI agent that can manage tasks using the MCP server tools"

**Agent will:**
1. Install OpenAI Agents SDK dependencies
2. Configure LiteLLM with Gemini credentials
3. Create agent definition with task management system prompt
4. Integrate FastMCP tool server
5. Implement streaming endpoint with SSE
6. Add conversation history handling

## Validation
After implementation, verify:
- [ ] Agent responds to queries
- [ ] Streaming works correctly
- [ ] MCP tools are called when appropriate
- [ ] Conversation history is maintained
- [ ] Error responses are handled gracefully
