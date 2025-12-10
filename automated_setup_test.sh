#!/bin/bash

# Automated Setup Test Script
# This script executes EVERY step from SETUP.md EXACTLY as written
# NO extra steps, NO variations

set -e  # Exit on any error

echo "=================================================="
echo "SpineAI Automated Setup Test"
echo "Following SETUP.md EXACTLY"
echo "=================================================="
echo ""

# Helper function to show progress
show_step() {
    echo ""
    echo "=========================================="
    echo "$1"
    echo "=========================================="
}

# Helper function to pause
pause_step() {
    echo ""
    echo "Press Enter to continue to next step..."
    read
}

# ===========================================
# STEP 1: Install Docker Desktop
# ===========================================
show_step "STEP 1: Install Docker Desktop"
echo "Checking if Docker is installed and running..."
if ! docker ps >/dev/null 2>&1; then
    echo "ERROR: Docker is not running!"
    echo "Please start Docker Desktop and run this script again."
    exit 1
fi
echo "✓ Docker is running"

# ===========================================
# STEP 2: Download the Projects
# ===========================================
show_step "STEP 2: Download the Projects"

# 2.2 Navigate to Downloads
echo "Step 2.2: Navigate to Downloads"
cd ~/Downloads

# 2.3 Download SpineAI (the iOS app)
echo ""
echo "Step 2.3: Download SpineAI"
if [ -d "SpineAI2" ]; then
    echo "SpineAI2 folder already exists. Removing it..."
    rm -rf SpineAI2
fi

git clone https://github.com/StanfordBDHG/SpineAI.git SpineAI2

cd SpineAI2
git checkout spineai-integration
cd ..

# 2.4 Download RAGFlow (the AI engine)
echo ""
echo "Step 2.4: Download RAGFlow"
if [ -d "ragflow" ]; then
    echo "ragflow folder already exists. Removing it..."
    rm -rf ragflow
fi

git clone https://github.com/infiniflow/ragflow.git

# Verify folders exist
echo ""
echo "Verifying folders..."
ls ~/Downloads | grep -E "SpineAI2|ragflow"

# ===========================================
# STEP 3: Set Up RAGFlow (AI Engine)
# ===========================================
show_step "STEP 3: Set Up RAGFlow (AI Engine)"

# 3.1 Navigate to RAGFlow Directory
echo "Step 3.1: Navigate to RAGFlow Directory"
cd ~/Downloads/ragflow/docker

# 3.2 Configure RAGFlow for Your Mac
echo ""
echo "Step 3.2: Configure RAGFlow for Your Mac"
cp .env .env.backup

sed -i '' 's/^DOC_ENGINE=.*/DOC_ENGINE=elasticsearch/' .env
sed -i '' 's/^MEM_LIMIT=.*/MEM_LIMIT=4294967296/' .env

# 3.3 Verify Configuration
echo ""
echo "Step 3.3: Verify Configuration"
grep "DOC_ENGINE\|MEM_LIMIT" .env

# 3.4 Start RAGFlow Services
echo ""
echo "Step 3.4: Start RAGFlow Services"
echo "This will take 5-10 minutes..."
docker compose -f docker-compose-macos.yml up -d ragflow mysql redis minio

echo "Waiting for services to start..."
sleep 180  # Wait 3 minutes

# 3.5 Verify Services Are Running
echo ""
echo "Step 3.5: Verify Services Are Running"
docker ps

# ===========================================
# STEP 4: Configure RAGFlow Web Interface
# ===========================================
show_step "STEP 4: Configure RAGFlow Web Interface"

echo "MANUAL STEP REQUIRED:"
echo ""
echo "1. Open your web browser"
echo "2. Go to: http://localhost:80"
echo "3. Create an account (Sign up)"
echo "4. Configure the AI Models:"
echo "   - LLM: Select OpenAI, Choose gpt-5-chat-latest, Enter your OpenAI API key"
echo "   - Text Embedding: Select OpenAI, Choose text-embedding-3-large"
echo "   - Click Finish"
echo "5. Create a Dataset:"
echo "   - Click Dataset > +"
echo "   - Name: Spine Guidelines"
echo "   - Description: Clinical spine care guidelines"
echo "   - Embedding Model: text-embedding-3-large"
echo "   - Click OK"
echo "6. Create a Chat Assistant:"
echo "   - Click Chat > +"
echo "   - Name: SpineAI Assistant"
echo "   - Language Model: gpt-5-chat-latest"
echo "   - System Prompt: You are a helpful spine care assistant. Provide clear, concise answers about spine conditions, treatments, and care. Use simple language that patients can understand. Keep responses brief (2-3 sentences) unless asked for more detail. Always cite sources when available."
echo "   - Empty Response: I don't have information about that in the clinical guidelines. Please consult with your healthcare provider."
echo "   - Link Dataset: Check 'Spine Guidelines'"
echo "   - Click Save"
echo "   - COPY THE CHAT ID"
echo "7. Get Your API Key:"
echo "   - Click profile icon > API Keys"
echo "   - Click Create API Key"
echo "   - COPY THE API KEY"
echo ""
echo "Once you have completed these steps and have:"
echo "  - Your Chat ID"
echo "  - Your RAGFlow API Key"
pause_step

