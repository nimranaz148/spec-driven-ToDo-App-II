# ChatKit Frontend - Examples

## Example 1: Basic Chat Component

### Simple Chat Implementation
```typescript
'use client';

import { useChatKit } from '@/hooks/useChatKit';

export function SimpleChat() {
  const { messages, sendMessage, isStreaming } = useChatKit();

  return (
    <div className="flex flex-col h-screen">
      {/* Messages */}
      <div className="flex-1 overflow-y-auto p-4">
        {messages.map(msg => (
          <div
            key={msg.id}
            className={`mb-4 ${
              msg.role === 'user' ? 'text-right' : 'text-left'
            }`}
          >
            <div
              className={`inline-block p-3 rounded-lg ${
                msg.role === 'user'
                  ? 'bg-blue-500 text-white'
                  : 'bg-gray-200 text-gray-900'
              }`}
            >
              {msg.content}
            </div>
          </div>
        ))}
      </div>

      {/* Input */}
      <div className="p-4 border-t">
        <input
          type="text"
          placeholder="Type a message..."
          disabled={isStreaming}
          onKeyPress={(e) => {
            if (e.key === 'Enter' && e.currentTarget.value) {
              sendMessage(e.currentTarget.value);
              e.currentTarget.value = '';
            }
          }}
          className="w-full p-2 border rounded"
        />
      </div>
    </div>
  );
}
```

## Example 2: Chat with Streaming Indicator

### Streaming Animation
```typescript
'use client';

import { useChatKit } from '@/hooks/useChatKit';

export function ChatWithStreaming() {
  const { messages, sendMessage, isStreaming } = useChatKit();

  return (
    <div className="chat-container">
      <MessageList messages={messages} />

      {isStreaming && (
        <div className="flex items-center gap-2 p-4 text-gray-500">
          <div className="animate-pulse">●</div>
          <div className="animate-pulse animation-delay-200">●</div>
          <div className="animate-pulse animation-delay-400">●</div>
          <span className="ml-2">Assistant is typing...</span>
        </div>
      )}

      <ChatInput onSend={sendMessage} disabled={isStreaming} />
    </div>
  );
}
```

### CSS for Animation Delays
```css
.animation-delay-200 {
  animation-delay: 200ms;
}

.animation-delay-400 {
  animation-delay: 400ms;
}
```

## Example 3: Advanced useChatKit Hook with Error Handling

### Enhanced Hook
```typescript
'use client';

import { useState, useCallback } from 'react';

export function useChatKit(conversationId?: string) {
  const [messages, setMessages] = useState<Message[]>([]);
  const [isStreaming, setIsStreaming] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const sendMessage = useCallback(async (content: string) => {
    setError(null);

    // Add user message
    const userMessage: Message = {
      id: `user-${Date.now()}`,
      role: 'user',
      content,
      timestamp: new Date()
    };
    setMessages(prev => [...prev, userMessage]);

    // Add assistant placeholder
    const assistantId = `assistant-${Date.now()}`;
    setMessages(prev => [...prev, {
      id: assistantId,
      role: 'assistant',
      content: '',
      timestamp: new Date()
    }]);

    setIsStreaming(true);

    try {
      const token = localStorage.getItem('auth_token');
      const url = new URL('/api/chat/stream', window.location.origin);
      url.searchParams.set('message', content);
      if (conversationId) {
        url.searchParams.set('conversation_id', conversationId);
      }

      const eventSource = new EventSource(url.toString(), {
        headers: {
          'Authorization': `Bearer ${token}`
        }
      } as any);

      let hasReceivedData = false;

      eventSource.onmessage = (event) => {
        hasReceivedData = true;

        if (event.data === '[DONE]') {
          eventSource.close();
          setIsStreaming(false);
        } else {
          setMessages(prev =>
            prev.map(msg =>
              msg.id === assistantId
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
          setMessages(prev => prev.filter(msg => msg.id !== assistantId));
        }
      };

      // Timeout after 30 seconds
      setTimeout(() => {
        if (eventSource.readyState !== EventSource.CLOSED) {
          eventSource.close();
          setIsStreaming(false);
          if (!hasReceivedData) {
            setError('Request timed out');
          }
        }
      }, 30000);

    } catch (err) {
      console.error('Send message error:', err);
      setError('Failed to send message');
      setIsStreaming(false);
    }
  }, [conversationId]);

  return {
    messages,
    isStreaming,
    error,
    sendMessage,
    clearError: () => setError(null)
  };
}
```

## Example 4: Message Component with Markdown Support

