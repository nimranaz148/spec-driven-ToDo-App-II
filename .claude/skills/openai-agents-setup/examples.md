# OpenAI Agents Setup - Examples

## Example 1: Basic Agent Query

### Request
```python
from agent import create_agent_response

messages = [
    {"role": "user", "content": "What tasks do I have today?"}
]

response = await create_agent_response(messages, stream=False)
print(response.choices[0].message.content)
```

### Response
```
Let me check your tasks for you.
```

## Example 2: Streaming Agent Response

### Backend Implementation
```python
from fastapi import APIRouter
from fastapi.responses import StreamingResponse
from agent import create_agent_response

@router.post("/chat/stream")
async def stream_chat(message: str):
    messages = [{"role": "user", "content": message}]

    async def generate():
        response = await create_agent_response(messages, stream=True)
        for chunk in response:
            delta = chunk.choices[0].delta
            if delta.content:
                yield f"data: {delta.content}\n\n"
        yield "data: [DONE]\n\n"

    return StreamingResponse(generate(), media_type="text/event-stream")
```

### Frontend Consumption
```typescript
const eventSource = new EventSource('/api/chat/stream?message=Hello');

eventSource.onmessage = (event) => {
  if (event.data === '[DONE]') {
    eventSource.close();
  } else {
    console.log('Chunk:', event.data);
  }
};
```

## Example 3: Agent with Tool Calling

### Tool Schema
```python
tools = [
    {
        "type": "function",
        "function": {
            "name": "get_tasks",
            "description": "Get all tasks for the user",
            "parameters": {
                "type": "object",
                "properties": {
                    "completed": {
                        "type": "boolean",
                        "description": "Filter by completion status"
                    }
                }
            }
        }
    }
]
```

### Agent Call
```python
messages = [
    {"role": "user", "content": "Show me my incomplete tasks"}
]

response = await create_agent_response(
    messages=messages,
    tools=tools,
    stream=False
)

# Check if tool was called
if response.choices[0].message.tool_calls:
    tool_call = response.choices[0].message.tool_calls[0]
    print(f"Tool called: {tool_call.function.name}")
    print(f"Arguments: {tool_call.function.arguments}")
```

### Output
```
Tool called: get_tasks
Arguments: {"completed": false}
```

## Example 4: Multi-Turn Conversation

### Implementation
```python
conversation_history = [
    {"role": "user", "content": "Create a task to buy groceries"},
    {"role": "assistant", "content": "I've created the task 'Buy groceries'."},
    {"role": "user", "content": "Mark it as complete"}
]

response = await create_agent_response(conversation_history, stream=False)
print(response.choices[0].message.content)
```

### Response
```
I've marked 'Buy groceries' as complete. Great job!
```

## Example 5: Custom System Prompt

### Configuration
```python
CUSTOM_AGENT_CONFIG = {
    "model": "gemini/gemini-2.0-flash-exp",
    "temperature": 0.5,
    "max_tokens": 1500,
    "system_prompt": """You are a productivity coach assistant.
When users create tasks, encourage them and suggest time management tips.
Keep responses brief and motivating."""
}

async def create_coaching_agent(messages: list[dict]):
    response = client.chat.completions.create(
        model=CUSTOM_AGENT_CONFIG["model"],
        messages=[
            {"role": "system", "content": CUSTOM_AGENT_CONFIG["system_prompt"]},
            *messages
        ],
        temperature=CUSTOM_AGENT_CONFIG["temperature"],
        max_tokens=CUSTOM_AGENT_CONFIG["max_tokens"]
    )
    return response
```

## Example 6: Error Handling

### Robust Implementation
```python
from typing import AsyncIterator
import logging

async def safe_agent_response(
    messages: list[dict],
    tools: list[dict] = None
) -> AsyncIterator[str]:
    """Agent response with error handling"""
    try:
        response = await create_agent_response(
            messages=messages,
            tools=tools,
            stream=True
        )

        for chunk in response:
            if chunk.choices[0].delta.content:
                yield chunk.choices[0].delta.content

    except Exception as e:
        logging.error(f"Agent error: {e}")
        yield "I apologize, but I encountered an error. Please try again."
```

## Example 7: Agent with Conversation Context

### With Database Persistence
```python
from sqlmodel import Session, select
from models import Message, Conversation

async def chat_with_context(
    user_message: str,
    conversation_id: str,
    user_id: str,
    session: Session
):
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
    messages.append({"role": "user", "content": user_message})

    # Get agent response
    response = await create_agent_response(messages, stream=False)

    # Save to database
    user_msg = Message(
        conversation_id=conversation_id,
        role="user",
        content=user_message
    )
    assistant_msg = Message(
        conversation_id=conversation_id,
        role="assistant",
        content=response.choices[0].message.content
    )

    session.add(user_msg)
    session.add(assistant_msg)
    session.commit()

    return response.choices[0].message.content
```

## Example 8: LiteLLM Configuration for Multiple Models

### Advanced litellm_config.yaml
```yaml
model_list:
  - model_name: gemini-2.0-flash-exp
    litellm_params:
      model: gemini/gemini-2.0-flash-exp
      api_key: os.environ/GOOGLE_API_KEY
      temperature: 0.7

  - model_name: gpt-4
    litellm_params:
      model: gpt-4
      api_key: os.environ/OPENAI_API_KEY
      temperature: 0.8

router_settings:
  fallbacks: [{"gemini-2.0-flash-exp": ["gpt-4"]}]
```

### Using Different Models
```python
# Use Gemini
response = await create_agent_response(messages, model="gemini-2.0-flash-exp")

# Fallback to GPT-4 if Gemini fails
response = await create_agent_response(messages, model="gpt-4")
```

## Testing Examples

### Unit Test
```python
import pytest
from agent import create_agent_response

@pytest.mark.asyncio
async def test_agent_responds():
    messages = [{"role": "user", "content": "Hello"}]
    response = await create_agent_response(messages, stream=False)

    assert response.choices[0].message.content
    assert len(response.choices[0].message.content) > 0

@pytest.mark.asyncio
async def test_agent_streaming():
    messages = [{"role": "user", "content": "Count to 3"}]
    response = await create_agent_response(messages, stream=True)

    chunks = []
    for chunk in response:
        if chunk.choices[0].delta.content:
            chunks.append(chunk.choices[0].delta.content)

    assert len(chunks) > 0
```

### Integration Test
```python
from fastapi.testclient import TestClient
from main import app

client = TestClient(app)

def test_chat_stream_endpoint():
    with client.stream("POST", "/api/chat/stream", json={
        "message": "Hello, assistant!"
    }) as response:
        assert response.status_code == 200
        chunks = list(response.iter_lines())
        assert len(chunks) > 0
        assert b"data: [DONE]" in chunks[-1]
```
