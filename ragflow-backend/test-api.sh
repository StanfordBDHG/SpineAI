#!/bin/bash

# SpineAI RAGFlow API Test Script
# This script tests the RAGFlow proxy API endpoints

BASE_URL="http://localhost:5001"
API_KEY="spineai_secret_key_change_in_production"

echo "🧪 Testing SpineAI RAGFlow API"
echo "================================"
echo ""

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test 1: Health Check
echo -e "${BLUE}Test 1: Health Check${NC}"
echo "GET $BASE_URL/health"
response=$(curl -s $BASE_URL/health)
echo "$response" | jq '.'
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Health check passed${NC}"
else
    echo -e "${RED}✗ Health check failed${NC}"
fi
echo ""

# Test 2: Get Authentication Token
echo -e "${BLUE}Test 2: Authentication${NC}"
echo "POST $BASE_URL/auth/token"
auth_response=$(curl -s -X POST $BASE_URL/auth/token \
  -H "Content-Type: application/json" \
  -d "{
    \"api_key\": \"$API_KEY\",
    \"user_id\": \"test_user\"
  }")
echo "$auth_response" | jq '.'

TOKEN=$(echo "$auth_response" | jq -r '.token')
if [ "$TOKEN" != "null" ] && [ -n "$TOKEN" ]; then
    echo -e "${GREEN}✓ Authentication successful${NC}"
    echo "Token: ${TOKEN:0:20}..."
else
    echo -e "${RED}✗ Authentication failed${NC}"
    exit 1
fi
echo ""

# Test 3: Simple RAG Query
echo -e "${BLUE}Test 3: RAG Query${NC}"
echo "POST $BASE_URL/rag/query"
curl -s -X POST $BASE_URL/rag/query \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "query": "What are the treatment options for lumbar spinal stenosis?",
    "context": {
      "patient_age": 65,
      "diagnosis": "lumbar spinal stenosis"
    }
  }' | jq '.'
echo ""

# Test 4: Spine Surgery Recommendation
echo -e "${BLUE}Test 4: Spine Surgery Recommendation${NC}"
echo "POST $BASE_URL/rag/spine-recommendation"
curl -s -X POST $BASE_URL/rag/spine-recommendation \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "patient_data": {
      "age": 65,
      "diagnosis": "lumbar spinal stenosis",
      "symptoms": ["back pain", "leg numbness", "difficulty walking"],
      "imaging": {
        "MRI": "Central canal stenosis at L4-L5 with nerve root compression"
      },
      "medical_history": {
        "summary": "Hypertension, controlled with medication"
      }
    }
  }' | jq '.'
echo ""

# Test 5: FHIR Analysis (with sample data)
echo -e "${BLUE}Test 5: FHIR Data Analysis${NC}"
echo "POST $BASE_URL/rag/analyze-fhir"
curl -s -X POST $BASE_URL/rag/analyze-fhir \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "fhir_resources": [
      {
        "resourceType": "Patient",
        "name": [{"given": ["John"], "family": "Doe"}],
        "gender": "male",
        "birthDate": "1958-01-01"
      },
      {
        "resourceType": "Condition",
        "code": {
          "text": "Lumbar spinal stenosis"
        }
      },
      {
        "resourceType": "Observation",
        "code": {
          "text": "Pain level"
        },
        "valueQuantity": {
          "value": 7,
          "unit": "score"
        }
      }
    ],
    "query": "What treatment approach would you recommend?"
  }' | jq '.'
echo ""

echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}All tests completed!${NC}"

