#!/bin/bash

# Conversation Management Validation Script

echo "🔍 Validating Conversation Management Setup..."
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Track validation status
ERRORS=0

# Check if in project root
if [ ! -d "frontend" ]; then
    echo -e "${RED}✗${NC} frontend directory not found"
    echo "   Run from project root"
    exit 1
fi

cd frontend

# Check useConversations hook
echo "Checking useConversations hook..."

if [ -f "hooks/useConversations.ts" ]; then
    echo -e "${GREEN}✓${NC} hooks/useConversations.ts exists"

    # Check hook exports
    REQUIRED_EXPORTS=(
        "useConversations"
        "createConversation"
        "deleteConversation"
        "switchConversation"
    )

    for export in "${REQUIRED_EXPORTS[@]}"; do
        if grep -q "$export" hooks/useConversations.ts; then
            echo -e "${GREEN}  ✓${NC} Function '$export' found"
        else
            echo -e "${RED}  ✗${NC} Function '$export' not found"
            ERRORS=$((ERRORS + 1))
        fi
    done
else
    echo -e "${RED}✗${NC} hooks/useConversations.ts not found"
    echo "   Create hooks/useConversations.ts"
    ERRORS=$((ERRORS + 1))
fi

# Check ConversationSidebar component
echo ""
echo "Checking ConversationSidebar component..."

if [ -f "components/chat/ConversationSidebar.tsx" ]; then
    echo -e "${GREEN}✓${NC} components/chat/ConversationSidebar.tsx exists"

    # Check component exports
    if grep -q "export function ConversationSidebar" components/chat/ConversationSidebar.tsx; then
        echo -e "${GREEN}  ✓${NC} ConversationSidebar component exported"
    else
        echo -e "${RED}  ✗${NC} ConversationSidebar component not exported"
        ERRORS=$((ERRORS + 1))
    fi

    # Check for required props
    REQUIRED_PROPS=("conversations" "currentConversationId" "onSelect" "onDelete" "onCreate")
    for prop in "${REQUIRED_PROPS[@]}"; do
        if grep -q "$prop" components/chat/ConversationSidebar.tsx; then
            echo -e "${GREEN}  ✓${NC} Prop '$prop' handled"
        else
            echo -e "${YELLOW}  ⚠${NC} Prop '$prop' may not be handled"
        fi
    done
else
    echo -e "${RED}✗${NC} components/chat/ConversationSidebar.tsx not found"
    echo "   Create components/chat/ConversationSidebar.tsx"
    ERRORS=$((ERRORS + 1))
fi

# Check ChatContainer integration
echo ""
echo "Checking ChatContainer integration..."

if [ -f "components/chat/ChatContainer.tsx" ]; then
    echo -e "${GREEN}✓${NC} components/chat/ChatContainer.tsx exists"

    # Check if sidebar is imported
    if grep -q "ConversationSidebar" components/chat/ChatContainer.tsx; then
        echo -e "${GREEN}  ✓${NC} ConversationSidebar imported"
    else
        echo -e "${RED}  ✗${NC} ConversationSidebar not imported"
        ERRORS=$((ERRORS + 1))
    fi

    # Check if useConversations is used
    if grep -q "useConversations" components/chat/ChatContainer.tsx; then
        echo -e "${GREEN}  ✓${NC} useConversations hook used"
    else
        echo -e "${RED}  ✗${NC} useConversations hook not used"
        ERRORS=$((ERRORS + 1))
    fi
else
    echo -e "${YELLOW}⚠${NC} components/chat/ChatContainer.tsx not found"
fi

# Check TypeScript compilation
echo ""
echo "Checking TypeScript compilation..."

if command -v tsc &> /dev/null; then
    if npx tsc --noEmit 2>&1 | grep -q "error TS"; then
        echo -e "${RED}✗${NC} TypeScript compilation errors found"
        echo "   Run: npx tsc --noEmit to see errors"
        ERRORS=$((ERRORS + 1))
    else
        echo -e "${GREEN}✓${NC} No TypeScript errors"
    fi
else
    echo -e "${YELLOW}⚠${NC} TypeScript compiler not found"
fi

# Check if Next.js server is running
echo ""
echo "Checking Next.js dev server..."

if curl -s http://localhost:3000 > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Next.js server responding"

    # Check chat page
    if curl -s http://localhost:3000/chat > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} Chat page accessible"
    else
        echo -e "${YELLOW}⚠${NC} Chat page not accessible"
    fi
else
    echo -e "${YELLOW}⚠${NC} Next.js server not running"
    echo "   Start with: npm run dev"
fi

# Check backend conversation endpoints
echo ""
echo "Checking backend conversation endpoints..."

if curl -s http://localhost:8000/api/conversations > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Conversations endpoint responding"
else
    echo -e "${YELLOW}⚠${NC} Conversations endpoint not accessible"
    echo "   Ensure backend is running and conversation routes are registered"
fi

# Check mobile responsiveness
echo ""
echo "Checking mobile responsiveness..."

if [ -f "components/chat/MobileSidebar.tsx" ]; then
    echo -e "${GREEN}✓${NC} MobileSidebar component exists"
else
    echo -e "${YELLOW}⚠${NC} MobileSidebar component not found (optional)"
fi

# Check styling
echo ""
echo "Checking Tailwind CSS classes..."

if [ -f "components/chat/ConversationSidebar.tsx" ]; then
    if grep -q "className" components/chat/ConversationSidebar.tsx; then
        echo -e "${GREEN}✓${NC} Tailwind classes used"
    else
        echo -e "${YELLOW}⚠${NC} No Tailwind classes found"
    fi
fi

# Integration test suggestions
echo ""
echo "Manual testing checklist:"
echo "  1. Visit http://localhost:3000/chat"
echo "  2. Click 'New Chat' button"
echo "  3. Verify new conversation appears in sidebar"
echo "  4. Click on a conversation to switch"
echo "  5. Hover over conversation to see delete button"
echo "  6. Click delete and verify conversation is removed"
echo "  7. Test on mobile device or resize browser"

cd ..

# Final summary
echo ""
echo "════════════════════════════════════════"
if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}✓ All validations passed!${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Test creating a conversation"
    echo "2. Test switching between conversations"
    echo "3. Test deleting a conversation"
    echo "4. Test on mobile viewport"
    echo ""
    echo "Feature enhancements to consider:"
    echo "- Add conversation rename functionality"
    echo "- Add conversation search"
    echo "- Add last message preview"
    echo "- Add keyboard shortcuts"
    echo "- Add conversation folders/tags"
    exit 0
else
    echo -e "${RED}✗ ${ERRORS} validation error(s) found${NC}"
    echo ""
    echo "Please fix the errors above and run validation again."
    exit 1
fi
