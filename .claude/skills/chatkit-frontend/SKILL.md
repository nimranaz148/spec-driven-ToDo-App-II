# OpenAI ChatKit Frontend Integration

## Overview
This skill sets up **OpenAI's official ChatKit** for building a conversational interface with streaming AI responses. ChatKit provides production-ready chat UI components specifically designed for AI applications with built-in support for streaming, markdown rendering, and accessibility.

## When to Use This Skill
- Use when building the chat interface UI for the Todo app with OpenAI ChatKit
- Use when implementing real-time streaming message display
- Use when creating chat input and message list components with official OpenAI components
- Use when integrating EventSource for SSE streaming

## Prerequisites
- Next.js 16+ with App Router installed
- TypeScript configured
- Tailwind CSS set up
- Better Auth configured for user context
- Backend SSE endpoint ready (chatkit-backend skill)
- **OpenAI Platform account** for domain allowlist configuration

## Important: Domain Allowlist Configuration

**⚠️ Critical Setup Step**: OpenAI ChatKit requires domain allowlist configuration for production deployment.

### For Local Development
- `localhost` and `127.0.0.1` work without configuration
- No domain key needed for local testing

### For Production Deployment
**Required Steps**:
1. Deploy your frontend first to get production URL (e.g., `https://your-app.vercel.app`)
2. Navigate to: https://platform.openai.com/settings/organization/security/domain-allowlist
3. Click "Add domain"
4. Enter your frontend URL (without trailing slash)
5. Save and copy the generated domain key
6. Add domain key to environment variables

## Setup Steps

### 1. Install OpenAI ChatKit Dependencies
```bash
cd frontend
npm install openai-chatkit
```

**Note**: The package name may be `@openai/chatkit` or `openai-chatkit`. Check OpenAI's official documentation for the exact package name.

### 2. Configure Environment Variables
Add to `frontend/.env.local`:
```env
# For Production Only (not needed for localhost)
NEXT_PUBLIC_OPENAI_DOMAIN_KEY=your-domain-key-here

# Backend API URL
NEXT_PUBLIC_API_URL=http://localhost:8000
```

### 3. Create Chat Configuration
Create `frontend/lib/chatkit-config.ts`:
```typescript
export const CHATKIT_CONFIG = {
  // Domain key for production (optional for localhost)
  domainKey: process.env.NEXT_PUBLIC_OPENAI_DOMAIN_KEY,

  // Backend API configuration
  apiUrl: process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8000',

  // Chat settings
  maxMessageLength: 2000,
  enableMarkdown: true,
  enableCodeHighlighting: true,
  streamingEnabled: true
};
```

### 4. Create useChatKit Hook with OpenAI ChatKit
Create `frontend/hooks/useChatKit.ts`:
```typescript
'use client';

import { useState, useCallback } from 'react';
import { CHATKIT_CONFIG } from '@/lib/chatkit-config';

export interface Message {
  id: string;
  role: 'user' | 'assistant';
  content: string;
  timestamp: Date;
}

export interface UseChatKitReturn {
  messages: Message[];
  isStreaming: boolean;
  sendMessage: (content: string) => Promise<void>;
  clearMessages: () => void;
  error: string | null;
}

export function useChatKit(conversationId?: string): UseChatKitReturn {
  const [messages, setMessages] = useState<Message[]>([]);
  const [isStreaming, setIsStreaming] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const sendMessage = useCallback(async (content: string) => {
    if (!content.trim() || content.length > CHATKIT_CONFIG.maxMessageLength) {
      setError('Message is empty or too long');
      return;
    }

    setError(null);

    // Add user message immediately (optimistic update)
    const userMessage: Message = {
      id: `user-${Date.now()}`,
      role: 'user',
      content,
      timestamp: new Date()
    };
    setMessages(prev => [...prev, userMessage]);

    // Create assistant message placeholder
    const assistantMessageId = `assistant-${Date.now()}`;
    const assistantMessage: Message = {
      id: assistantMessageId,
      role: 'assistant',
      content: '',
      timestamp: new Date()
    };
    setMessages(prev => [...prev, assistantMessage]);

    setIsStreaming(true);

    try {
      // Get auth token from Better Auth
      const token = localStorage.getItem('auth_token');
      if (!token) {
        throw new Error('Not authenticated');
      }

      // Build SSE URL
      const url = new URL(`${CHATKIT_CONFIG.apiUrl}/api/chat/stream`);
      url.searchParams.set('message', content);
      if (conversationId) {
        url.searchParams.set('conversation_id', conversationId);
      }

      // Connect to SSE endpoint
      const eventSource = new EventSource(url.toString());

      let hasReceivedData = false;

      eventSource.onmessage = (event) => {
        hasReceivedData = true;

        if (event.data === '[DONE]') {
          eventSource.close();
          setIsStreaming(false);
        } else {
          // Append chunk to assistant message
          setMessages(prev =>
            prev.map(msg =>
              msg.id === assistantMessageId
                ? { ...msg, content: msg.content + event.data }
                : msg
            )
          );
        }
      };

      eventSource.onerror = (err) => {
        console.error('SSE error:', err);
        eventSource.close();
        setIsStreaming(false);

        if (!hasReceivedData) {
          setError('Failed to connect to chat server');
          // Remove assistant placeholder on error
          setMessages(prev => prev.filter(msg => msg.id !== assistantMessageId));
        }
      };

      // Timeout after 60 seconds
      setTimeout(() => {
        if (eventSource.readyState !== EventSource.CLOSED) {
          eventSource.close();
          setIsStreaming(false);
          if (!hasReceivedData) {
            setError('Request timed out');
          }
        }
      }, 60000);

    } catch (err) {
      console.error('Send message error:', err);
      setError(err instanceof Error ? err.message : 'Failed to send message');
      setIsStreaming(false);
      // Remove assistant placeholder on error
      setMessages(prev => prev.filter(msg => msg.id !== assistantMessageId));
    }
  }, [conversationId]);

  const clearMessages = useCallback(() => {
    setMessages([]);
    setError(null);
  }, []);

  return {
    messages,
    isStreaming,
    sendMessage,
    clearMessages,
    error
  };
}
```

