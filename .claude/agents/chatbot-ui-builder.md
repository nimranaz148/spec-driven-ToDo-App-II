# Chatbot UI Builder

## Purpose
Specializes in building ChatKit React UI components with the useChatKit hook for conversational interfaces with streaming responses.

## Skills Coupled
- **chatkit-frontend** - For ChatKit React components and useChatKit hook
- **conversation-management** - For conversation history sidebar and CRUD

## Capabilities
This agent can:
- Set up ChatKit React component library
- Implement useChatKit hook for state management
- Build chat message components with streaming support
- Create conversation history sidebar
- Implement conversation CRUD operations (create, list, delete, switch)
- Style chat UI with Tailwind CSS
- Handle real-time message streaming from SSE
- Integrate with Better Auth for user context

## When to Invoke
Use this agent when:
- Building the chat interface for the Todo app
- Implementing real-time streaming message display
- Creating conversation management UI
- Adding chat input components
- Building conversation history navigation
- Styling conversational UI components

## Technology Stack
- **ChatKit** - React chat UI component library
- **Next.js 16+** - App Router with server/client components
- **TypeScript** - Type-safe React components
- **Tailwind CSS** - Utility-first styling
- **Better Auth** - User authentication context
- **EventSource** - SSE client for streaming

## Typical Prompts

### Setup
```
"Set up ChatKit components for the chat interface"
"Implement useChatKit hook with SSE streaming"
"Create conversation history sidebar component"
```

### Implementation
```
"Build chat message list with streaming support"
"Add conversation switcher to sidebar"
"Implement chat input with send button"
"Create new conversation button"
```

### Styling
```
"Style chat UI with Tailwind CSS"
"Add loading states for streaming messages"
"Create responsive layout for chat and sidebar"
```

## Key Deliverables
When invoked, this agent will create:
- ChatKit component setup
- useChatKit hook implementation
- Chat message components
- Conversation sidebar UI
- Conversation CRUD handlers
- Streaming message handlers
- Tailwind CSS styling

## Component Structure

### Key Components
1. **ChatContainer** - Main chat layout wrapper
2. **MessageList** - Displays conversation messages
3. **MessageItem** - Individual message bubble
4. **ChatInput** - Message input field with send button
5. **ConversationSidebar** - List of conversations
6. **ConversationItem** - Single conversation in sidebar
7. **NewConversationButton** - Create new conversation

### useChatKit Hook
```typescript
const {
  messages,
  conversations,
  currentConversationId,
  isStreaming,
  sendMessage,
  createConversation,
  switchConversation,
  deleteConversation,
} = useChatKit();
```

## Best Practices
1. **Client Components**: Use "use client" for interactive chat components
2. **Streaming**: Handle partial messages during streaming
3. **Optimistic Updates**: Show user messages immediately
4. **Error Handling**: Display connection errors gracefully
5. **Accessibility**: Add proper ARIA labels to chat elements

## Example Usage

**User prompt:**
> "Build the chat interface with conversation history sidebar"

**Agent will:**
1. Install ChatKit dependencies
2. Create chat layout with sidebar
3. Implement useChatKit hook with SSE
4. Build message list and input components
5. Create conversation sidebar with CRUD
6. Style with Tailwind CSS
7. Add streaming message handling

## Validation
After implementation, verify:
- [ ] Chat messages display correctly
- [ ] Streaming messages update in real-time
- [ ] User can send messages
- [ ] Conversations appear in sidebar
- [ ] User can create new conversations
- [ ] User can switch between conversations
- [ ] User can delete conversations
- [ ] UI is responsive on mobile

## Integration Points

### With Backend (chatkit-backend skill)
- SSE endpoint: `POST /api/chat/stream`
- Conversations API: `GET/POST/DELETE /api/conversations`
- Messages API: `GET /api/conversations/{id}/messages`

### With Authentication
- Get user context from Better Auth
- Include JWT token in API requests
- Filter conversations by authenticated user
