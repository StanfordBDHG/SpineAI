"""
SpineAI RAGFlow Proxy Service

This proxy service acts as a bridge between the iOS SpineAI app and RAGFlow backend.
It provides authentication, request routing, and data transformation.
"""

import os
import logging
from datetime import datetime, timedelta
from functools import wraps

from flask import Flask, request, jsonify, g
from flask_cors import CORS
import requests
import jwt
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Initialize Flask app
app = Flask(__name__)
CORS(app)

# Configuration
RAGFLOW_API_URL = os.getenv('RAGFLOW_API_URL', 'http://ragflow:80/api')
SECRET_KEY = os.getenv('PROXY_SECRET_KEY', 'spineai_secret_key_change_in_production')
OPENAI_API_KEY = os.getenv('OPENAI_API_KEY', '')

app.config['SECRET_KEY'] = SECRET_KEY


# Authentication decorator
def require_auth(f):
    @wraps(f)
    def decorated_function(*args, **kwargs):
        auth_header = request.headers.get('Authorization')
        
        if not auth_header:
            return jsonify({'error': 'No authorization header'}), 401
        
        try:
            # Extract token from "Bearer <token>"
            token = auth_header.split(' ')[1] if ' ' in auth_header else auth_header
            
            # Verify token
            payload = jwt.decode(token, SECRET_KEY, algorithms=['HS256'])
            g.user_id = payload.get('user_id')
            
        except jwt.ExpiredSignatureError:
            return jsonify({'error': 'Token expired'}), 401
        except jwt.InvalidTokenError:
            return jsonify({'error': 'Invalid token'}), 401
        except Exception as e:
            logger.error(f"Authentication error: {e}")
            return jsonify({'error': 'Authentication failed'}), 401
        
        return f(*args, **kwargs)
    
    return decorated_function


@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    return jsonify({
        'status': 'healthy',
        'service': 'SpineAI RAGFlow Proxy',
        'timestamp': datetime.utcnow().isoformat()
    })


@app.route('/auth/token', methods=['POST'])
def generate_token():
    """Generate JWT token for iOS app authentication"""
    data = request.json
    
    # In production, validate credentials against a user database
    # For now, we'll use a simple API key validation
    api_key = data.get('api_key')
    user_id = data.get('user_id', 'default_user')
    
    if not api_key or api_key != SECRET_KEY:
        return jsonify({'error': 'Invalid API key'}), 401
    
    # Generate JWT token
    payload = {
        'user_id': user_id,
        'exp': datetime.utcnow() + timedelta(days=30)  # Token expires in 30 days
    }
    
    token = jwt.encode(payload, SECRET_KEY, algorithm='HS256')
    
    return jsonify({
        'token': token,
        'expires_in': 30 * 24 * 3600  # 30 days in seconds
    })


@app.route('/rag/knowledge-base', methods=['POST'])
@require_auth
def create_knowledge_base():
    """Create a new knowledge base for medical documents"""
    data = request.json
    
    try:
        response = requests.post(
            f"{RAGFLOW_API_URL}/knowledge_base",
            json=data,
            timeout=30
        )
        
        return jsonify(response.json()), response.status_code
        
    except requests.RequestException as e:
        logger.error(f"Error creating knowledge base: {e}")
        return jsonify({'error': 'Failed to create knowledge base'}), 500


@app.route('/rag/knowledge-base/<kb_id>/documents', methods=['POST'])
@require_auth
def upload_document(kb_id):
    """Upload a medical document to a knowledge base"""
    
    if 'file' not in request.files:
        return jsonify({'error': 'No file provided'}), 400
    
    file = request.files['file']
    
    try:
        # Forward file to RAGFlow
        files = {'file': (file.filename, file.stream, file.content_type)}
        
        response = requests.post(
            f"{RAGFLOW_API_URL}/knowledge_base/{kb_id}/documents",
            files=files,
            timeout=60
        )
        
        return jsonify(response.json()), response.status_code
        
    except requests.RequestException as e:
        logger.error(f"Error uploading document: {e}")
        return jsonify({'error': 'Failed to upload document'}), 500