### 5. Create Chat Components with OpenAI ChatKit
Create `frontend/components/chat/ChatInterface.tsx`:
```typescript
'use client';

import { useChatKit } from '@/hooks/useChatKit';
import { Chat, ChatInput, ChatMessage } from 'openai-chatkit';
import { CHATKIT_CONFIG } from '@/lib/chatkit-config';

interface ChatInterfaceProps {
  conversationId?: string;
}

export function ChatInterface({ conversationId }: ChatInterfaceProps) {
  const { messages, isStreaming, sendMessage, error } = useChatKit(conversationId);

  return (
    <div className="flex flex-col h-full bg-white">
      {/* Error Banner */}
      {error && (
        <div className="bg-red-50 border-b border-red-200 px-4 py-3 text-sm text-red-700">
          {error}
        </div>
      )}

      {/* Chat Container using OpenAI ChatKit */}
      <Chat
        domainKey={CHATKIT_CONFIG.domainKey}
        className="flex-1 overflow-hidden"
      >
        {/* Messages List */}
        <div className="flex-1 overflow-y-auto p-4 space-y-4">
          {messages.length === 0 ? (
            <div className="flex items-center justify-center h-full text-gray-500">
              <div className="text-center">
                <p className="text-lg font-medium">Start a conversation</p>
                <p className="text-sm mt-2">Ask me to manage your tasks!</p>
              </div>
            </div>
          ) : (
            messages.map(msg => (
              <ChatMessage
                key={msg.id}
                role={msg.role}
                content={msg.content}
                timestamp={msg.timestamp}
                isStreaming={msg.role === 'assistant' && isStreaming && msg.id === messages[messages.length - 1]?.id}
              />
            ))
          )}

          {/* Streaming Indicator */}
          {isStreaming && (
            <div className="flex items-center gap-2 text-gray-500 text-sm px-4">
              <span className="animate-pulse">●</span>
              <span className="animate-pulse animation-delay-200">●</span>
              <span className="animate-pulse animation-delay-400">●</span>
              <span>Assistant is thinking...</span>
            </div>
          )}
        </div>

        {/* Chat Input */}
        <div className="border-t bg-white p-4">
          <ChatInput
            onSend={sendMessage}
            disabled={isStreaming}
            placeholder="Type a message... (e.g., 'Add a task to buy groceries')"
            maxLength={CHATKIT_CONFIG.maxMessageLength}
          />
        </div>
      </Chat>
    </div>
  );
}
```

