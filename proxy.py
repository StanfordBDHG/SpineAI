"""
Minimal RAG Proxy for SpineAI
Sits between LLMonFHIR app and RAGFlow
"""
from flask import Flask, request, jsonify
import requests
from datetime import datetime, timedelta
from google.cloud import storage
import os
import logging

# Setup logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)

# RAGFlow config - can point to K8S deployment
RAGFLOW_URL = os.getenv("RAGFLOW_URL", "http://localhost:9380/api/v1")
RAGFLOW_API_KEY = os.getenv("RAGFLOW_API_KEY", "")

# GCS config
GCS_BUCKET = os.getenv("GCS_BUCKET", "spineai-chat-results")
GCS_PROJECT_ID = os.getenv("GCS_PROJECT_ID", "")

@app.route("/health", methods=["GET"])
def health():
    """Health check with configuration status"""
    config_status = {
        "ragflow_configured": bool(RAGFLOW_API_KEY),
        "ragflow_url": RAGFLOW_URL,
        "gcs_configured": bool(GCS_BUCKET),
        "gcs_bucket": GCS_BUCKET if GCS_BUCKET else None
    }
    
    return jsonify({
        "status": "ok",
        "service": "spineai-proxy",
        "version": "1.0.0",
        "config": config_status
    })

@app.route("/query", methods=["POST"])
def query():
    """Forward query to RAGFlow and get spine-related medical guidance"""
    try:
        data = request.json
        question = data.get("question")
        conversation_id = data.get("conversation_id")  # Optional: to continue a conversation
        
        if not question:
            return jsonify({"error": "question is required"}), 400
        
        if not RAGFLOW_API_KEY:
            logger.error("RAGFLOW_API_KEY not set")
            return jsonify({"error": "RAGFlow API key not configured"}), 500
        
        logger.info(f"Querying RAGFlow: {question[:100]}...")
        
        # Call RAGFlow API
        # First create/get session, then send message
        chat_id = "8d19a384d25d11f0b8fa76278ce0f2bf"  # SpineAI Assistant ID
        
        # Create a session if no conversation_id provided
        if not conversation_id:
            session_response = requests.post(
                f"{RAGFLOW_URL}/chats/{chat_id}/sessions",
                headers={
                    "Authorization": f"Bearer {RAGFLOW_API_KEY}",
                    "Content-Type": "application/json"
                },
                json={"name": "Spine Imaging Query"},
                timeout=10
            )
            session_response.raise_for_status()
            conversation_id = session_response.json().get("data", {}).get("id")
        
        # Send question to RAGFlow
        payload = {
            "question": question,
            "stream": False,
            "session_id": conversation_id
        }
        
        response = requests.post(
            f"{RAGFLOW_URL}/chats/{chat_id}/completions",
            headers={
                "Authorization": f"Bearer {RAGFLOW_API_KEY}",
                "Content-Type": "application/json"
            },
            json=payload,
            timeout=30
        )
        
        response.raise_for_status()
        result = response.json()
        
        logger.info(f"RAGFlow response received")
        return jsonify(result)
    
    except requests.exceptions.Timeout:
        logger.error("RAGFlow request timeout")
        return jsonify({"error": "Request timeout"}), 504
    except requests.exceptions.RequestException as e:
        logger.error(f"RAGFlow request failed: {str(e)}")
        return jsonify({"error": f"RAGFlow connection failed: {str(e)}"}), 502
    except Exception as e:
        logger.error(f"Unexpected error: {str(e)}")
        return jsonify({"error": str(e)}), 500

@app.route("/upload-url", methods=["POST"])
def get_upload_url():
    """Generate one-time signed URL for GCS upload"""
    try:
        data = request.json or {}
        filename = data.get("filename", f"chat_{datetime.now().isoformat()}.json")
        
        if not GCS_BUCKET:
            logger.error("GCS_BUCKET not configured")
            return jsonify({"error": "Storage bucket not configured"}), 500
        
        logger.info(f"Generating upload URL for: {filename}")
        
        # Initialize GCS client
        if GCS_PROJECT_ID:
            storage_client = storage.Client(project=GCS_PROJECT_ID)
        else:
            storage_client = storage.Client()
            
        bucket = storage_client.bucket(GCS_BUCKET)
        blob = bucket.blob(filename)
        
        # Generate signed URL (valid for 15 minutes)
        # One-time use for PUT upload
        url = blob.generate_signed_url(
            version="v4",
            expiration=timedelta(minutes=15),
            method="PUT",
            content_type="application/json"
        )
        
        logger.info(f"Upload URL generated successfully")
        
        return jsonify({
            "upload_url": url,
            "filename": filename,
            "bucket": GCS_BUCKET,
            "expires_in": 900  # 15 minutes in seconds
        })
    
    except Exception as e:
        logger.error(f"Failed to generate upload URL: {str(e)}")
        return jsonify({"error": str(e)}), 500

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8000, debug=True)

