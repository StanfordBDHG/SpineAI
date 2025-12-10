# SpineAI Setup Guide

Complete setup instructions for running the SpineAI system on your Mac.

## What You'll Need

- Mac computer with at least 16 GB RAM
- macOS (any recent version)
- About 1-2 hours for initial setup
- Stable internet connection

## Prerequisites Check

Before starting, verify you have:
- [ ] Xcode installed (download from App Store if needed)
- [ ] At least 20 GB of free disk space
- [ ] Admin access to your Mac

---

## Step 1: Install Docker Desktop

Docker is software that runs the AI engine.

1. Go to: https://www.docker.com/products/docker-desktop
2. Click "Download for Mac"
3. Choose the correct version:
   - Apple Silicon (M1/M2/M3): Download "Apple Chip"
   - Intel Mac: Download "Intel Chip"
4. Open the downloaded .dmg file
5. Drag Docker to your Applications folder
6. Open Docker Desktop from Applications
7. Wait 2-3 minutes for Docker to fully start
8. You'll see a whale icon in your menu bar when it's ready

CHECKPOINT: Docker icon should be in your menu bar (top of screen) and NOT show any error messages.

---

## Step 2: Download the Projects

### 2.1 Open Terminal

1. Press Cmd + Space to open Spotlight
2. Type "Terminal" and press Enter
3. A black or white window will open - this is Terminal

### 2.2 Navigate to Downloads

Copy and paste this command into Terminal, then press Enter:

```bash
cd ~/Downloads
```

### 2.3 Download SpineAI (the iOS app)

Copy and paste these commands ONE AT A TIME, pressing Enter after each:

```bash
git clone https://github.com/StanfordBDHG/SpineAI.git
```

Wait for it to finish, then:

```bash
cd SpineAI
git checkout spineai-integration
cd ..
```

### 2.4 Download RAGFlow (the AI engine)

Copy and paste this command:

```bash
git clone https://github.com/infiniflow/ragflow.git
```

CHECKPOINT: You should now have two folders in your Downloads:
- SpineAI (the iOS app)
- ragflow (the AI engine)

To verify, run:
```bash
ls ~/Downloads
```

You should see both folders listed.

---

## Step 3: Set Up RAGFlow (AI Engine)

### 3.1 Navigate to RAGFlow Directory

```bash
cd ~/Downloads/ragflow/docker
```

### 3.2 Configure RAGFlow for Your Mac

Copy and paste these commands ONE AT A TIME:

```bash
cp .env .env.backup
```

Then:

```bash
sed -i '' 's/^DOC_ENGINE=.*/DOC_ENGINE=elasticsearch/' .env
sed -i '' 's/^MEM_LIMIT=.*/MEM_LIMIT=4294967296/' .env
```

NOTE: If you see an error with sed, that's okay. Continue to the next step.

### 3.3 Verify Configuration (Optional but Recommended)

To verify the changes worked:

```bash
grep "DOC_ENGINE\|MEM_LIMIT" .env
```

You should see:
```
DOC_ENGINE=elasticsearch
MEM_LIMIT=4294967296
```

### 3.4 Start RAGFlow Services

First, pull the pre-built images (this prevents build errors):

```bash
docker compose -f docker-compose-macos.yml pull ragflow mysql redis minio es01
```

This will take 5-10 minutes as Docker downloads the images.

Then start the services:

```bash
docker compose -f docker-compose-macos.yml up -d --no-build ragflow mysql redis minio es01
```

Wait until you see "Started" messages and the command prompt returns.

### 3.5 Verify Services Are Running

Wait 2-3 minutes after the command completes, then run:

```bash
docker ps
```

You should see at least 5 containers running (ragflow, mysql, redis, minio, es01).

---

## Step 4: Configure RAGFlow Web Interface

### 4.1 Access RAGFlow

1. Open your web browser (Chrome, Safari, or Firefox)
2. Go to: http://localhost:80
3. You should see a RAGFlow login page
   - If you see "This site can't be reached", wait 2 more minutes and refresh
   - If it still doesn't work, go back to Step 3.5

### 4.2 Create an Account

