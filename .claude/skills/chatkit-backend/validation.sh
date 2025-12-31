#!/bin/bash

# ChatKit Backend Validation Script

echo "🔍 Validating ChatKit Backend Setup..."
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Track validation status
ERRORS=0

# Check if in backend directory
if [ ! -f "backend/main.py" ]; then
    echo -e "${YELLOW}⚠${NC} Not in project root. Changing to project root..."
    cd ..
fi

# Check database models
echo "Checking database models..."

if [ -f "backend/models.py" ]; then
    echo -e "${GREEN}✓${NC} models.py exists"

    # Check for Conversation model
    if grep -q "class Conversation" backend/models.py; then
        echo -e "${GREEN}  ✓${NC} Conversation model defined"
    else
        echo -e "${RED}  ✗${NC} Conversation model not found"
        ERRORS=$((ERRORS + 1))
    fi

    # Check for Message model
    if grep -q "class Message" backend/models.py; then
        echo -e "${GREEN}  ✓${NC} Message model defined"
    else
        echo -e "${RED}  ✗${NC} Message model not found"
        ERRORS=$((ERRORS + 1))
    fi
else
    echo -e "${RED}✗${NC} models.py not found"
    ERRORS=$((ERRORS + 1))
fi

# Check database migrations
echo ""
echo "Checking database migrations..."

