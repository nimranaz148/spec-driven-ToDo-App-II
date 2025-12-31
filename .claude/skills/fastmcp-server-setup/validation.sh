#!/bin/bash

# FastMCP Server Setup Validation Script

echo "🔍 Validating FastMCP Server Setup..."
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

# Check FastMCP installation
echo "Checking FastMCP installation..."
if python -c "import fastmcp" 2>/dev/null; then
    echo -e "${GREEN}✓${NC} FastMCP installed"
else
    echo -e "${RED}✗${NC} FastMCP not installed"
    echo "   Run: pip install fastmcp"
    ERRORS=$((ERRORS + 1))
fi

# Check MCP server file
echo ""
echo "Checking MCP server files..."

if [ -f "backend/mcp_server.py" ]; then
    echo -e "${GREEN}✓${NC} mcp_server.py exists"

    # Check for required tools
    REQUIRED_TOOLS=("get_tasks" "create_task" "update_task" "toggle_complete" "delete_task")
    for tool in "${REQUIRED_TOOLS[@]}"; do
        if grep -q "async def $tool" backend/mcp_server.py; then
            echo -e "${GREEN}  ✓${NC} Tool '$tool' defined"
        else
            echo -e "${RED}  ✗${NC} Tool '$tool' not found"
            ERRORS=$((ERRORS + 1))
        fi
    done
else
    echo -e "${RED}✗${NC} mcp_server.py not found"
    echo "   Create backend/mcp_server.py"
    ERRORS=$((ERRORS + 1))
fi

# Check MCP routes file
echo ""
echo "Checking MCP routes..."

if [ -f "backend/routes/mcp.py" ]; then
    echo -e "${GREEN}✓${NC} routes/mcp.py exists"
else
    echo -e "${YELLOW}⚠${NC} routes/mcp.py not found (optional)"
fi

# Check if MCP routes are registered in main.py
if [ -f "backend/main.py" ]; then
    if grep -q "mcp" backend/main.py; then
        echo -e "${GREEN}✓${NC} MCP routes registered in main.py"
    else
        echo -e "${YELLOW}⚠${NC} MCP routes may not be registered in main.py"
    fi
fi

# Check database models
echo ""
echo "Checking database dependencies..."

if python -c "import sqlmodel" 2>/dev/null; then
    echo -e "${GREEN}✓${NC} SQLModel installed"
else
    echo -e "${RED}✗${NC} SQLModel not installed"
    echo "   Run: pip install sqlmodel"
    ERRORS=$((ERRORS + 1))
fi

# Check if models file exists
if [ -f "backend/models.py" ]; then
    if grep -q "class Task" backend/models.py; then
        echo -e "${GREEN}✓${NC} Task model defined"
    else
        echo -e "${RED}✗${NC} Task model not found in models.py"
        ERRORS=$((ERRORS + 1))
    fi
else
    echo -e "${RED}✗${NC} models.py not found"
    ERRORS=$((ERRORS + 1))
fi

# Check authentication
echo ""
echo "Checking authentication setup..."

if [ -f "backend/auth.py" ]; then
    echo -e "${GREEN}✓${NC} auth.py exists"
else
    echo -e "${YELLOW}⚠${NC} auth.py not found"
    echo "   MCP tools should verify user authentication"
fi

# Test MCP server initialization
echo ""
echo "Testing MCP server initialization..."

cat > /tmp/test_mcp.py << 'EOF'
import sys
sys.path.insert(0, 'backend')

try:
    from mcp_server import mcp

    # Check if server is initialized
    if mcp:
        print(f"✓ MCP server initialized: {mcp.name}")

    # Check tools
    tools = mcp.list_tools()
    print(f"✓ {len(tools)} tools registered")

    # Verify required tools
    tool_names = [tool.name for tool in tools]
    required = ["get_tasks", "create_task", "update_task", "toggle_complete", "delete_task"]

    missing = [t for t in required if t not in tool_names]
    if missing:
        print(f"✗ Missing tools: {', '.join(missing)}")
        sys.exit(1)
    else:
        print("✓ All required tools present")

    sys.exit(0)

except Exception as e:
    print(f"✗ MCP server initialization failed: {e}")
    sys.exit(1)
EOF

if python /tmp/test_mcp.py 2>&1 | while read line; do
    if [[ $line == ✓* ]]; then
        echo -e "${GREEN}${line}${NC}"
    elif [[ $line == ✗* ]]; then
        echo -e "${RED}${line}${NC}"
        ERRORS=$((ERRORS + 1))
    else
        echo "$line"
    fi
done; then
    :
else
    ERRORS=$((ERRORS + 1))
fi

rm /tmp/test_mcp.py

# Check if FastAPI server is running
echo ""
echo "Checking FastAPI server..."

if curl -s http://localhost:8000/docs > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} FastAPI server responding"

    # Test tool discovery endpoint
    if curl -s http://localhost:8000/api/mcp/tools > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} Tool discovery endpoint accessible"
    else
        echo -e "${YELLOW}⚠${NC} Tool discovery endpoint not accessible"
        echo "   Ensure /api/mcp/tools route is registered"
    fi
else
    echo -e "${YELLOW}⚠${NC} FastAPI server not running"
    echo "   Start with: uvicorn backend.main:app --reload --port 8000"
fi

# Check integration with agent
echo ""
echo "Checking agent integration..."

if [ -f "backend/agent.py" ]; then
    if grep -q "mcp" backend/agent.py; then
        echo -e "${GREEN}✓${NC} Agent integrated with MCP tools"
    else
        echo -e "${YELLOW}⚠${NC} Agent may not be integrated with MCP tools"
    fi
else
    echo -e "${YELLOW}⚠${NC} agent.py not found"
    echo "   Tools should be integrated with OpenAI Agents SDK"
fi

# Final summary
echo ""
echo "════════════════════════════════════════"
if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}✓ All validations passed!${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Test tool discovery: GET http://localhost:8000/api/mcp/tools"
    echo "2. Test tool execution: POST http://localhost:8000/api/mcp/tools/get_tasks"
    echo "3. Integrate tools with OpenAI agent"
    echo "4. Test agent tool calling"
    echo ""
    echo "Example test:"
    echo "  curl http://localhost:8000/api/mcp/tools"
    exit 0
else
    echo -e "${RED}✗ ${ERRORS} validation error(s) found${NC}"
    echo ""
    echo "Please fix the errors above and run validation again."
    exit 1
fi
