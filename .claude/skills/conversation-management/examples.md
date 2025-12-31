# Conversation Management - Examples

## Example 1: Basic Conversation Sidebar

### Simple Implementation
```typescript
'use client';

import { useConversations } from '@/hooks/useConversations';

export function SimpleConversationList() {
  const {
    conversations,
    currentConversationId,
    switchConversation,
    createConversation,
    deleteConversation
  } = useConversations();

  return (
    <div className="w-64 bg-gray-50 p-4">
      <button
        onClick={() => createConversation()}
        className="w-full mb-4 px-4 py-2 bg-blue-500 text-white rounded"
      >
        New Chat
      </button>

      <div className="space-y-2">
        {conversations.map(conv => (
          <div
            key={conv.id}
            onClick={() => switchConversation(conv.id)}
            className={`
              p-3 rounded cursor-pointer
              ${currentConversationId === conv.id ? 'bg-blue-100' : 'hover:bg-gray-100'}
            `}
          >
            <div className="flex justify-between items-start">
              <span className="font-medium">{conv.title}</span>
              <button
                onClick={(e) => {
                  e.stopPropagation();
                  deleteConversation(conv.id);
                }}
                className="text-red-500 hover:text-red-700"
              >
                ×
              </button>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
```

## Example 2: Conversation with Rename

### Editable Conversation Title
```typescript
'use client';

import { useState } from 'react';

interface ConversationItemProps {
  conversation: Conversation;
  isActive: boolean;
  onSelect: () => void;
  onDelete: () => void;
  onRename: (id: string, newTitle: string) => void;
}

export function ConversationItem({
  conversation,
  isActive,
  onSelect,
  onDelete,
  onRename
}: ConversationItemProps) {
  const [isEditing, setIsEditing] = useState(false);
  const [editTitle, setEditTitle] = useState(conversation.title);

  const handleRename = () => {
    if (editTitle.trim() !== conversation.title) {
      onRename(conversation.id, editTitle.trim());
    }
    setIsEditing(false);
  };

  return (
    <div
      className={`
        group p-3 rounded-lg cursor-pointer
        ${isActive ? 'bg-blue-100' : 'hover:bg-gray-100'}
      `}
      onClick={onSelect}
    >
      {isEditing ? (
        <input
          type="text"
          value={editTitle}
          onChange={(e) => setEditTitle(e.target.value)}
          onBlur={handleRename}
          onKeyPress={(e) => e.key === 'Enter' && handleRename()}
          onClick={(e) => e.stopPropagation()}
          autoFocus
          className="w-full px-2 py-1 text-sm border rounded"
        />
      ) : (
        <div className="flex items-center justify-between">
          <span className="flex-1 truncate">{conversation.title}</span>

          <div className="flex gap-1 opacity-0 group-hover:opacity-100">
            <button
              onClick={(e) => {
                e.stopPropagation();
                setIsEditing(true);
              }}
              className="p-1 hover:bg-gray-200 rounded"
              title="Rename"
            >
              <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15.232 5.232l3.536 3.536m-2.036-5.036a2.5 2.5 0 113.536 3.536L6.5 21.036H3v-3.572L16.732 3.732z" />
              </svg>
            </button>

            <button
              onClick={(e) => {
                e.stopPropagation();
                onDelete();
              }}
              className="p-1 hover:bg-red-100 text-red-500 rounded"
              title="Delete"
            >
              <svg className="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
              </svg>
            </button>
          </div>
        </div>
      )}

      <p className="text-xs text-gray-500 mt-1">
        {formatDate(conversation.updated_at)}
      </p>
    </div>
  );
}

// Add to useConversations hook
export function useConversations() {
  // ... existing code ...

  const renameConversation = useCallback(async (id: string, newTitle: string) => {
    try {
      const token = getAuthToken();
      const response = await fetch(`/api/conversations/${id}`, {
        method: 'PATCH',
        headers: {
          'Authorization': `Bearer ${token}`,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({ title: newTitle })
      });

      if (response.ok) {
        setConversations(prev =>
          prev.map(c => c.id === id ? { ...c, title: newTitle } : c)
        );
      }
    } catch (error) {
      console.error('Rename conversation error:', error);
    }
  }, []);

  return {
    // ... existing returns ...
    renameConversation
  };
}
```

## Example 3: Conversation Search