@app.route('/rag/query', methods=['POST'])
@require_auth
def rag_query():
    """
    Perform RAG-enhanced query for spine surgery recommendations
    
    Expected request body:
    {
        "query": "What treatment options are recommended for lumbar spinal stenosis?",
        "context": {
            "patient_age": 65,
            "diagnosis": "lumbar spinal stenosis",
            "imaging_findings": "...",
            "medical_history": "..."
        },
        "knowledge_base_id": "optional_kb_id"
    }
    """
    data = request.json
    query = data.get('query')
    context = data.get('context', {})
    kb_id = data.get('knowledge_base_id')
    
    if not query:
        return jsonify({'error': 'Query is required'}), 400
    
    try:
        # Prepare enhanced query with medical context
        enhanced_query = f"""
Patient Context:
- Age: {context.get('patient_age', 'Not specified')}
- Diagnosis: {context.get('diagnosis', 'Not specified')}
- Imaging Findings: {context.get('imaging_findings', 'Not specified')}
- Medical History: {context.get('medical_history', 'Not specified')}

Query: {query}

Please provide evidence-based recommendations including:
1. Treatment options (conservative vs surgical)
2. Success rates and outcomes
3. Risks and contraindications
4. Evidence from clinical literature
"""
        
        # Query RAGFlow
        ragflow_request = {
            'query': enhanced_query,
            'knowledge_base_id': kb_id,
            'top_k': 5  # Retrieve top 5 relevant documents
        }
        
        response = requests.post(
            f"{RAGFLOW_API_URL}/query",
            json=ragflow_request,
            timeout=30
        )
        
        if response.status_code == 200:
            result = response.json()
            
            # Format response for iOS app
            formatted_response = {
                'answer': result.get('answer', ''),
                'sources': result.get('sources', []),
                'confidence': result.get('confidence', 0.0),
                'timestamp': datetime.utcnow().isoformat()
            }
            
            return jsonify(formatted_response), 200
        else:
            return jsonify({'error': 'RAGFlow query failed'}), response.status_code
            
    except requests.RequestException as e:
        logger.error(f"Error querying RAGFlow: {e}")
        return jsonify({'error': 'Failed to query RAGFlow'}), 500


@app.route('/rag/analyze-fhir', methods=['POST'])
@require_auth
def analyze_fhir_data():
    """
    Analyze FHIR health records with RAG-enhanced insights
    
    Expected request body:
    {
        "fhir_resources": [...],  # Array of FHIR resources
        "query": "What treatment recommendations can you provide based on this data?"
    }
    """
    data = request.json
    fhir_resources = data.get('fhir_resources', [])
    query = data.get('query', 'Analyze this patient data and provide treatment recommendations')
    
    if not fhir_resources:
        return jsonify({'error': 'FHIR resources are required'}), 400
    
    try:
        # Extract relevant medical information from FHIR resources
        patient_context = extract_patient_context(fhir_resources)
        
        # Create comprehensive query with FHIR data
        enhanced_query = f"""
Patient Health Record Summary:
{patient_context}

Clinical Question: {query}

Please provide:
1. Analysis of the patient's condition
2. Evidence-based treatment recommendations
3. Potential risks and considerations
4. Relevant clinical guidelines and literature
"""
        
        # Query RAGFlow with enhanced context
        ragflow_request = {
            'query': enhanced_query,
            'top_k': 5
        }
        
        response = requests.post(
            f"{RAGFLOW_API_URL}/query",
            json=ragflow_request,
            timeout=30
        )
        
        if response.status_code == 200:
            result = response.json()
            
            return jsonify({
                'analysis': result.get('answer', ''),
                'sources': result.get('sources', []),
                'patient_summary': patient_context,
                'timestamp': datetime.utcnow().isoformat()
            }), 200
        else:
            return jsonify({'error': 'Analysis failed'}), response.status_code
            
    except Exception as e:
        logger.error(f"Error analyzing FHIR data: {e}")
        return jsonify({'error': str(e)}), 500


