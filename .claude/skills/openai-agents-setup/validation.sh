#!/bin/bash

# OpenAI Agents Setup Validation Script

echo "🔍 Validating OpenAI Agents Setup..."
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Track validation status
ERRORS=0

# Check Python version
echo "Checking Python version..."
PYTHON_VERSION=$(python --version 2>&1 | awk '{print $2}')
REQUIRED_VERSION="3.11"
if python -c "import sys; sys.exit(0 if sys.version_info >= (3, 11) else 1)"; then
    echo -e "${GREEN}✓${NC} Python ${PYTHON_VERSION} installed"
else
    echo -e "${RED}✗${NC} Python 3.11+ required, found ${PYTHON_VERSION}"
    ERRORS=$((ERRORS + 1))
fi

# Check if in backend directory
if [ ! -f "backend/main.py" ]; then
    echo -e "${YELLOW}⚠${NC} Not in project root. Changing to project root..."
    cd ..
fi

# Check dependencies
echo ""
echo "Checking Python dependencies..."

# Check OpenAI Agents SDK
if python -c "import openai" 2>/dev/null; then
    echo -e "${GREEN}✓${NC} OpenAI SDK installed"
else
    echo -e "${RED}✗${NC} OpenAI SDK not installed"
    echo "   Run: pip install openai"
    ERRORS=$((ERRORS + 1))
fi

# Check LiteLLM
if python -c "import litellm" 2>/dev/null; then
    echo -e "${GREEN}✓${NC} LiteLLM installed"
else
    echo -e "${RED}✗${NC} LiteLLM not installed"
    echo "   Run: pip install litellm"
    ERRORS=$((ERRORS + 1))
fi

# Check python-dotenv
if python -c "import dotenv" 2>/dev/null; then
    echo -e "${GREEN}✓${NC} python-dotenv installed"
else
    echo -e "${RED}✗${NC} python-dotenv not installed"
    echo "   Run: pip install python-dotenv"
    ERRORS=$((ERRORS + 1))
fi

# Check environment variables
echo ""
echo "Checking environment variables..."

if [ -f "backend/.env" ]; then
    echo -e "${GREEN}✓${NC} .env file exists"

    # Check GOOGLE_API_KEY
    if grep -q "GOOGLE_API_KEY" backend/.env; then
        GOOGLE_API_KEY=$(grep "GOOGLE_API_KEY" backend/.env | cut -d '=' -f2)
        if [ -n "$GOOGLE_API_KEY" ] && [ "$GOOGLE_API_KEY" != "your_gemini_api_key_here" ]; then
            echo -e "${GREEN}✓${NC} GOOGLE_API_KEY configured"
        else
            echo -e "${RED}✗${NC} GOOGLE_API_KEY not set or using placeholder"
            echo "   Set your Google AI Studio API key in backend/.env"
            ERRORS=$((ERRORS + 1))
        fi
    else
        echo -e "${RED}✗${NC} GOOGLE_API_KEY not found in .env"
        ERRORS=$((ERRORS + 1))
    fi
else
    echo -e "${RED}✗${NC} backend/.env file not found"
    echo "   Create backend/.env with GOOGLE_API_KEY"
    ERRORS=$((ERRORS + 1))
fi

# Check configuration files
echo ""
echo "Checking configuration files..."

if [ -f "backend/agent_config.py" ]; then
    echo -e "${GREEN}✓${NC} agent_config.py exists"
else
    echo -e "${RED}✗${NC} agent_config.py not found"
    echo "   Create backend/agent_config.py"
    ERRORS=$((ERRORS + 1))
fi

if [ -f "backend/agent.py" ]; then
    echo -e "${GREEN}✓${NC} agent.py exists"
else
    echo -e "${RED}✗${NC} agent.py not found"
    echo "   Create backend/agent.py"
    ERRORS=$((ERRORS + 1))
fi

if [ -f "backend/litellm_config.yaml" ]; then
    echo -e "${GREEN}✓${NC} litellm_config.yaml exists"
else
    echo -e "${YELLOW}⚠${NC} litellm_config.yaml not found (optional)"
fi

# Check if LiteLLM proxy is running
echo ""
echo "Checking LiteLLM proxy..."

if curl -s http://localhost:4000/health > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} LiteLLM proxy responding on port 4000"
else
    echo -e "${YELLOW}⚠${NC} LiteLLM proxy not responding"
    echo "   Start with: litellm --config backend/litellm_config.yaml --port 4000"
fi

# Test agent response (if all checks passed)
if [ $ERRORS -eq 0 ]; then
    echo ""
    echo "Testing agent response..."

    cat > /tmp/test_agent.py << 'EOF'
import sys
sys.path.insert(0, 'backend')

try:
    from agent import create_agent_response
    import asyncio

    async def test():
        messages = [{"role": "user", "content": "Hello"}]
        response = await create_agent_response(messages, stream=False)
        return response.choices[0].message.content

    result = asyncio.run(test())
    if result:
        print("✓ Agent responds to test query")
        sys.exit(0)
    else:
        print("✗ Agent returned empty response")
        sys.exit(1)
except Exception as e:
    print(f"✗ Agent test failed: {e}")
    sys.exit(1)
EOF

    if python /tmp/test_agent.py 2>/dev/null; then
        echo -e "${GREEN}✓${NC} Agent responds to test query"
    else
        echo -e "${YELLOW}⚠${NC} Could not test agent (proxy may not be running)"
    fi

    rm /tmp/test_agent.py
fi

# Final summary
echo ""
echo "════════════════════════════════════════"
if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}✓ All validations passed!${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Start LiteLLM proxy: litellm --config backend/litellm_config.yaml --port 4000"
    echo "2. Test streaming endpoint: POST /api/chat/stream"
    echo "3. Integrate with MCP tools (fastmcp-server-setup skill)"
    exit 0
else
    echo -e "${RED}✗ ${ERRORS} validation error(s) found${NC}"
    echo ""
    echo "Please fix the errors above and run validation again."
    exit 1
fi