### Search Functionality
```typescript
'use client';

import { useState, useMemo } from 'react';

export function SearchableConversationList() {
  const { conversations, currentConversationId, switchConversation } = useConversations();
  const [searchQuery, setSearchQuery] = useState('');

  const filteredConversations = useMemo(() => {
    if (!searchQuery.trim()) return conversations;

    const query = searchQuery.toLowerCase();
    return conversations.filter(conv =>
      conv.title.toLowerCase().includes(query)
    );
  }, [conversations, searchQuery]);

  return (
    <div className="w-64 bg-gray-50 flex flex-col h-full">
      {/* Search Bar */}
      <div className="p-4 border-b">
        <div className="relative">
          <input
            type="text"
            placeholder="Search conversations..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="w-full pl-10 pr-4 py-2 border rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500"
          />
          <svg
            className="absolute left-3 top-2.5 w-5 h-5 text-gray-400"
            fill="none"
            stroke="currentColor"
            viewBox="0 0 24 24"
          >
            <path
              strokeLinecap="round"
              strokeLinejoin="round"
              strokeWidth={2}
              d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"
            />
          </svg>
        </div>
      </div>

      {/* Filtered List */}
      <div className="flex-1 overflow-y-auto p-2">
        {filteredConversations.length === 0 ? (
          <div className="text-center text-gray-500 mt-4">
            No conversations found
          </div>
        ) : (
          filteredConversations.map(conv => (
            <ConversationItem
              key={conv.id}
              conversation={conv}
              isActive={currentConversationId === conv.id}
              onSelect={() => switchConversation(conv.id)}
            />
          ))
        )}
      </div>
    </div>
  );
}
```

## Example 4: Conversation with Message Count

### Display Message Count Badge
```typescript
interface ConversationWithCount extends Conversation {
  message_count?: number;
}

export function ConversationItemWithBadge({ conversation }: { conversation: ConversationWithCount }) {
  return (
    <div className="p-3 rounded-lg hover:bg-gray-100 cursor-pointer">
      <div className="flex items-center justify-between">
        <h3 className="font-medium truncate flex-1">{conversation.title}</h3>

        {conversation.message_count && conversation.message_count > 0 && (
          <span className="ml-2 px-2 py-1 text-xs bg-blue-100 text-blue-700 rounded-full">
            {conversation.message_count}
          </span>
        )}
      </div>

      <p className="text-xs text-gray-500 mt-1">
        {formatDate(conversation.updated_at)}
      </p>
    </div>
  );
}

// Fetch conversations with counts
async function loadConversationsWithCounts() {
  const response = await fetch('/api/conversations?include_counts=true', {
    headers: {
      'Authorization': `Bearer ${token}`
    }
  });

  const data = await response.json();
  return data.conversations;
}
```

## Example 5: Drag to Reorder Conversations

### Draggable Conversation List
```typescript
'use client';

import { DragDropContext, Droppable, Draggable } from 'react-beautiful-dnd';
import { useState } from 'react';

export function ReorderableConversationList() {
  const [conversations, setConversations] = useState<Conversation[]>([]);

  const handleDragEnd = (result: any) => {
    if (!result.destination) return;

    const items = Array.from(conversations);
    const [reorderedItem] = items.splice(result.source.index, 1);
    items.splice(result.destination.index, 0, reorderedItem);

    setConversations(items);

    // Optionally save order to backend
    saveConversationOrder(items.map(c => c.id));
  };

  return (
    <DragDropContext onDragEnd={handleDragEnd}>
      <Droppable droppableId="conversations">
        {(provided) => (
          <div
            {...provided.droppableProps}
            ref={provided.innerRef}
            className="space-y-2"
          >
            {conversations.map((conv, index) => (
              <Draggable key={conv.id} draggableId={conv.id} index={index}>
                {(provided, snapshot) => (
                  <div
                    ref={provided.innerRef}
                    {...provided.draggableProps}
                    {...provided.dragHandleProps}
                    className={`
                      p-3 rounded-lg bg-white
                      ${snapshot.isDragging ? 'shadow-lg' : ''}
                    `}
                  >
                    <ConversationItem conversation={conv} />
                  </div>
                )}
              </Draggable>
            ))}
            {provided.placeholder}
          </div>
        )}
      </Droppable>
    </DragDropContext>
  );
}
```

## Example 6: Conversation with Last Message Preview

### Show Last Message
```typescript
interface ConversationWithPreview extends Conversation {
  last_message?: {
    role: string;
    content: string;
    created_at: string;
  };
}

export function ConversationPreview({ conversation }: { conversation: ConversationWithPreview }) {
  return (
    <div className="p-3 rounded-lg hover:bg-gray-100 cursor-pointer">
      <h3 className="font-medium truncate">{conversation.title}</h3>

      {conversation.last_message && (
        <p className="text-sm text-gray-600 truncate mt-1">
          {conversation.last_message.role === 'user' ? 'You: ' : 'AI: '}
          {conversation.last_message.content}
        </p>
      )}

      <p className="text-xs text-gray-500 mt-1">
        {formatDate(conversation.updated_at)}
      </p>
    </div>
  );
}

// Backend endpoint to include last message
@router.get("/conversations")
async def list_conversations(
    include_preview: bool = False,
    user_id: str = Depends(get_current_user),
    session: Session = Depends(get_session)
):
    conversations = session.exec(
        select(Conversation).where(
            Conversation.user_id == user_id
        ).order_by(Conversation.updated_at.desc())
    ).all()

    result = []
    for conv in conversations:
        conv_dict = conv.dict()

        if include_preview:
            last_msg = session.exec(
                select(Message).where(
                    Message.conversation_id == conv.id
                ).order_by(Message.created_at.desc()).limit(1)
            ).first()

            if last_msg:
                conv_dict['last_message'] = {
                    'role': last_msg.role,
                    'content': last_msg.content,
                    'created_at': last_msg.created_at.isoformat()
                }

        result.append(conv_dict)

    return {"conversations": result}
```