if [ -d "backend/alembic/versions" ]; then
    VERSION_COUNT=$(ls -1 backend/alembic/versions/*.py 2>/dev/null | wc -l)
    if [ $VERSION_COUNT -gt 0 ]; then
        echo -e "${GREEN}✓${NC} Alembic migrations exist (${VERSION_COUNT} versions)"

        # Check if conversation/message migration exists
        if grep -r "conversation\|message" backend/alembic/versions/ 2>/dev/null | grep -q "def upgrade"; then
            echo -e "${GREEN}  ✓${NC} Conversation/Message migration found"
        else
            echo -e "${YELLOW}  ⚠${NC} No conversation/message migration found"
            echo "     Run: alembic revision --autogenerate -m 'Add conversation models'"
        fi
    else
        echo -e "${YELLOW}⚠${NC} No migration files found"
        echo "   Run: alembic revision --autogenerate -m 'Add conversation models'"
    fi
else
    echo -e "${YELLOW}⚠${NC} Alembic not initialized"
    echo "   Run: alembic init alembic"
fi

# Check chat routes
echo ""
echo "Checking chat routes..."

if [ -f "backend/routes/chat.py" ]; then
    echo -e "${GREEN}✓${NC} routes/chat.py exists"

    # Check for SSE endpoint
    if grep -q "chat/stream" backend/routes/chat.py; then
        echo -e "${GREEN}  ✓${NC} SSE stream endpoint defined"
    else
        echo -e "${RED}  ✗${NC} SSE stream endpoint not found"
        ERRORS=$((ERRORS + 1))
    fi

    # Check for conversation endpoints
    ENDPOINTS=("/conversations" "create_conversation" "delete_conversation" "get_messages")
    for endpoint in "${ENDPOINTS[@]}"; do
        if grep -q "$endpoint" backend/routes/chat.py; then
            echo -e "${GREEN}  ✓${NC} Endpoint '$endpoint' defined"
        else
            echo -e "${RED}  ✗${NC} Endpoint '$endpoint' not found"
            ERRORS=$((ERRORS + 1))
        fi
    done

    # Check for StreamingResponse
    if grep -q "StreamingResponse" backend/routes/chat.py; then
        echo -e "${GREEN}  ✓${NC} StreamingResponse used for SSE"
    else
        echo -e "${RED}  ✗${NC} StreamingResponse not imported"
        ERRORS=$((ERRORS + 1))
    fi
else
    echo -e "${RED}✗${NC} routes/chat.py not found"
    echo "   Create backend/routes/chat.py"
    ERRORS=$((ERRORS + 1))
fi

# Check if routes are registered
echo ""
echo "Checking route registration..."

if [ -f "backend/main.py" ]; then
    if grep -q "chat" backend/main.py; then
        echo -e "${GREEN}✓${NC} Chat routes registered in main.py"
    else
        echo -e "${RED}✗${NC} Chat routes not registered in main.py"
        echo "   Add: app.include_router(chat.router, prefix='/api', tags=['chat'])"
        ERRORS=$((ERRORS + 1))
    fi
else
    echo -e "${RED}✗${NC} main.py not found"
    ERRORS=$((ERRORS + 1))
fi

# Check dependencies
echo ""
echo "Checking dependencies..."

REQUIRED_DEPS=("fastapi" "sqlmodel" "alembic")
for dep in "${REQUIRED_DEPS[@]}"; do
    if python -c "import $dep" 2>/dev/null; then
        echo -e "${GREEN}✓${NC} $dep installed"
    else
        echo -e "${RED}✗${NC} $dep not installed"
        echo "   Run: pip install $dep"
        ERRORS=$((ERRORS + 1))
    fi
done

# Check if FastAPI server is running
echo ""
echo "Checking FastAPI server..."

if curl -s http://localhost:8000/docs > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} FastAPI server responding"

    # Check SSE endpoint
    echo ""
    echo "Testing endpoints..."

    # Test /api/conversations endpoint
    if curl -s http://localhost:8000/api/conversations -H "Authorization: Bearer test" > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} Conversations endpoint accessible"
    else
        echo -e "${YELLOW}⚠${NC} Conversations endpoint not accessible (may need auth)"
    fi

    # Check if SSE endpoint exists (won't test without proper auth)
    if curl -s -I http://localhost:8000/api/chat/stream 2>&1 | grep -q "text/event-stream\|405\|401"; then
        echo -e "${GREEN}✓${NC} SSE endpoint registered"
    else
        echo -e "${YELLOW}⚠${NC} SSE endpoint may not be registered"
    fi
else
    echo -e "${YELLOW}⚠${NC} FastAPI server not running"
    echo "   Start with: uvicorn backend.main:app --reload --port 8000"
fi

# Check database connection
echo ""
echo "Checking database connection..."

cat > /tmp/test_db.py << 'EOF'
import sys
sys.path.insert(0, 'backend')

try:
    from db import engine
    from sqlmodel import SQLModel

    # Test connection
    with engine.connect() as conn:
        print("✓ Database connection successful")

    # Check if tables exist
    from sqlalchemy import inspect
    inspector = inspect(engine)
    tables = inspector.get_table_names()

    if "conversation" in tables:
        print("✓ Conversation table exists")
    else:
        print("✗ Conversation table not found")
        print("  Run: alembic upgrade head")

    if "message" in tables:
        print("✓ Message table exists")
    else:
        print("✗ Message table not found")
        print("  Run: alembic upgrade head")

except Exception as e:
    print(f"✗ Database connection failed: {e}")
    sys.exit(1)
EOF

if python /tmp/test_db.py 2>&1 | while read line; do
    if [[ $line == ✓* ]]; then
        echo -e "${GREEN}${line}${NC}"
    elif [[ $line == ✗* ]]; then
        echo -e "${RED}${line}${NC}"
    else
        echo "$line"
    fi
done; then
    :
else
    ERRORS=$((ERRORS + 1))
fi

rm /tmp/test_db.py

# Final summary
echo ""
echo "════════════════════════════════════════"
if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}✓ All validations passed!${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Test SSE endpoint:"
    echo "   curl -N 'http://localhost:8000/api/chat/stream?message=Hello' \\"
    echo "        -H 'Authorization: Bearer <token>'"
    echo ""
    echo "2. Test conversation creation:"
    echo "   curl -X POST http://localhost:8000/api/conversations \\"
    echo "        -H 'Authorization: Bearer <token>' \\"
    echo "        -H 'Content-Type: application/json' \\"
    echo "        -d '{\"title\": \"Test Chat\"}'"
    echo ""
    echo "3. Integrate with frontend (chatkit-frontend skill)"
    echo "4. Add conversation sidebar (conversation-management skill)"
    exit 0
else
    echo -e "${RED}✗ ${ERRORS} validation error(s) found${NC}"
    echo ""
    echo "Please fix the errors above and run validation again."
    exit 1
fi
