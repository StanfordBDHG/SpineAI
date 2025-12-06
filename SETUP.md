# SpineAI Setup Guide

Complete setup instructions for running the SpineAI system on your Mac.

## What You'll Need

- Mac computer with at least 16 GB RAM
- macOS (any recent version)
- About 1 hour for initial setup

## Step 1: Install Docker Desktop

1. Download Docker Desktop for Mac from: https://www.docker.com/products/docker-desktop
2. Open the downloaded file and drag Docker to your Applications folder
3. Open Docker Desktop from Applications
4. Wait for Docker to start (you'll see a whale icon in your menu bar)

## Step 2: Download the Project

1. Open Terminal (found in Applications > Utilities)
2. Navigate to where you want to download the project
3. Clone the repository:
   ```bash
   git clone <repository-url>
   cd spineai-demo
   ```

## Step 3: Start RAGFlow

RAGFlow is the AI engine that provides spine imaging guidance.

### 3.1 Configure RAGFlow

```bash
cd ragflow/docker
```

Run these commands to configure RAGFlow for your Mac:

```bash
sed -i.bak 's/^DOC_ENGINE=.*/DOC_ENGINE=elasticsearch/' .env
sed -i.bak 's/^MEM_LIMIT=.*/MEM_LIMIT=4294967296/' .env
```

### 3.2 Start RAGFlow Services

```bash
docker compose -f docker-compose-macos.yml up -d ragflow mysql redis minio
```

**Wait 2-3 minutes** for everything to start up.

### 3.3 Set Up RAGFlow Account

1. Open your web browser
2. Go to: **http://localhost:80**
3. Click **"Sign up"** and create an account
4. You'll see a setup screen - configure it as follows:

   **LLM (Language Model):**
   - If you have an OpenAI API key, select "OpenAI" and choose "gpt-4o"
   - Add your OpenAI API key when prompted
   
   **Embedding:**
   - Select "OpenAI" and choose "text-embedding-3-small"
   
   **Skip the other options** (VLM, ASR, Rerank, TTS)

5. Click through to complete setup

### 3.4 Create a Dataset

1. In RAGFlow, click **"Dataset"** at the top
2. Click the **+** button
3. Name it: **"Spine Imaging Guidelines"**
4. Select the embedding model you configured earlier
5. Click **"OK"**

### 3.5 Get Your API Key

1. Click your profile icon (circle in top right corner)
2. Look for **"Settings"** or **"System"**
3. Find the **"API Keys"** section
4. Click **"Generate API Key"**
5. **Copy the key** - you'll need it in the next step
   - It looks like: `ragflow-xxxxxxxxxxxxxx`

## Step 4: Start the Flask Proxy

The proxy connects your iOS app to RAGFlow.

### 4.1 Install Python Dependencies

```bash
cd /path/to/spineai-demo
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

### 4.2 Create Startup Script

Create a file called `start_proxy.sh`:

```bash
cat > start_proxy.sh << 'EOF'
#!/bin/bash
cd /path/to/spineai-demo
source venv/bin/activate
export RAGFLOW_API_KEY="PASTE_YOUR_API_KEY_HERE"
export RAGFLOW_URL="http://localhost:9380/api/v1"
python proxy.py
EOF

chmod +x start_proxy.sh
```

**Important:** 
- Replace `/path/to/spineai-demo` with your actual path
- Replace `PASTE_YOUR_API_KEY_HERE` with the API key you copied

### 4.3 Start the Proxy

```bash
./start_proxy.sh
```

You should see:
```
* Running on http://127.0.0.1:8000
```

**Keep this terminal window open** - the proxy needs to stay running.

## Step 5: Run the iOS App

### 5.1 Open Xcode

```bash
cd SpineAI
open LLMonFHIR.xcodeproj
```

### 5.2 Build and Run

1. In Xcode, select a simulator from the top (e.g., "iPhone 16 Pro")
2. Click the Play button (▶) or press `Cmd+R`
3. Wait for the app to build and launch in the simulator

### 5.3 Configure the App

In the running app:

1. Tap the **Settings** icon (gear icon, top right)
2. Scroll down to **"SpineAI RAG"** section
3. Tap **"SpineAI Proxy Settings"**
4. Enter: `http://localhost:8000`
5. Tap **"Test Connection"**

You should see: **"Connection Successful"**

## Step 6: Test It

1. In the app, go to the chat section
2. Ask a question like: *"What are guidelines for spine imaging?"*
3. The system will respond

**Note:** If you haven't uploaded any documents to RAGFlow, it will say "The answer you are looking for is not found in the knowledge base!" - this means it's working, but has no documents yet.

## Optional: Add Spine Imaging Documents

To get real answers:

1. Open RAGFlow in your browser (http://localhost:80)
2. Go to **Dataset** → **"Spine Imaging Guidelines"**
3. Click **"Add file"**
4. Upload PDF files of spine imaging clinical guidelines
5. Click the play button next to each file to process it
6. Wait for processing to complete (status will show 100%)

Now when you ask questions, you'll get answers based on your uploaded documents!

## Stopping Everything

When you're done:

### Stop the Flask Proxy
In the terminal where it's running, press `Ctrl+C`

### Stop RAGFlow
```bash
cd ragflow/docker
docker compose down
```

### Quit Docker Desktop
Click the Docker icon in your menu bar → "Quit Docker Desktop"

## Restarting Later

When you want to use it again:

1. **Start Docker Desktop** (from Applications)
2. **Start RAGFlow:**
   ```bash
   cd ragflow/docker
   docker compose -f docker-compose-macos.yml up -d ragflow mysql redis minio
   ```
3. **Start Flask Proxy:**
   ```bash
   cd /path/to/spineai-demo
   ./start_proxy.sh
   ```
4. **Run the iOS app** in Xcode

## Common Problems

### "Docker daemon is not running"
- Open Docker Desktop and wait for it to fully start

### RAGFlow login page doesn't work
- Wait 2-3 minutes after starting Docker
- Check if services are running: `docker ps`

### Proxy shows "RAGFlow not configured"
- Make sure you set your API key in `start_proxy.sh`
- The key should look like: `ragflow-xxxxxxxxxxxxx`

### iOS app can't connect
- Make sure Flask proxy is running (`./start_proxy.sh`)
- Check the URL is: `http://localhost:8000` (no `s` in http)

### Out of memory errors
- Close other applications
- Restart Docker Desktop
- If problem persists, your Mac may not have enough RAM (needs 16 GB)

## Getting Help

If you're stuck:
1. Check that Docker Desktop is running
2. Verify all services are up: `docker ps`
3. Check proxy is running: `curl http://localhost:8000/health`
4. Try restarting everything (see "Stopping Everything" above)

---

**Last Updated:** December 6, 2025