## Example 7: Keyboard Navigation

### Keyboard Shortcuts
```typescript
'use client';

import { useEffect } from 'react';

export function KeyboardNavigableConversations() {
  const {
    conversations,
    currentConversationId,
    switchConversation,
    createConversation
  } = useConversations();

  useEffect(() => {
    const handleKeyPress = (e: KeyboardEvent) => {
      // Cmd/Ctrl + N: New conversation
      if ((e.metaKey || e.ctrlKey) && e.key === 'n') {
        e.preventDefault();
        createConversation();
        return;
      }

      // Cmd/Ctrl + K: Search conversations
      if ((e.metaKey || e.ctrlKey) && e.key === 'k') {
        e.preventDefault();
        // Open search modal
        return;
      }

      // Up/Down arrows: Navigate conversations
      if (e.key === 'ArrowUp' || e.key === 'ArrowDown') {
        const currentIndex = conversations.findIndex(
          c => c.id === currentConversationId
        );

        if (currentIndex >= 0) {
          const newIndex = e.key === 'ArrowUp'
            ? Math.max(0, currentIndex - 1)
            : Math.min(conversations.length - 1, currentIndex + 1);

          switchConversation(conversations[newIndex].id);
        }
      }
    };

    window.addEventListener('keydown', handleKeyPress);
    return () => window.removeEventListener('keydown', handleKeyPress);
  }, [conversations, currentConversationId]);

  return (
    <div>
      <div className="text-xs text-gray-500 p-4 border-b">
        <kbd>⌘N</kbd> New chat · <kbd>⌘K</kbd> Search · <kbd>↑↓</kbd> Navigate
      </div>
      {/* Conversation list */}
    </div>
  );
}
```

## Example 8: Conversation Context Menu

### Right-Click Menu
```typescript
'use client';

import { useState, useRef, useEffect } from 'react';

export function ConversationWithContextMenu({ conversation, onRename, onDelete, onDuplicate }) {
  const [showMenu, setShowMenu] = useState(false);
  const [menuPosition, setMenuPosition] = useState({ x: 0, y: 0 });
  const menuRef = useRef<HTMLDivElement>(null);

  const handleContextMenu = (e: React.MouseEvent) => {
    e.preventDefault();
    setMenuPosition({ x: e.clientX, y: e.clientY });
    setShowMenu(true);
  };

  useEffect(() => {
    const handleClickOutside = () => setShowMenu(false);
    document.addEventListener('click', handleClickOutside);
    return () => document.removeEventListener('click', handleClickOutside);
  }, []);

  return (
    <>
      <div
        onContextMenu={handleContextMenu}
        className="p-3 rounded-lg hover:bg-gray-100 cursor-pointer"
      >
        <h3 className="font-medium">{conversation.title}</h3>
      </div>

      {showMenu && (
        <div
          ref={menuRef}
          style={{
            position: 'fixed',
            left: menuPosition.x,
            top: menuPosition.y
          }}
          className="bg-white border rounded-lg shadow-lg py-1 z-50"
        >
          <button
            onClick={() => {
              onRename(conversation.id);
              setShowMenu(false);
            }}
            className="w-full text-left px-4 py-2 hover:bg-gray-100"
          >
            Rename
          </button>
          <button
            onClick={() => {
              onDuplicate(conversation.id);
              setShowMenu(false);
            }}
            className="w-full text-left px-4 py-2 hover:bg-gray-100"
          >
            Duplicate
          </button>
          <hr className="my-1" />
          <button
            onClick={() => {
              onDelete(conversation.id);
              setShowMenu(false);
            }}
            className="w-full text-left px-4 py-2 hover:bg-red-50 text-red-600"
          >
            Delete
          </button>
        </div>
      )}
    </>
  );
}
```

## Testing Examples

### Unit Tests
```typescript
import { renderHook, act } from '@testing-library/react';
import { useConversations } from '@/hooks/useConversations';

describe('useConversations', () => {
  it('creates a new conversation', async () => {
    const { result } = renderHook(() => useConversations());

    await act(async () => {
      const id = await result.current.createConversation('Test Chat');
      expect(id).toBeDefined();
    });

    expect(result.current.conversations).toHaveLength(1);
    expect(result.current.conversations[0].title).toBe('Test Chat');
  });

  it('deletes a conversation', async () => {
    const { result } = renderHook(() => useConversations());

    let convId: string;
    await act(async () => {
      convId = await result.current.createConversation();
    });

    await act(async () => {
      await result.current.deleteConversation(convId);
    });

    expect(result.current.conversations).toHaveLength(0);
  });

  it('switches between conversations', async () => {
    const { result } = renderHook(() => useConversations());

    let conv1, conv2;
    await act(async () => {
      conv1 = await result.current.createConversation('Chat 1');
      conv2 = await result.current.createConversation('Chat 2');
    });

    act(() => {
      result.current.switchConversation(conv1);
    });

    expect(result.current.currentConversationId).toBe(conv1);
  });
});
```
