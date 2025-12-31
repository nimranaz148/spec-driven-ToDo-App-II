#!/bin/bash

# ChatKit Frontend Validation Script

echo "🔍 Validating ChatKit Frontend Setup..."
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

# Check Node.js and npm
echo "Checking Node.js and npm..."
if command -v node &> /dev/null; then
    NODE_VERSION=$(node --version)
    echo -e "${GREEN}✓${NC} Node.js ${NODE_VERSION} installed"
else
    echo -e "${RED}✗${NC} Node.js not installed"
    ERRORS=$((ERRORS + 1))
fi

# Check ChatKit dependencies
echo ""
echo "Checking ChatKit dependencies..."

cd frontend

if [ -f "package.json" ]; then
    if grep -q "@chatscope/chat-ui-kit-react" package.json; then
        echo -e "${GREEN}✓${NC} @chatscope/chat-ui-kit-react in package.json"
    else
        echo -e "${RED}✗${NC} @chatscope/chat-ui-kit-react not found"
        echo "   Run: npm install @chatscope/chat-ui-kit-react"
        ERRORS=$((ERRORS + 1))
    fi

    if grep -q "@chatscope/chat-ui-kit-styles" package.json; then
        echo -e "${GREEN}✓${NC} @chatscope/chat-ui-kit-styles in package.json"
    else
        echo -e "${RED}✗${NC} @chatscope/chat-ui-kit-styles not found"
        echo "   Run: npm install @chatscope/chat-ui-kit-styles"
        ERRORS=$((ERRORS + 1))
    fi
else
    echo -e "${RED}✗${NC} package.json not found"
    ERRORS=$((ERRORS + 1))
fi

# Check if node_modules exist
if [ -d "node_modules" ]; then
    if [ -d "node_modules/@chatscope/chat-ui-kit-react" ]; then
        echo -e "${GREEN}✓${NC} ChatKit packages installed"
    else
        echo -e "${YELLOW}⚠${NC} ChatKit packages not installed"
        echo "   Run: npm install"
    fi
else
    echo -e "${YELLOW}⚠${NC} node_modules not found"
    echo "   Run: npm install"
fi

# Check useChatKit hook
echo ""
echo "Checking useChatKit hook..."

if [ -f "hooks/useChatKit.ts" ]; then
    echo -e "${GREEN}✓${NC} hooks/useChatKit.ts exists"

    # Check hook exports
    if grep -q "export function useChatKit" hooks/useChatKit.ts; then
        echo -e "${GREEN}  ✓${NC} useChatKit function exported"
    else
        echo -e "${RED}  ✗${NC} useChatKit function not found"
        ERRORS=$((ERRORS + 1))
    fi

    # Check for SSE implementation
    if grep -q "EventSource" hooks/useChatKit.ts; then
        echo -e "${GREEN}  ✓${NC} EventSource implementation found"
    else
        echo -e "${RED}  ✗${NC} EventSource not implemented"
        ERRORS=$((ERRORS + 1))
    fi
else
    echo -e "${RED}✗${NC} hooks/useChatKit.ts not found"
    echo "   Create hooks/useChatKit.ts"
    ERRORS=$((ERRORS + 1))
fi

# Check chat components
echo ""
echo "Checking chat components..."

COMPONENTS=(
    "components/chat/ChatContainer.tsx"
    "components/chat/MessageList.tsx"
    "components/chat/ChatInput.tsx"
)

for component in "${COMPONENTS[@]}"; do
    if [ -f "$component" ]; then
        echo -e "${GREEN}✓${NC} $component exists"
    else
        echo -e "${RED}✗${NC} $component not found"
        ERRORS=$((ERRORS + 1))
    fi
done

# Check chat page
echo ""
echo "Checking chat page route..."

if [ -f "app/chat/page.tsx" ]; then
    echo -e "${GREEN}✓${NC} app/chat/page.tsx exists"

    if grep -q "ChatContainer" app/chat/page.tsx; then
        echo -e "${GREEN}  ✓${NC} ChatContainer imported in page"
    else
        echo -e "${YELLOW}  ⚠${NC} ChatContainer may not be used in page"
    fi
else
    echo -e "${RED}✗${NC} app/chat/page.tsx not found"
    echo "   Create app/chat/page.tsx"
    ERRORS=$((ERRORS + 1))
fi

# Check styles import
echo ""
echo "Checking ChatKit styles import..."

if [ -f "app/layout.tsx" ]; then
    if grep -q "@chatscope/chat-ui-kit-styles" app/layout.tsx; then
        echo -e "${GREEN}✓${NC} ChatKit styles imported in layout"
    else
        echo -e "${YELLOW}⚠${NC} ChatKit styles not imported in layout"
        echo "   Add: import '@chatscope/chat-ui-kit-styles/dist/default/styles.min.css'"
    fi
else
    echo -e "${YELLOW}⚠${NC} app/layout.tsx not found"
fi

# Check custom styles
if [ -f "styles/chat.css" ]; then
    echo -e "${GREEN}✓${NC} styles/chat.css exists"
else
    echo -e "${YELLOW}⚠${NC} styles/chat.css not found (optional)"
fi

# Check TypeScript configuration
echo ""
echo "Checking TypeScript configuration..."

if [ -f "tsconfig.json" ]; then
    echo -e "${GREEN}✓${NC} tsconfig.json exists"

    if grep -q '"strict": true' tsconfig.json; then
        echo -e "${GREEN}  ✓${NC} Strict mode enabled"
    fi
else
    echo -e "${YELLOW}⚠${NC} tsconfig.json not found"
fi

# Check if Next.js dev server is running
echo ""
echo "Checking Next.js dev server..."

if curl -s http://localhost:3000 > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Next.js server responding on port 3000"

    # Check if chat page is accessible
    if curl -s http://localhost:3000/chat > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} Chat page accessible at /chat"
    else
        echo -e "${YELLOW}⚠${NC} Chat page not accessible"
    fi
else
    echo -e "${YELLOW}⚠${NC} Next.js server not running"
    echo "   Start with: npm run dev"
fi

# Check SSE endpoint availability
echo ""
echo "Checking backend SSE endpoint..."

if curl -s http://localhost:8000/api/chat/stream > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} SSE endpoint responding"
else
    echo -e "${YELLOW}⚠${NC} SSE endpoint not accessible"
    echo "   Ensure backend is running and SSE endpoint is implemented"
    echo "   See: chatkit-backend skill"
fi

# Test TypeScript compilation
echo ""
echo "Testing TypeScript compilation..."

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

cd ..

# Final summary
echo ""
echo "════════════════════════════════════════"
if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}✓ All validations passed!${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Start Next.js: cd frontend && npm run dev"
    echo "2. Visit: http://localhost:3000/chat"
    echo "3. Test sending a message"
    echo "4. Verify streaming works"
    echo "5. Add conversation management (conversation-management skill)"
    echo ""
    echo "Test the chat:"
    echo "  1. Navigate to http://localhost:3000/chat"
    echo "  2. Type 'Hello' and press Enter"
    echo "  3. Verify streaming response appears"
    exit 0
else
    echo -e "${RED}✗ ${ERRORS} validation error(s) found${NC}"
    echo ""
    echo "Please fix the errors above and run validation again."
    exit 1
fi