# Get user inputs
echo ""
read -p "Enter your Chat ID: " CHAT_ID
read -p "Enter your RAGFlow API Key: " RAGFLOW_API_KEY
read -p "Enter your OpenAI API Key (for reference): " OPENAI_API_KEY

# ===========================================
# STEP 5: Set Up the Flask Proxy
# ===========================================
show_step "STEP 5: Set Up the Flask Proxy"

# 5.2 Install Python Dependencies
echo "Step 5.2: Install Python Dependencies"
cd ~/Downloads/SpineAI2

python3 -m venv venv

source venv/bin/activate

pip install -r requirements.txt

# 5.3 Configure the Chat ID in proxy.py
echo ""
echo "Step 5.3: Configure the Chat ID in proxy.py"
# Find and replace the chat_id line in proxy.py
sed -i '' "s/chat_id = \".*\"/chat_id = \"$CHAT_ID\"/" proxy.py

echo "✓ Updated proxy.py with Chat ID: $CHAT_ID"

# 5.4 Create Startup Script
echo ""
echo "Step 5.4: Create Startup Script"
cat > ~/Downloads/SpineAI2/start_proxy.sh << 'EOF'
#!/bin/bash
cd ~/Downloads/SpineAI2
source venv/bin/activate
export RAGFLOW_API_KEY="PASTE_YOUR_API_KEY_HERE"
export RAGFLOW_URL="http://localhost:9380/api/v1"
python proxy.py
EOF

chmod +x ~/Downloads/SpineAI2/start_proxy.sh

# 5.5 Edit the Startup Script with Your API Key
echo ""
echo "Step 5.5: Edit the Startup Script with Your API Key"
sed -i '' "s/PASTE_YOUR_API_KEY_HERE/$RAGFLOW_API_KEY/" start_proxy.sh

echo "✓ Updated start_proxy.sh with API key"

# 5.6 Start the Proxy
echo ""
echo "Step 5.6: Start the Proxy"
echo "Starting proxy in background..."
./start_proxy.sh &
PROXY_PID=$!

sleep 5  # Wait for proxy to start

# Verify proxy is running
if curl -s http://localhost:8000/health >/dev/null; then
    echo "✓ Flask proxy is running"
else
    echo "ERROR: Flask proxy failed to start"
    exit 1
fi

# ===========================================
# STEP 6: Run the iOS App
# ===========================================
show_step "STEP 6: Run the iOS App"

# 6.1 Open Xcode
echo "Step 6.1: Open Xcode"
cd ~/Downloads/SpineAI2
open LLMonFHIR.xcodeproj

echo ""
echo "MANUAL STEP REQUIRED:"
echo ""
echo "1. In Xcode, select a simulator (e.g., iPhone 16 Pro)"
echo "2. Click the Play button (▶) or press Cmd+R"
echo "3. Wait for the app to build and launch"
echo ""
pause_step

# ===========================================
# STEP 7: Configure the App
# ===========================================
show_step "STEP 7: Configure the App"

echo "MANUAL STEP REQUIRED:"
echo ""
echo "1. In the simulator, tap Settings icon (gear icon in top right)"
echo "2. Scroll down to 'SpineAI Proxy Settings'"
echo "3. Tap it"
echo "4. Toggle ON 'Enable SpineAI RAG'"
echo "5. Enter URL: http://localhost:8000"
echo "6. Tap 'Test Connection'"
echo "7. You should see: 'Connection Successful'"
echo "8. Tap back, tap Done/X to close Settings"
echo ""
pause_step

# ===========================================
# STEP 8: Test the System
# ===========================================
show_step "STEP 8: Test the System"

echo "MANUAL STEP REQUIRED:"
echo ""
echo "1. In the chat, type: 'What are treatment options for lower back pain?'"
echo "2. Press Send"
echo "3. You should get a response like:"
echo "   'I don't have information about that in the clinical guidelines.'"
echo "   OR 'The answer you are looking for is not found in the knowledge base!'"
echo ""
echo "This means the system is working!"
echo ""
pause_step

# ===========================================
# COMPLETION
# ===========================================
show_step "SETUP COMPLETE!"

echo "All automated steps from SETUP.md have been executed successfully!"
echo ""
echo "Summary:"
echo "  ✓ Docker running"
echo "  ✓ Projects downloaded (SpineAI2, ragflow)"
echo "  ✓ RAGFlow configured and running"
echo "  ✓ Flask proxy configured and running (PID: $PROXY_PID)"
echo "  ✓ Xcode project opened"
echo ""
echo "The system is ready to use!"
echo ""
echo "To stop everything later:"
echo "  1. Stop iOS app in Xcode"
echo "  2. Stop proxy: kill $PROXY_PID"
echo "  3. Stop RAGFlow: cd ~/Downloads/ragflow/docker && docker compose down"
echo "  4. Quit Docker Desktop"
echo ""