### 6. Create Fallback Custom Chat UI (If ChatKit Unavailable)
Create `frontend/components/chat/CustomChatUI.tsx`:
```typescript
'use client';

import { useChatKit } from '@/hooks/useChatKit';

interface CustomChatUIProps {
  conversationId?: string;
}

export function CustomChatUI({ conversationId }: CustomChatUIProps) {
  const { messages, isStreaming, sendMessage, error } = useChatKit(conversationId);

  const handleSubmit = (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    const formData = new FormData(e.currentTarget);
    const message = formData.get('message') as string;
    if (message.trim()) {
      sendMessage(message);
      e.currentTarget.reset();
    }
  };

  return (
    <div className="flex flex-col h-full bg-white">
      {/* Error Banner */}
      {error && (
        <div className="bg-red-50 border-b border-red-200 px-4 py-3 text-sm text-red-700">
          {error}
        </div>
      )}

      {/* Messages */}
      <div className="flex-1 overflow-y-auto p-4 space-y-4">
        {messages.length === 0 ? (
          <div className="flex items-center justify-center h-full text-gray-500">
            <div className="text-center">
              <p className="text-lg font-medium">Start a conversation</p>
              <p className="text-sm mt-2">Ask me to manage your tasks!</p>
            </div>
          </div>
        ) : (
          messages.map(msg => (
            <div
              key={msg.id}
              className={`flex ${msg.role === 'user' ? 'justify-end' : 'justify-start'}`}
            >
              <div
                className={`max-w-[70%] rounded-lg p-4 ${
                  msg.role === 'user'
                    ? 'bg-blue-500 text-white'
                    : 'bg-gray-100 text-gray-900'
                }`}
              >
                <p className="whitespace-pre-wrap">{msg.content}</p>
                <span className="text-xs opacity-70 mt-2 block">
                  {msg.timestamp.toLocaleTimeString()}
                </span>
              </div>
            </div>
          ))
        )}

        {isStreaming && (
          <div className="flex justify-start">
            <div className="bg-gray-100 rounded-lg p-4 max-w-[70%]">
              <div className="flex gap-1">
                <span className="animate-pulse">●</span>
                <span className="animate-pulse animation-delay-200">●</span>
                <span className="animate-pulse animation-delay-400">●</span>
              </div>
            </div>
          </div>
        )}
      </div>

      {/* Input */}
      <div className="border-t bg-white p-4">
        <form onSubmit={handleSubmit}>
          <div className="flex gap-2">
            <input
              type="text"
              name="message"
              placeholder="Type a message..."
              disabled={isStreaming}
              maxLength={2000}
              className="flex-1 px-4 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 disabled:bg-gray-100"
            />
            <button
              type="submit"
              disabled={isStreaming}
              className="px-6 py-2 bg-blue-500 text-white rounded-lg hover:bg-blue-600 disabled:bg-gray-300 disabled:cursor-not-allowed"
            >
              Send
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}
```

### 7. Create Main Chat Page
Create `frontend/app/chat/page.tsx`:
```typescript
import { ChatInterface } from '@/components/chat/ChatInterface';
import { CustomChatUI } from '@/components/chat/CustomChatUI';

// Dynamic import to check ChatKit availability
const USE_CHATKIT = process.env.NEXT_PUBLIC_USE_OPENAI_CHATKIT === 'true';

export default function ChatPage() {
  return (
    <div className="h-screen w-full">
      {/* Header */}
      <div className="bg-blue-500 text-white p-4">
        <h1 className="text-xl font-bold">Todo Assistant</h1>
        <p className="text-sm opacity-90">Powered by AI</p>
      </div>

      {/* Chat UI */}
      <div className="h-[calc(100vh-4rem)]">
        {USE_CHATKIT ? (
          <ChatInterface />
        ) : (
          <CustomChatUI />
        )}
      </div>
    </div>
  );
}
```

### 8. Add Animation Styles
Create `frontend/styles/chat-animations.css`:
```css
@keyframes pulse {
  0%, 100% {
    opacity: 1;
  }
  50% {
    opacity: 0.5;
  }
}

.animate-pulse {
  animation: pulse 1.5s cubic-bezier(0.4, 0, 0.6, 1) infinite;
}

.animation-delay-200 {
  animation-delay: 200ms;
}

.animation-delay-400 {
  animation-delay: 400ms;
}
```

Import in `frontend/app/layout.tsx`:
```typescript
import '@/styles/chat-animations.css';
```

## Key Files Created

| File | Purpose |
|------|---------|
| frontend/lib/chatkit-config.ts | ChatKit configuration and settings |
| frontend/hooks/useChatKit.ts | Chat state management with SSE |
| frontend/components/chat/ChatInterface.tsx | OpenAI ChatKit UI implementation |
| frontend/components/chat/CustomChatUI.tsx | Fallback custom chat UI |
| frontend/app/chat/page.tsx | Main chat page route |
| frontend/styles/chat-animations.css | Animation styles for chat |
| frontend/.env.local | Environment variables |

## Dependencies

| Dependency | Version | Purpose |
|------------|---------|---------|
| openai-chatkit | latest | OpenAI's official ChatKit library |
| next | ^16.0.0 | React framework |
| react | ^19.0.0 | UI library |
| typescript | ^5.0.0 | Type safety |

