# Conversation Management - Sidebar and CRUD

## Overview
This skill implements a conversation history sidebar with full CRUD operations, allowing users to create, list, switch between, and delete conversations in the chat interface.

## When to Use This Skill
- Use when adding conversation history sidebar to chat UI
- Use when implementing conversation switching functionality
- Use when building conversation list with recent conversations
- Use when adding conversation delete and rename features

## Prerequisites
- Next.js 16+ with App Router installed
- ChatKit frontend components set up (chatkit-frontend skill)
- ChatKit backend with conversation endpoints (chatkit-backend skill)
- Better Auth configured for user context
- useChatKit hook implemented

## Setup Steps

### 1. Create Conversation State Hook
Create `frontend/hooks/useConversations.ts`:
```typescript
'use client';

import { useState, useEffect, useCallback } from 'react';

export interface Conversation {
  id: string;
  title: string;
  created_at: string;
  updated_at: string;
}

export interface UseConversationsReturn {
  conversations: Conversation[];
  currentConversationId: string | null;
  isLoading: boolean;
  createConversation: (title?: string) => Promise<string>;
  deleteConversation: (id: string) => Promise<void>;
  switchConversation: (id: string) => void;
  refreshConversations: () => Promise<void>;
}

export function useConversations(): UseConversationsReturn {
  const [conversations, setConversations] = useState<Conversation[]>([]);
  const [currentConversationId, setCurrentConversationId] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(false);

  // Load conversations on mount
  useEffect(() => {
    loadConversations();
  }, []);

  const loadConversations = async () => {
    setIsLoading(true);
    try {
      const token = getAuthToken();
      const response = await fetch('/api/conversations', {
        headers: {
          'Authorization': `Bearer ${token}`
        }
      });

      if (response.ok) {
        const data = await response.json();
        setConversations(data.conversations || []);

        // Set first conversation as current if none selected
        if (!currentConversationId && data.conversations.length > 0) {
          setCurrentConversationId(data.conversations[0].id);
        }
      }
    } catch (error) {
      console.error('Failed to load conversations:', error);
    } finally {
      setIsLoading(false);
    }
  };

  const createConversation = useCallback(async (title: string = 'New Conversation'): Promise<string> => {
    try {
      const token = getAuthToken();
      const response = await fetch('/api/conversations', {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${token}`,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({ title })
      });

      if (response.ok) {
        const newConv = await response.json();
        setConversations(prev => [newConv, ...prev]);
        setCurrentConversationId(newConv.id);
        return newConv.id;
      }

      throw new Error('Failed to create conversation');
    } catch (error) {
      console.error('Create conversation error:', error);
      throw error;
    }
  }, []);

  const deleteConversation = useCallback(async (id: string) => {
    try {
      const token = getAuthToken();
      const response = await fetch(`/api/conversations/${id}`, {
        method: 'DELETE',
        headers: {
          'Authorization': `Bearer ${token}`
        }
      });

      if (response.ok) {
        setConversations(prev => prev.filter(c => c.id !== id));

        // Switch to another conversation if deleting current
        if (currentConversationId === id) {
          const remaining = conversations.filter(c => c.id !== id);
          setCurrentConversationId(remaining.length > 0 ? remaining[0].id : null);
        }
      }
    } catch (error) {
      console.error('Delete conversation error:', error);
      throw error;
    }
  }, [currentConversationId, conversations]);

  const switchConversation = useCallback((id: string) => {
    setCurrentConversationId(id);
  }, []);

  const refreshConversations = useCallback(async () => {
    await loadConversations();
  }, []);

  return {
    conversations,
    currentConversationId,
    isLoading,
    createConversation,
    deleteConversation,
    switchConversation,
    refreshConversations
  };
}

function getAuthToken(): string {
  return localStorage.getItem('auth_token') || '';
}
```

### 2. Create Conversation Sidebar Component
Create `frontend/components/chat/ConversationSidebar.tsx`:
```typescript
'use client';

import { useState } from 'react';
import { Conversation } from '@/hooks/useConversations';

interface ConversationSidebarProps {
  conversations: Conversation[];
  currentConversationId: string | null;
  onSelect: (id: string) => void;
  onDelete: (id: string) => void;
  onCreate: () => void;
  isLoading?: boolean;
}