1. Click "Sign up" (or "Register")
2. Enter:
   - Email: (use any email, doesn't have to be real)
   - Password: (create a password you'll remember)
3. Click "Sign up" or "Create Account"
4. Log in with your credentials

### 4.3 Configure the AI Models

You'll see a setup screen. Configure it as follows:

LLM (Language Model):
- Select "OpenAI"
- Choose "gpt-5-chat-latest"
- Enter your OpenAI API key when prompted

Text Embedding:
- Select "OpenAI"
- Choose "text-embedding-3-large"

Skip the other options: VLM, ASR, Rerank, TTS (leave them unconfigured)

Click "Finish" or "Complete Setup" when done.

### 4.4 Create a Dataset

A dataset is where you'll upload clinical guidelines.

1. Click "Dataset" in the top navigation
2. Click the "+" button (or "Create Dataset")
3. Enter these details:
   - Name: Spine Guidelines
   - Description: Clinical spine care guidelines
   - Embedding Model: Select "text-embedding-3-large" (the OpenAI model you configured)
   - Chunk Method: Leave as default
4. Click "OK" or "Create"

CHECKPOINT: You should see "Spine Guidelines" in your dataset list.

### 4.5 Create a Chat Assistant

This is the AI that will answer questions.

1. Click "Chat" or "Assistants" in the top navigation
2. Click "+" or "Create Assistant"
3. Enter these details:
   - Name: SpineAI Assistant
   - Language Model: Select "gpt-5-chat-latest" (the OpenAI model you configured)
   - System Prompt: Copy and paste this:
     ```
     You are a helpful spine care assistant. Provide clear, concise answers about spine conditions, treatments, and care. Use simple language that patients can understand. Keep responses brief (2-3 sentences) unless asked for more detail. Always cite sources when available.
     ```
   - Prompt Engine (scroll down to find this): Replace the default text with:
     ```
     You are a helpful spine care assistant. Use the knowledge base below to answer the patient's question clearly and concisely in 2-3 sentences. Use simple language that patients can understand. Always cite sources when available. If the knowledge base doesn't contain relevant information, say "I don't have information about that in the clinical guidelines. Please consult with your healthcare provider."

     Here is the knowledge base:

     {knowledge}

     The above is the knowledge base.
     ```
   - Empty Response: Enter this:
     ```
     I don't have information about that in the clinical guidelines. Please consult with your healthcare provider.
     ```
4. Link the Dataset:
   - Scroll down to "Knowledge Bases" or "Datasets"
   - Check the box next to "Spine Guidelines"
5. Click "Save" or "Create"

IMPORTANT: Get the Chat ID
- After saving the assistant, click the "Embed into webpage" button (usually in the assistant list)
- A dialog will appear showing the Chat ID (a long string of letters and numbers)
- COPY THIS CHAT ID - you'll need it in Step 5.3
- It looks like: 444442f6d58a11f084153604d8716792

### 4.6 Get Your API Key

1. Click your profile icon (circle in top right corner)
2. Click "API Keys" or "Settings" > "API Keys"
3. Click "Create API Key" or "Generate"
4. COPY the entire key - it starts with "ragflow-"
5. Save this key somewhere safe - you can't see it again

---

## Step 5: Set Up the Flask Proxy

The proxy connects your iOS app to RAGFlow.

### 5.1 Open a NEW Terminal Window

1. Keep your previous Terminal window open
2. Open a new Terminal: Press Cmd + N in Terminal, or open Terminal again from Spotlight

### 5.2 Install Python Dependencies

Copy and paste these commands ONE AT A TIME:

```bash
cd ~/Downloads/SpineAI
```

Then:

```bash
python3 -m venv venv
```

Then:

```bash
source venv/bin/activate
```

You should see (venv) appear at the start of your command line.

Now install the required packages:

```bash
pip install -r requirements.txt
```

Wait for installation to complete. This might take 1-2 minutes.

### 5.3 Configure the Chat ID in proxy.py

CRITICAL STEP - Don't skip this!

You need to update the proxy with your Chat ID from Step 4.5.

1. Open the proxy.py file:
   ```bash
   open -a TextEdit ~/Downloads/SpineAI/proxy.py
   ```

2. Find this line (around line 62):
   ```python
   chat_id = "8d19a384d25d11f0b8fa76278ce0f2bf"
   ```

3. REPLACE the long string with YOUR Chat ID from Step 4.5

4. Save the file: Press Cmd + S, then close TextEdit

### 5.4 Create Startup Script

Copy and paste this command:

```bash
cat > ~/Downloads/SpineAI/start_proxy.sh << 'EOF'
#!/bin/bash
cd ~/Downloads/SpineAI
export RAGFLOW_API_KEY="PASTE_YOUR_API_KEY_HERE"
export RAGFLOW_URL="http://localhost:9380/api/v1"
./venv/bin/python proxy.py
EOF
```

Then make it executable:

```bash
chmod +x ~/Downloads/SpineAI/start_proxy.sh
```

### 5.5 Edit the Startup Script with Your API Key

1. Open the script:
   ```bash
   open -a TextEdit ~/Downloads/SpineAI/start_proxy.sh
   ```

2. Find this line:
   ```bash
   export RAGFLOW_API_KEY="PASTE_YOUR_API_KEY_HERE"
   ```

3. REPLACE PASTE_YOUR_API_KEY_HERE with your actual RAGFlow API key from Step 4.6
   - Keep the quotes around it
   - Should look like: export RAGFLOW_API_KEY="ragflow-xxxxx..."

4. Save: Press Cmd + S, then close TextEdit

### 5.6 Start the Proxy

In the Terminal where you activated the virtual environment:

```bash
cd ~/Downloads/SpineAI
./start_proxy.sh
```

You should see:
```
* Running on http://127.0.0.1:8000
```

DO NOT CLOSE THIS TERMINAL WINDOW - the proxy needs to stay running.

---

## Step 6: Run the iOS App

### 6.1 Open Xcode

Open a NEW Terminal window (keep the proxy running in the old one), then:

```bash
cd ~/Downloads/SpineAI
open LLMonFHIR.xcodeproj
```

Xcode will open. This might take a minute.

### 6.2 Select a Simulator

1. In Xcode, at the top, you'll see a device selector
2. Click it and select any iPhone simulator (e.g., "iPhone 16 Pro")

### 6.3 Build and Run

1. Click the Play button (▶) at the top left of Xcode
   - OR press Cmd + R
2. Wait 2-5 minutes for the app to build
3. The iOS simulator will open and launch the SpineAI app

If you see build errors:
- Wait for them to appear, then take a screenshot and contact support
- Common fix: Clean build folder (Cmd + Shift + K), then try again

---

## Step 7: Configure the App

### 7.1 Enable SpineAI in the App

1. In the simulator, tap the Settings icon (gear icon in top right)
2. Scroll down to find "SpineAI Proxy Settings"
3. Tap it
4. Toggle ON the switch at the top that says "Enable SpineAI RAG"
5. In the Proxy URL field, enter: http://localhost:8000
6. Tap "Test Connection"

You should see: "Connection Successful" with a green checkmark

If you see "Connection Failed":
- Go back to your Terminal and verify the proxy is still running
- Check that you entered the correct API key in Step 5.5
- Try restarting the proxy (see Step 5.6)

### 7.2 Navigate to the Chat

1. Tap the back button to return to Settings
2. Tap Done or the X to close Settings
3. You should see the SpineAI chat interface

---

## Step 8: Test the System

### 8.1 Test Without Documents (Verify Connection)

1. In the chat, type: "What are treatment options for lower back pain?"
2. Press Send
3. You should get a response like:
   - "I don't have information about that in the clinical guidelines."
   - OR "The answer you are looking for is not found in the knowledge base!"

This is good! It means the system is working, but you haven't uploaded documents yet.

### 8.2 Upload Documents (Optional but Recommended)

To get real answers, you need to upload clinical guidelines:

1. Go back to your web browser
2. Go to http://localhost:80
3. Click "Dataset" > "Spine Guidelines"
4. Click "Add file" or "Upload"
5. Upload a PDF file containing spine care clinical guidelines
   - If you don't have one, you can create a simple text file for testing
6. After uploading, click the "Play" button (▶) or "Parse" next to the file
7. Wait for parsing to complete - the status will show 100% when done
8. This can take 5-15 minutes depending on file size

### 8.3 Test With Documents

Once parsing is complete:

1. Go back to the iOS app
2. Ask the same question: "What are treatment options for lower back pain?"
3. You should now get a real answer based on the uploaded document!

---

## Step 9: Stopping Everything

When you're done for the day:

### 9.1 Stop the iOS App
- In Xcode, click the Stop button (⬛) or close the simulator

### 9.2 Stop the Flask Proxy
- In the Terminal where it's running, press Ctrl + C

### 9.3 Stop RAGFlow
```bash
cd ~/Downloads/ragflow/docker
docker compose down
```

### 9.4 Quit Docker Desktop
- Click the Docker whale icon in your menu bar
- Click "Quit Docker Desktop"

---

## Restarting Later

When you want to use SpineAI again:

### 1. Start Docker Desktop
- Open Docker Desktop from Applications
- Wait 2-3 minutes for it to fully start

### 2. Start RAGFlow
Open Terminal:
```bash
cd ~/Downloads/ragflow/docker
docker compose -f docker-compose-macos.yml up -d --no-build ragflow mysql redis minio es01
```
Wait 2-3 minutes for services to start.

### 3. Start Flask Proxy
In Terminal:
```bash
cd ~/Downloads/SpineAI
./start_proxy.sh
```
Keep this Terminal open.

### 4. Run the iOS App
In a new Terminal:
```bash
cd ~/Downloads/SpineAI
open LLMonFHIR.xcodeproj
```
Then click Play (▶) in Xcode.

---

## Troubleshooting

### Docker Issues

"Cannot connect to Docker daemon"
- Solution: Open Docker Desktop and wait for it to fully start (2-3 minutes)
- Check the Docker icon in menu bar - should NOT show an error

"Port already in use"
- Solution: Something else is using the same port. Run:
  ```bash
  docker compose down
  ```
  Then start again.

### RAGFlow Issues

"This site can't be reached" at http://localhost:80
- Solution 1: Wait 2-3 more minutes, then refresh
- Solution 2: Check if services are running:
  ```bash
  docker ps
  ```
  You should see ragflow, mysql, redis, minio
- Solution 3: Check logs:
  ```bash
  cd ~/Downloads/ragflow/docker
  docker compose logs ragflow
  ```

"The answer you are looking for is not found"
- This is GOOD if you haven't uploaded documents yet
- If you have uploaded documents:
  - Check that parsing completed (should show 100%)
  - Check that the dataset is linked to the assistant (Step 4.5)

### Flask Proxy Issues

"Connection Failed" in iOS app
- Check 1: Is the proxy running? Look at the Terminal - should say "Running on http://127.0.0.1:8000"
- Check 2: Is the API key correct in start_proxy.sh?
- Check 3: Is the URL exactly http://localhost:8000 (no https)?
- Check 4: Test proxy directly:
  ```bash
  curl http://localhost:8000/health
  ```
  Should return a JSON response.

Proxy shows "RAGFlow not configured"
- Your API key is wrong or missing
- Go back to Step 5.5 and verify the API key

"Chat ID not found"
- The Chat ID in proxy.py doesn't match your assistant
- Go back to Step 5.3 and update proxy.py with the correct Chat ID

### iOS App Issues

"Build Failed" in Xcode
- Solution 1: Clean build folder (Cmd + Shift + K), then build again
- Solution 2: Close Xcode, delete DerivedData:
  ```bash
  rm -rf ~/Library/Developer/Xcode/DerivedData
  ```
  Then reopen Xcode and build.

App doesn't respond in chat
- Check that "Enable SpineAI RAG" toggle is ON (Step 7.1)
- Check that proxy URL is correct: http://localhost:8000
- Test connection button should show green

### Memory/Performance Issues

"Out of memory" errors
- Your Mac might not have enough RAM
- Solution: Close all other applications
- Solution: Restart Docker Desktop
- If problem persists, your Mac needs at least 16 GB RAM

Everything is slow
- This is normal during first run (Docker downloads images)
- After first time, it should be faster
- Close unnecessary applications to free up resources

---

## Quick Health Check

Run these commands to verify everything is working:

```bash
# Check Docker is running
docker ps

# Check RAGFlow is accessible
curl -I http://localhost:80

# Check Flask proxy is accessible
curl http://localhost:8000/health
```

All three should return successful responses (no errors).

---

## Getting More Help

If you're completely stuck:

1. Check all services are running:
   ```bash
   docker ps
   ```

2. Check proxy logs (in the Terminal where it's running)

3. Restart everything:
   - Follow "Step 9: Stopping Everything"
   - Then follow "Restarting Later"

4. Contact team with:
   - Screenshot of the error
   - What step you're on
   - Output of "docker ps"

---

## Summary Checklist

If you run into an issue, first verify:

- [ ] Docker Desktop is running (whale icon in menu bar)
- [ ] RAGFlow web interface loads at http://localhost:80
- [ ] You created a RAGFlow account
- [ ] You configured LLM and embedding models
- [ ] You created the "Spine Guidelines" dataset
- [ ] You created the "SpineAI Assistant" chat assistant
- [ ] You linked the dataset to the assistant
- [ ] You copied your RAGFlow API key
- [ ] You updated the Chat ID in proxy.py (Step 5.3)
- [ ] You updated the API key in start_proxy.sh (Step 5.5)
- [ ] Flask proxy is running and shows "Running on http://127.0.0.1:8000"
- [ ] iOS app builds successfully in Xcode
- [ ] "Enable SpineAI RAG" toggle is ON in app settings
- [ ] Proxy URL is set to http://localhost:8000
- [ ] "Test Connection" shows "Connection Successful"

---

Last Updated: December 10, 2025