## Environment Variables

```env
# Production Only (not needed for localhost)
NEXT_PUBLIC_OPENAI_DOMAIN_KEY=your-domain-key-here

# Backend API URL
NEXT_PUBLIC_API_URL=http://localhost:8000

# Feature Flag (optional)
NEXT_PUBLIC_USE_OPENAI_CHATKIT=true
```

## Domain Allowlist Setup Guide

### Step-by-Step Process

1. **Deploy Your Frontend First**
   ```bash
   cd frontend
   npm run build
   vercel deploy --prod
   ```

   Note your deployment URL (e.g., `https://todo-app.vercel.app`)

2. **Configure OpenAI Domain Allowlist**
   - Navigate to: https://platform.openai.com/settings/organization/security/domain-allowlist
   - Click "Add domain"
   - Enter: `https://todo-app.vercel.app` (your actual URL)
   - Save changes

3. **Get Domain Key**
   - After adding domain, OpenAI provides a domain key
   - Copy this key

4. **Add to Vercel Environment Variables**
   ```bash
   # Via Vercel Dashboard
   Settings → Environment Variables → Add

   Key: NEXT_PUBLIC_OPENAI_DOMAIN_KEY
   Value: your-domain-key-here
   ```

5. **Redeploy**
   ```bash
   vercel deploy --prod
   ```

### Local Development (No Configuration Needed)
```bash
cd frontend
npm run dev
```

Visit `http://localhost:3000/chat` - ChatKit works without domain key on localhost.

## Validation
Run: `.claude/skills/chatkit-frontend/validation.sh`

Expected output:
```
✓ OpenAI ChatKit package installed
✓ useChatKit hook exists
✓ Chat components exist
✓ Chat page route exists
✓ Environment variables configured
✓ SSE connection works
✓ Domain allowlist configured (production only)
```

## Troubleshooting

### Issue: ChatKit not loading in production
**Solution**: Verify domain allowlist configuration:
1. Check domain is added: https://platform.openai.com/settings/organization/security/domain-allowlist
2. Verify `NEXT_PUBLIC_OPENAI_DOMAIN_KEY` is set in Vercel environment variables
3. Ensure URL matches exactly (with/without www, http vs https)

### Issue: "Package 'openai-chatkit' not found"
**Solution**: Check OpenAI documentation for the correct package name. It may be `@openai/chatkit` or available via CDN:
```html
<script src="https://cdn.openai.com/chatkit/latest/chatkit.js"></script>
```

### Issue: Messages not streaming in real-time
**Solution**: Verify EventSource is connecting to correct SSE endpoint:
```typescript
const url = new URL(`${CHATKIT_CONFIG.apiUrl}/api/chat/stream`);
console.log('Connecting to:', url.toString());
```

### Issue: "Not authenticated" error
**Solution**: Ensure Better Auth token is available:
```typescript
const token = localStorage.getItem('auth_token');
if (!token) {
  // Redirect to login or show auth error
}
```

## Testing Checklist

- [ ] Chat UI loads on localhost without domain key
- [ ] Can send messages and receive responses
- [ ] Streaming works (messages appear character by character)
- [ ] User messages appear immediately (optimistic update)
- [ ] Error messages display correctly
- [ ] Domain allowlist configured for production
- [ ] Production deployment works with domain key
- [ ] Fallback UI works if ChatKit fails

## Deployment Checklist

### Before Production Deployment
1. [ ] Frontend built and deployed to get URL
2. [ ] Domain added to OpenAI allowlist
3. [ ] Domain key copied from OpenAI dashboard
4. [ ] `NEXT_PUBLIC_OPENAI_DOMAIN_KEY` set in Vercel
5. [ ] Redeployed after adding environment variable
6. [ ] Tested chat on production URL

### Fallback Strategy
If OpenAI ChatKit has issues:
```env
NEXT_PUBLIC_USE_OPENAI_CHATKIT=false
```

This will use the custom Tailwind-based chat UI instead.

## Next Steps
After completing this skill:
1. Test chat UI locally on localhost
2. Deploy to Vercel and configure domain allowlist
3. Test production deployment with domain key
4. Integrate with conversation management (conversation-management skill)
5. Add message persistence (chatkit-backend skill)

## References
- OpenAI ChatKit Documentation: https://platform.openai.com/docs/guides/chatkit
- Domain Allowlist Setup: https://platform.openai.com/settings/organization/security/domain-allowlist
- Vercel Environment Variables: https://vercel.com/docs/environment-variables