export function ConversationSidebar({
  conversations,
  currentConversationId,
  onSelect,
  onDelete,
  onCreate,
  isLoading
}: ConversationSidebarProps) {
  const [deleteConfirm, setDeleteConfirm] = useState<string | null>(null);

  const handleDelete = async (id: string, e: React.MouseEvent) => {
    e.stopPropagation();

    if (deleteConfirm === id) {
      await onDelete(id);
      setDeleteConfirm(null);
    } else {
      setDeleteConfirm(id);
      setTimeout(() => setDeleteConfirm(null), 3000);
    }
  };

  return (
    <div className="w-64 bg-gray-50 border-r border-gray-200 flex flex-col h-full">
      {/* Header */}
      <div className="p-4 border-b border-gray-200">
        <h2 className="text-lg font-semibold text-gray-900 mb-3">
          Conversations
        </h2>
        <button
          onClick={onCreate}
          className="w-full px-4 py-2 bg-blue-500 text-white rounded-lg hover:bg-blue-600 transition-colors"
        >
          + New Chat
        </button>
      </div>

      {/* Conversation List */}
      <div className="flex-1 overflow-y-auto">
        {isLoading ? (
          <div className="p-4 text-center text-gray-500">
            Loading conversations...
          </div>
        ) : conversations.length === 0 ? (
          <div className="p-4 text-center text-gray-500">
            No conversations yet.
            <br />
            Start a new chat!
          </div>
        ) : (
          <div className="space-y-1 p-2">
            {conversations.map(conv => (
              <div
                key={conv.id}
                onClick={() => onSelect(conv.id)}
                className={`
                  group relative p-3 rounded-lg cursor-pointer transition-colors
                  ${currentConversationId === conv.id
                    ? 'bg-blue-100 border border-blue-200'
                    : 'hover:bg-gray-100'
                  }
                `}
              >
                <div className="flex items-start justify-between">
                  <div className="flex-1 min-w-0">
                    <h3 className="text-sm font-medium text-gray-900 truncate">
                      {conv.title}
                    </h3>
                    <p className="text-xs text-gray-500 mt-1">
                      {formatDate(conv.updated_at)}
                    </p>
                  </div>

                  {/* Delete Button */}
                  <button
                    onClick={(e) => handleDelete(conv.id, e)}
                    className={`
                      ml-2 p-1 rounded opacity-0 group-hover:opacity-100
                      transition-opacity
                      ${deleteConfirm === conv.id
                        ? 'bg-red-500 text-white'
                        : 'hover:bg-gray-200 text-gray-600'
                      }
                    `}
                    title={deleteConfirm === conv.id ? 'Click again to confirm' : 'Delete'}
                  >
                    <svg
                      className="w-4 h-4"
                      fill="none"
                      stroke="currentColor"
                      viewBox="0 0 24 24"
                    >
                      <path
                        strokeLinecap="round"
                        strokeLinejoin="round"
                        strokeWidth={2}
                        d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"
                      />
                    </svg>
                  </button>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}

function formatDate(dateString: string): string {
  const date = new Date(dateString);
  const now = new Date();
  const diffMs = now.getTime() - date.getTime();
  const diffMins = Math.floor(diffMs / 60000);
  const diffHours = Math.floor(diffMs / 3600000);
  const diffDays = Math.floor(diffMs / 86400000);

  if (diffMins < 1) return 'Just now';
  if (diffMins < 60) return `${diffMins}m ago`;
  if (diffHours < 24) return `${diffHours}h ago`;
  if (diffDays < 7) return `${diffDays}d ago`;

  return date.toLocaleDateString();
}
```

### 3. Update Chat Container
Update `frontend/components/chat/ChatContainer.tsx`:
```typescript
'use client';

import { MainContainer, ChatContainer as ChatUIContainer } from '@chatscope/chat-ui-kit-react';
import { MessageList } from './MessageList';
import { ChatInput } from './ChatInput';
import { ConversationSidebar } from './ConversationSidebar';
import { useChatKit } from '@/hooks/useChatKit';
import { useConversations } from '@/hooks/useConversations';

export function ChatContainer() {
  const {
    conversations,
    currentConversationId,
    isLoading: isLoadingConversations,
    createConversation,
    deleteConversation,
    switchConversation
  } = useConversations();

  const { messages, isStreaming, sendMessage } = useChatKit(currentConversationId);

  const handleCreateConversation = async () => {
    await createConversation('New Chat');
  };

  return (
    <div className="flex h-[calc(100vh-4rem)] w-full">
      {/* Sidebar */}
      <ConversationSidebar
        conversations={conversations}
        currentConversationId={currentConversationId}
        onSelect={switchConversation}
        onDelete={deleteConversation}
        onCreate={handleCreateConversation}
        isLoading={isLoadingConversations}
      />

      {/* Chat Area */}
      <div className="flex-1">
        <MainContainer>
          <ChatUIContainer>
            <MessageList messages={messages} isStreaming={isStreaming} />
            <ChatInput onSend={sendMessage} disabled={isStreaming} />
          </ChatUIContainer>
        </MainContainer>
      </div>
    </div>
  );
}
```

### 4. Add Mobile Responsive Sidebar
Create `frontend/components/chat/MobileSidebar.tsx`:
```typescript
'use client';

import { useState } from 'react';
import { ConversationSidebar } from './ConversationSidebar';

export function MobileSidebar({ children, ...sidebarProps }) {
  const [isOpen, setIsOpen] = useState(false);

  return (
    <>
      {/* Mobile Menu Button */}
      <button
        onClick={() => setIsOpen(true)}
        className="md:hidden fixed top-4 left-4 z-40 p-2 bg-white rounded-lg shadow-lg"
      >
        <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 6h16M4 12h16M4 18h16" />
        </svg>
      </button>

      {/* Sidebar Overlay */}
      {isOpen && (
        <div
          className="md:hidden fixed inset-0 bg-black bg-opacity-50 z-40"
          onClick={() => setIsOpen(false)}
        />
      )}

      {/* Sidebar */}
      <div
        className={`
          fixed md:relative inset-y-0 left-0 z-50 md:z-0
          transform transition-transform duration-300 ease-in-out
          ${isOpen ? 'translate-x-0' : '-translate-x-full md:translate-x-0'}
        `}
      >
        <ConversationSidebar {...sidebarProps} />
      </div>

      {/* Close overlay on mobile when selecting conversation */}
      <div onClick={() => setIsOpen(false)}>
        {children}
      </div>
    </>
  );
}
```

## Key Files Created

| File | Purpose |
|------|---------|
| frontend/hooks/useConversations.ts | Conversation state management hook |
| frontend/components/chat/ConversationSidebar.tsx | Sidebar UI component |
| frontend/components/chat/MobileSidebar.tsx | Mobile-responsive sidebar wrapper |
| frontend/components/chat/ChatContainer.tsx | Updated chat container with sidebar |

## Dependencies

No new dependencies required - uses existing ChatKit and Next.js setup.

## Validation
Run: `.claude/skills/conversation-management/validation.sh`

Expected output:
```
✓ useConversations hook exists
✓ ConversationSidebar component exists
✓ ChatContainer integrated with sidebar
✓ Conversation list displays correctly
✓ Create conversation works
✓ Delete conversation works
✓ Switch conversation works
```

## Troubleshooting

### Issue: Conversations not loading
**Solution**: Verify backend `/api/conversations` endpoint is accessible and returns correct format

### Issue: Delete button not appearing
**Solution**: Check that group-hover CSS classes are working and button has proper opacity transitions

### Issue: Current conversation not highlighting
**Solution**: Verify `currentConversationId` matches conversation IDs from backend

### Issue: Mobile sidebar not closing
**Solution**: Ensure click handlers are properly propagating and state is updating

## Features

### Conversation List Features
- ✓ Display all user conversations
- ✓ Show conversation titles
- ✓ Show last updated time
- ✓ Highlight current conversation
- ✓ Sort by most recent

### CRUD Operations
- ✓ Create new conversation
- ✓ Delete conversation (with confirmation)
- ✓ Switch between conversations
- ✓ Auto-load first conversation

### UI/UX Features
- ✓ Loading states
- ✓ Empty state message
- ✓ Hover effects
- ✓ Delete confirmation
- ✓ Mobile responsive
- ✓ Smooth transitions

## Next Steps
After completing this skill:
1. Test conversation creation
2. Test switching between conversations
3. Test conversation deletion
4. Test on mobile devices
5. Consider adding conversation renaming feature
6. Consider adding conversation search
