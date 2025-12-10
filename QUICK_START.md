# SpineAI Quick Start

**Use this guide if you already completed the full setup. For first-time setup, see [SETUP.md](SETUP.md).**

## Starting SpineAI (Every Time)

Follow these steps in order:

### 1. Start Docker Desktop
- Open Docker Desktop from Applications
- **Wait 2-3 minutes** for it to fully start
- Look for the whale icon in your menu bar

### 2. Start RAGFlow
Open Terminal and run:
```bash
cd ~/Downloads/ragflow/docker
docker compose -f docker-compose-macos.yml up -d ragflow mysql redis minio
```
**Wait 2-3 minutes** for services to start.

### 3. Start Flask Proxy
**Keep Terminal open from step 2**, open a NEW Terminal window:
```bash
cd ~/Downloads/SpineAI
./start_proxy.sh
```
**Keep this Terminal window open** - you should see:
```
* Running on http://127.0.0.1:8000
```

### 4. Run iOS App
Open a THIRD Terminal window:
```bash
cd ~/Downloads/SpineAI
open LLMonFHIR.xcodeproj
```
In Xcode:
- Click the Play button (▶) or press `Cmd+R`
- Wait for the app to build and launch

### 5. Verify Everything Works
Run the verification script:
```bash
cd ~/Downloads/SpineAI
./verify_setup.sh
```
All tests should pass with green checkmarks ✓

---

## Stopping SpineAI (End of Day)

### 1. Stop iOS App
- In Xcode, click Stop (⬛) or close simulator

### 2. Stop Flask Proxy
- In the Terminal where it's running, press `Ctrl+C`

### 3. Stop RAGFlow
```bash
cd ~/Downloads/ragflow/docker
docker compose down
```

### 4. Quit Docker Desktop
- Click Docker icon in menu bar → "Quit Docker Desktop"

---

## Quick Troubleshooting

### Problem: "Cannot connect to Docker daemon"
**Solution:** Open Docker Desktop and wait 2-3 minutes

### Problem: "This site can't be reached" (http://localhost:80)
**Solution:** Wait 2-3 more minutes, RAGFlow takes time to start

### Problem: "Connection Failed" in iOS app
**Solution:** 
1. Check proxy is running (you should see "Running on http://127.0.0.1:8000" in Terminal)
2. Make sure "Enable SpineAI RAG" toggle is ON in Settings
3. Verify URL is exactly: `http://localhost:8000`

### Problem: App builds but gives weird responses
**Solution:** Make sure you uploaded documents to RAGFlow and parsed them

---

## Emergency Reset

If nothing works, do a full restart:

1. Stop everything (see "Stopping SpineAI" above)
2. Wait 1 minute
3. Start everything again (see "Starting SpineAI" above)
4. Run `./verify_setup.sh` to check status

---

## Need More Help?

1. Read the full guide: [SETUP.md](SETUP.md)
2. Run the verification script: `./verify_setup.sh`
3. Check all services: `docker ps`
4. Contact your supervisor with:
   - Screenshot of the error
   - Output of `docker ps`
   - Which step you're on

---

## Common Commands

```bash
# Check if Docker services are running
docker ps

# Check RAGFlow logs
cd ~/Downloads/ragflow/docker
docker compose logs ragflow

# Check proxy health
curl http://localhost:8000/health

# Restart RAGFlow (if needed)
cd ~/Downloads/ragflow/docker
docker compose restart ragflow
```

---

## URLs to Remember

- **RAGFlow Web**: http://localhost:80
- **Flask Proxy**: http://localhost:8000
- **Proxy Health Check**: http://localhost:8000/health

---

**Last Updated:** December 10, 2025