### Rich Message Display
```typescript
'use client';

import ReactMarkdown from 'react-markdown';
import { Prism as SyntaxHighlighter } from 'react-syntax-highlighter';
import { Message } from '@/hooks/useChatKit';

interface MessageItemProps {
  message: Message;
}

export function MessageItem({ message }: MessageItemProps) {
  return (
    <div
      className={`flex ${
        message.role === 'user' ? 'justify-end' : 'justify-start'
      } mb-4`}
    >
      <div
        className={`max-w-[70%] rounded-lg p-4 ${
          message.role === 'user'
            ? 'bg-blue-500 text-white'
            : 'bg-gray-100 text-gray-900'
        }`}
      >
        {message.role === 'assistant' ? (
          <ReactMarkdown
            components={{
              code({ node, inline, className, children, ...props }) {
                const match = /language-(\w+)/.exec(className || '');
                return !inline && match ? (
                  <SyntaxHighlighter
                    language={match[1]}
                    PreTag="div"
                    {...props}
                  >
                    {String(children).replace(/\n$/, '')}
                  </SyntaxHighlighter>
                ) : (
                  <code className={className} {...props}>
                    {children}
                  </code>
                );
              }
            }}
          >
            {message.content}
          </ReactMarkdown>
        ) : (
          <p className="whitespace-pre-wrap">{message.content}</p>
        )}

        <div className="text-xs mt-2 opacity-70">
          {message.timestamp.toLocaleTimeString()}
        </div>
      </div>
    </div>
  );
}
```

### Installation
```bash
npm install react-markdown react-syntax-highlighter
npm install --save-dev @types/react-syntax-highlighter
```

## Example 5: Chat Input with Features

### Enhanced Input Component
```typescript
'use client';

import { useState, useRef } from 'react';

interface EnhancedChatInputProps {
  onSend: (message: string) => void;
  disabled?: boolean;
}

export function EnhancedChatInput({ onSend, disabled }: EnhancedChatInputProps) {
  const [value, setValue] = useState('');
  const textareaRef = useRef<HTMLTextAreaElement>(null);

  const handleSend = () => {
    if (value.trim() && !disabled) {
      onSend(value);
      setValue('');
      if (textareaRef.current) {
        textareaRef.current.style.height = 'auto';
      }
    }
  };

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      handleSend();
    }
  };

  const handleInput = (e: React.ChangeEvent<HTMLTextAreaElement>) => {
    setValue(e.target.value);

    // Auto-resize textarea
    e.target.style.height = 'auto';
    e.target.style.height = e.target.scrollHeight + 'px';
  };

  return (
    <div className="flex items-end gap-2 p-4 border-t bg-white">
      <textarea
        ref={textareaRef}
        value={value}
        onChange={handleInput}
        onKeyDown={handleKeyDown}
        placeholder="Type a message... (Shift+Enter for new line)"
        disabled={disabled}
        rows={1}
        className="flex-1 resize-none p-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 max-h-32 overflow-y-auto"
      />

      <button
        onClick={handleSend}
        disabled={disabled || !value.trim()}
        className="px-4 py-2 bg-blue-500 text-white rounded-lg hover:bg-blue-600 disabled:bg-gray-300 disabled:cursor-not-allowed"
      >
        Send
      </button>
    </div>
  );
}
```

## Example 6: Chat with User Context

### Context-Aware Chat
```typescript
'use client';

import { useChatKit } from '@/hooks/useChatKit';
import { useAuth } from '@/lib/auth';

export function ContextAwareChat() {
  const { user } = useAuth();
  const { messages, sendMessage, isStreaming } = useChatKit();

  return (
    <div className="h-screen flex flex-col">
      {/* Header */}
      <div className="bg-blue-500 text-white p-4 flex justify-between items-center">
        <h1 className="text-xl font-bold">Task Assistant</h1>
        <div className="text-sm">
          Logged in as {user?.name || 'Guest'}
        </div>
      </div>

      {/* Messages */}
      <div className="flex-1 overflow-y-auto">
        {messages.length === 0 ? (
          <div className="flex items-center justify-center h-full text-gray-500">
            <div className="text-center">
              <p className="text-lg mb-2">👋 Hello, {user?.name}!</p>
              <p>How can I help you manage your tasks today?</p>
            </div>
          </div>
        ) : (
          messages.map(msg => (
            <MessageItem key={msg.id} message={msg} />
          ))
        )}
      </div>

      {/* Input */}
      <ChatInput onSend={sendMessage} disabled={isStreaming} />
    </div>
  );
}
```

## Example 7: Testing Chat Components

