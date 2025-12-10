#!/bin/bash

# SpineAI Setup Verification Script
# Run this script to verify all components are working correctly

echo "=================================================="
echo "SpineAI Setup Verification"
echo "=================================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test 1: Check Docker is running
echo "Test 1: Checking Docker..."
if docker ps >/dev/null 2>&1; then
    echo -e "${GREEN}✓ Docker is running${NC}"
else
    echo -e "${RED}✗ Docker is NOT running${NC}"
    echo "  → Solution: Open Docker Desktop and wait for it to start"
    exit 1
fi
echo ""

# Test 2: Check RAGFlow containers
echo "Test 2: Checking RAGFlow containers..."
CONTAINER_COUNT=$(docker ps --filter "name=ragflow\|mysql\|redis\|minio" --format "{{.Names}}" | wc -l)
if [ "$CONTAINER_COUNT" -ge 4 ]; then
    echo -e "${GREEN}✓ RAGFlow containers are running ($CONTAINER_COUNT containers)${NC}"
    docker ps --filter "name=ragflow\|mysql\|redis\|minio" --format "  • {{.Names}}: {{.Status}}"
else
    echo -e "${RED}✗ RAGFlow containers are NOT running${NC}"
    echo "  → Solution: Run: cd ~/Downloads/ragflow/docker && docker compose -f docker-compose-macos.yml up -d ragflow mysql redis minio"
    exit 1
fi
echo ""

# Test 3: Check RAGFlow web interface
echo "Test 3: Checking RAGFlow web interface..."
if curl -s -o /dev/null -w "%{http_code}" http://localhost:80 | grep -q "200\|302\|404"; then
    echo -e "${GREEN}✓ RAGFlow web interface is accessible at http://localhost:80${NC}"
else
    echo -e "${RED}✗ RAGFlow web interface is NOT accessible${NC}"
    echo "  → Solution: Wait 2-3 minutes for RAGFlow to fully start, then try again"
    exit 1
fi
echo ""

# Test 4: Check Flask proxy
echo "Test 4: Checking Flask proxy..."
if curl -s http://localhost:8000/health >/dev/null 2>&1; then
    echo -e "${GREEN}✓ Flask proxy is running at http://localhost:8000${NC}"
    HEALTH=$(curl -s http://localhost:8000/health)
    echo "  Health check response:"
    echo "  $HEALTH" | python3 -m json.tool 2>/dev/null || echo "  $HEALTH"
else
    echo -e "${RED}✗ Flask proxy is NOT running${NC}"
    echo "  → Solution: Run: cd ~/Downloads/SpineAI && ./start_proxy.sh"
    exit 1
fi
echo ""

# Test 5: Check proxy configuration
echo "Test 5: Checking proxy configuration..."
HEALTH_RESPONSE=$(curl -s http://localhost:8000/health)
if echo "$HEALTH_RESPONSE" | grep -q "ragflowConfigured.*true"; then
    echo -e "${GREEN}✓ RAGFlow is properly configured in proxy${NC}"
else
    echo -e "${YELLOW}⚠ RAGFlow might not be properly configured${NC}"
    echo "  → Check: API key is set in start_proxy.sh"
    echo "  → Check: RAGFlow API key is valid"
fi
echo ""

# Test 6: Check Xcode project exists
echo "Test 6: Checking iOS app files..."
if [ -f "$HOME/Downloads/SpineAI/LLMonFHIR.xcodeproj/project.pbxproj" ]; then
    echo -e "${GREEN}✓ Xcode project found${NC}"
else
    echo -e "${RED}✗ Xcode project NOT found${NC}"
    echo "  → Solution: Make sure you cloned the SpineAI repository correctly"
    exit 1
fi
echo ""

# Test 7: Check proxy.py configuration
echo "Test 7: Checking proxy.py configuration..."
if [ -f "$HOME/Downloads/SpineAI/proxy.py" ]; then
    CHAT_ID=$(grep -o 'chat_id = "[^"]*"' "$HOME/Downloads/SpineAI/proxy.py" | cut -d'"' -f2)
    if [ ! -z "$CHAT_ID" ]; then
        echo -e "${GREEN}✓ proxy.py is configured with Chat ID: $CHAT_ID${NC}"
    else
        echo -e "${RED}✗ Chat ID not found in proxy.py${NC}"
        echo "  → Solution: Update chat_id in proxy.py with your RAGFlow assistant ID"
    fi
else
    echo -e "${RED}✗ proxy.py file not found${NC}"
    exit 1
fi
echo ""

# Summary
echo "=================================================="
echo -e "${GREEN}All tests passed!${NC}"
echo "=================================================="
echo ""
echo "Your SpineAI setup is working correctly!"
echo ""
echo "Next steps:"
echo "1. Open Xcode: cd ~/Downloads/SpineAI && open LLMonFHIR.xcodeproj"
echo "2. Build and run the app (press the Play button)"
echo "3. Configure the app:"
echo "   • Tap Settings (gear icon)"
echo "   • Go to 'SpineAI Proxy Settings'"
echo "   • Toggle ON 'Enable SpineAI RAG'"
echo "   • Enter URL: http://localhost:8000"
echo "   • Tap 'Test Connection'"
echo ""