def extract_patient_context(fhir_resources):
    """Extract relevant medical information from FHIR resources"""
    context_parts = []
    
    for resource in fhir_resources:
        resource_type = resource.get('resourceType', 'Unknown')
        
        if resource_type == 'Patient':
            # Extract patient demographics
            name = resource.get('name', [{}])[0]
            gender = resource.get('gender', 'unknown')
            birth_date = resource.get('birthDate', 'unknown')
            
            context_parts.append(f"Patient: {name.get('given', [''])[0]} {name.get('family', '')}")
            context_parts.append(f"Gender: {gender}, Birth Date: {birth_date}")
            
        elif resource_type == 'Condition':
            # Extract diagnoses
            code = resource.get('code', {})
            text = code.get('text', code.get('coding', [{}])[0].get('display', 'Unknown condition'))
            context_parts.append(f"Condition: {text}")
            
        elif resource_type == 'Observation':
            # Extract vital signs and lab results
            code = resource.get('code', {})
            text = code.get('text', code.get('coding', [{}])[0].get('display', 'Unknown observation'))
            value = resource.get('valueQuantity', {})
            
            if value:
                context_parts.append(f"Observation: {text} = {value.get('value', '')} {value.get('unit', '')}")
            
        elif resource_type == 'Procedure':
            # Extract procedures
            code = resource.get('code', {})
            text = code.get('text', code.get('coding', [{}])[0].get('display', 'Unknown procedure'))
            context_parts.append(f"Procedure: {text}")
    
    return '\n'.join(context_parts) if context_parts else 'No patient context available'


@app.route('/rag/spine-recommendation', methods=['POST'])
@require_auth
def spine_surgery_recommendation():
    """
    Specialized endpoint for spine surgery treatment recommendations
    
    Expected request body:
    {
        "patient_data": {
            "age": 65,
            "diagnosis": "lumbar spinal stenosis",
            "imaging": {...},
            "symptoms": [...],
            "medical_history": {...}
        }
    }
    """
    data = request.json
    patient_data = data.get('patient_data', {})
    
    if not patient_data:
        return jsonify({'error': 'Patient data is required'}), 400
    
    try:
        # Create specialized query for spine surgery recommendations
        query = f"""
Spine Surgery Consultation Request:

Patient Profile:
- Age: {patient_data.get('age', 'Not specified')}
- Primary Diagnosis: {patient_data.get('diagnosis', 'Not specified')}
- Symptoms: {', '.join(patient_data.get('symptoms', ['Not specified']))}
- Relevant Medical History: {patient_data.get('medical_history', {}).get('summary', 'Not specified')}

Imaging Findings:
{format_imaging_data(patient_data.get('imaging', {}))}

Please provide:
1. Conservative treatment options with expected outcomes
2. Surgical treatment options with evidence-based success rates
3. Risk-benefit analysis for each approach
4. Patient selection criteria from clinical guidelines
5. Recovery timelines and rehabilitation considerations
6. Relevant clinical studies and meta-analyses
"""
        
        # Query RAGFlow
        response = requests.post(
            f"{RAGFLOW_API_URL}/query",
            json={'query': query, 'top_k': 10},
            timeout=30
        )
        
        if response.status_code == 200:
            result = response.json()
            
            return jsonify({
                'recommendations': result.get('answer', ''),
                'evidence_sources': result.get('sources', []),
                'confidence_score': result.get('confidence', 0.0),
                'timestamp': datetime.utcnow().isoformat()
            }), 200
        else:
            return jsonify({'error': 'Failed to generate recommendations'}), response.status_code
            
    except Exception as e:
        logger.error(f"Error generating spine surgery recommendations: {e}")
        return jsonify({'error': str(e)}), 500


def format_imaging_data(imaging):
    """Format imaging data for query"""
    if not imaging:
        return "No imaging data available"
    
    parts = []
    for modality, findings in imaging.items():
        parts.append(f"{modality}: {findings}")
    
    return '\n'.join(parts)


if __name__ == '__main__':
    # Run with gunicorn in production
    app.run(host='0.0.0.0', port=5000, debug=False)