### Unit Tests
```typescript
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import { useChatKit } from '@/hooks/useChatKit';
import { ChatContainer } from '@/components/chat/ChatContainer';

// Mock the hook
jest.mock('@/hooks/useChatKit');

describe('ChatContainer', () => {
  const mockSendMessage = jest.fn();

  beforeEach(() => {
    (useChatKit as jest.Mock).mockReturnValue({
      messages: [
        {
          id: '1',
          role: 'user',
          content: 'Hello',
          timestamp: new Date()
        },
        {
          id: '2',
          role: 'assistant',
          content: 'Hi there!',
          timestamp: new Date()
        }
      ],
      isStreaming: false,
      sendMessage: mockSendMessage
    });
  });

  it('renders messages', () => {
    render(<ChatContainer />);

    expect(screen.getByText('Hello')).toBeInTheDocument();
    expect(screen.getByText('Hi there!')).toBeInTheDocument();
  });

  it('sends message on input', async () => {
    render(<ChatContainer />);

    const input = screen.getByPlaceholderText('Type a message...');
    fireEvent.change(input, { target: { value: 'Test message' } });
    fireEvent.keyPress(input, { key: 'Enter', code: 13 });

    await waitFor(() => {
      expect(mockSendMessage).toHaveBeenCalledWith('Test message');
    });
  });

  it('disables input while streaming', () => {
    (useChatKit as jest.Mock).mockReturnValue({
      messages: [],
      isStreaming: true,
      sendMessage: mockSendMessage
    });

    render(<ChatContainer />);

    const input = screen.getByPlaceholderText('Type a message...');
    expect(input).toBeDisabled();
  });
});
```

### Integration Test with SSE
```typescript
import { renderHook, act } from '@testing-library/react';
import { useChatKit } from '@/hooks/useChatKit';

// Mock EventSource
global.EventSource = jest.fn().mockImplementation(() => ({
  addEventListener: jest.fn(),
  removeEventListener: jest.fn(),
  close: jest.fn(),
  onmessage: null,
  onerror: null
}));

describe('useChatKit SSE', () => {
  it('handles streaming messages', async () => {
    const { result } = renderHook(() => useChatKit());

    act(() => {
      result.current.sendMessage('Hello');
    });

    // Simulate SSE events
    const eventSource = (EventSource as jest.Mock).mock.results[0].value;

    act(() => {
      eventSource.onmessage({ data: 'Hello' });
      eventSource.onmessage({ data: ' there' });
      eventSource.onmessage({ data: '[DONE]' });
    });

    expect(result.current.messages).toHaveLength(2);
    expect(result.current.messages[1].content).toBe('Hello there');
    expect(result.current.isStreaming).toBe(false);
  });
});
```

## Example 8: Responsive Chat Layout

### Mobile-Friendly Chat
```typescript
'use client';

export function ResponsiveChat() {
  const { messages, sendMessage, isStreaming } = useChatKit();

  return (
    <div className="h-screen flex flex-col max-w-4xl mx-auto">
      {/* Header - Hidden on mobile when keyboard is open */}
      <div className="bg-gradient-to-r from-blue-500 to-blue-600 text-white p-4 md:p-6">
        <h1 className="text-lg md:text-2xl font-bold">
          Task Assistant
        </h1>
        <p className="text-sm md:text-base opacity-90">
          Powered by AI
        </p>
      </div>

      {/* Messages - Scrollable area */}
      <div className="flex-1 overflow-y-auto px-4 md:px-6 py-4 bg-gray-50">
        {messages.map(msg => (
          <div
            key={msg.id}
            className={`mb-4 ${
              msg.role === 'user' ? 'text-right' : 'text-left'
            }`}
          >
            <div
              className={`inline-block max-w-[85%] md:max-w-[70%] p-3 md:p-4 rounded-2xl ${
                msg.role === 'user'
                  ? 'bg-blue-500 text-white rounded-br-none'
                  : 'bg-white text-gray-900 shadow-sm rounded-bl-none'
              }`}
            >
              {msg.content}
            </div>
          </div>
        ))}
      </div>

      {/* Input - Fixed at bottom */}
      <div className="bg-white border-t p-4 md:p-6 safe-area-bottom">
        <div className="flex gap-2">
          <input
            type="text"
            placeholder="Type your message..."
            disabled={isStreaming}
            className="flex-1 p-3 border rounded-full focus:outline-none focus:ring-2 focus:ring-blue-500"
            onKeyPress={(e) => {
              if (e.key === 'Enter' && e.currentTarget.value) {
                sendMessage(e.currentTarget.value);
                e.currentTarget.value = '';
              }
            }}
          />
          <button
            disabled={isStreaming}
            className="px-6 py-3 bg-blue-500 text-white rounded-full hover:bg-blue-600 disabled:bg-gray-300"
          >
            Send
          </button>
        </div>
      </div>
    </div>
  );
}
```

### CSS for Safe Area
```css
.safe-area-bottom {
  padding-bottom: env(safe-area-inset-bottom);
}
```
