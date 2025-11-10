# RAGFlow Backend Quick Start Guide

## Prerequisites

- Docker Desktop installed and running
- OpenAI API key (for embeddings and LLM)
- At least 8GB RAM available for Docker

## Step 1: Setup Environment

1. Navigate to the backend directory:
```bash
cd /Users/madhuhaasgottimukkala/Desktop/SpineAI-1/ragflow-backend
```

2. Create `.env` file from example:
```bash
cp .env.example .env
```

3. Edit `.env` and add your OpenAI API key:
```bash
# Use your preferred editor
nano .env
# or
open .env
```

Update this line:
```
OPENAI_API_KEY=your_actual_openai_api_key_here
```

## Step 2: Start the Backend Services

```bash
# Start all services (RAGFlow, Elasticsearch, MySQL, Redis, MinIO, Proxy)
docker compose up -d

# Check if services are running
docker compose ps

# View logs (useful for debugging)
docker compose logs -f
```

**Wait 2-3 minutes** for all services to initialize (especially Elasticsearch and RAGFlow).

## Step 3: Verify the Services

### Check Health Status
```bash
# Test the proxy health endpoint
curl http://localhost:5000/health
```

Expected response:
```json
{
  "status": "healthy",
  "service": "SpineAI RAGFlow Proxy",
  "timestamp": "..."
}
```

### Access RAGFlow UI (Optional)
Open browser to: http://localhost:8080

## Step 4: Get Authentication Token

```bash
# Get a JWT token for the iOS app
curl -X POST http://localhost:5000/auth/token \
  -H "Content-Type: application/json" \
  -d '{
    "api_key": "spineai_secret_key_change_in_production",
    "user_id": "test_user"
  }'
```

Save the returned token - you'll use it in the iOS app.

## Step 5: Test RAG Query

```bash
# Test a simple query
curl -X POST http://localhost:5000/rag/query \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN_HERE" \
  -d '{
    "query": "What are treatment options for lumbar spinal stenosis?",
    "context": {
      "patient_age": 65,
      "diagnosis": "lumbar spinal stenosis"
    }
  }'
```

## Step 6: Configure iOS App

1. Open Xcode project: `LLMonFHIR.xcodeproj`
2. Build and run the app
3. Go to **Settings** > **RAG Settings**
4. Configure:
   - Server URL: `http://localhost:5000` (or your machine's local IP if testing on device)
   - API Key: `spineai_secret_key_change_in_production`
5. Tap "Save & Authenticate"
6. Verify "Connected" status

## Troubleshooting

### Services won't start
```bash
# Stop everything
docker compose down -v

# Check Docker resources (need 8GB+ RAM)
docker stats

# Restart
docker compose up -d
```

### Connection refused from iOS
- If testing on physical device, use your Mac's local IP instead of localhost
- Find your IP: `ifconfig | grep "inet " | grep -v 127.0.0.1`
- Update Server URL in app to: `http://192.168.x.x:5000`

### Elasticsearch fails
```bash
# Increase vm.max_map_count (macOS/Linux)
sudo sysctl -w vm.max_map_count=262144
```

### View service logs
```bash
# All services
docker compose logs -f

# Specific service
docker compose logs -f spineai-proxy
docker compose logs -f ragflow
```

## Stop Services

```bash
# Stop but keep data
docker compose stop

# Stop and remove containers (keeps volumes)
docker compose down

# Stop and remove everything including data
docker compose down -v
```

## Testing Endpoints

See `test-api.sh` for more API testing examples.

