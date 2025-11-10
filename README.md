# SpineAI: AI-Driven Clinical Decision Support for Spine Surgery

## Overview

SpineAI is an enhanced mobile health application that provides evidence-based clinical decision support for spine surgery. Building on the Stanford LLM on FHIR framework, SpineAI integrates Retrieval-Augmented Generation (RAG) technology to deliver treatment recommendations grounded in medical literature rather than relying solely on language model generation.

### Clinical Problem

Patients with spinal pathology, particularly lumbar spinal stenosis, face significant challenges:
- Inconsistent treatment recommendations across healthcare providers
- Difficulty understanding complex medical information
- Uncertainty about conservative versus surgical treatment options
- Limited access to evidence-based decision-making tools

SpineAI addresses these challenges by combining patient health records with real-time medical literature retrieval to support informed clinical decisions.

## Key Features

### 1. Evidence-Based Treatment Recommendations
- Analyzes patient FHIR health records from Apple HealthKit
- Retrieves relevant medical literature and clinical guidelines
- Generates personalized treatment recommendations
- Provides source citations with confidence scores

### 2. RAG-Enhanced Conversational Interface
- Natural language queries about spine surgery
- Responses grounded in medical literature
- Automatic patient context integration
- Real-time source citation

### 3. Comprehensive Health Data Integration
- FHIR-compliant health record processing
- Apple HealthKit connectivity
- Patient demographics and medical history
- Diagnostic imaging results
- Treatment and medication history

## Technical Architecture

SpineAI implements a three-tier architecture:

**iOS Application Layer:**
- Swift and SwiftUI user interfaces
- FHIR resource management
- Real-time data synchronization

**API Gateway Layer:**
- Python Flask microservice
- JWT authentication
- Medical query optimization
- Request routing and transformation

**RAG Engine Layer:**
- RAGFlow for document retrieval
- Elasticsearch for full-text search
- MySQL for metadata management
- Redis for caching
- MinIO for object storage

For detailed technical documentation, see [RAGFLOW_INTEGRATION.md](RAGFLOW_INTEGRATION.md).

## Installation

### Prerequisites
- macOS 14.0 or later
- Xcode 15.0 or later
- Docker Desktop 4.0+
- OpenAI API key
- 8GB+ RAM for backend services

### Quick Start

1. **Clone the repository:**
   ```bash
   git clone <repository-url>
   cd SpineAI-1
   ```

2. **Start backend services:**
   ```bash
   cd ragflow-backend
   cp .env.example .env
   # Edit .env with your OpenAI API key
   docker compose up -d
   ```

3. **Open iOS application:**
   ```bash
   open LLMonFHIR.xcodeproj
   ```

4. **Build and run:**
   - Press Cmd+B to build
   - Press Cmd+R to run on simulator

5. **Configure RAGFlow:**
   - Navigate to Settings > RAG Enhancement > RAGFlow Configuration
   - Enter server URL: `http://localhost:5001`
   - Enter API key from .env file
   - Test connection

For detailed setup instructions, see [ragflow-backend/QUICKSTART.md](ragflow-backend/QUICKSTART.md).

## Usage

### Spine Surgery Treatment Recommendations

1. Navigate to **Settings** > **RAG Enhancement** > **Spine Surgery Recommendations**
2. Enter patient information:
   - Age and diagnosis
   - Symptoms and duration
   - Imaging findings
   - Medical history (optional)
3. Tap **Get AI Recommendations**
4. Review treatment options with evidence sources

### Conversational Queries

1. Access the RAG-Enhanced Chat interface
2. Ask natural language questions such as:
   - "What are the treatment options for lumbar spinal stenosis?"
   - "What are the success rates of spinal fusion?"
   - "When is conservative treatment preferred?"
3. Receive evidence-based responses with source citations

## Documentation

- **[RAGFLOW_INTEGRATION.md](RAGFLOW_INTEGRATION.md)** - Comprehensive technical documentation
- **[ragflow-backend/QUICKSTART.md](ragflow-backend/QUICKSTART.md)** - Backend setup guide
- **[ragflow-backend/INTEGRATION_COMPLETE.md](ragflow-backend/INTEGRATION_COMPLETE.md)** - Deployment guide

## Project Structure

```
SpineAI-1/
├── ragflow-backend/          # Backend services and API
│   ├── docker-compose.yml    # Service orchestration
│   ├── proxy/               # Flask microservice
│   └── docs/                # Backend documentation
│
├── LLMonFHIR/               # iOS application
│   ├── RAGFlow/            # RAG integration module
│   ├── FHIRInterpretation/ # FHIR processing
│   ├── Settings/           # Application settings
│   └── Resources/          # App resources
│
└── Documentation/
    ├── RAGFLOW_INTEGRATION.md
    └── README.md (this file)
```

## Technology Stack

**Frontend:**
- Swift 5.9+
- SwiftUI
- Spezi Framework
- SpeziFHIR
- SpeziLLM

**Backend:**
- Python 3.10+
- Flask 3.0
- RAGFlow v0.21.1
- Docker Compose

**Infrastructure:**
- Elasticsearch 8.11.3
- MySQL 8.0
- Redis 7
- MinIO

## Testing

### Backend Services
```bash
cd ragflow-backend
./test-api.sh
```

### iOS Application
1. Build the application in Xcode
2. Run on iOS Simulator or physical device
3. Test RAGFlow connection in Settings
4. Verify treatment recommendation workflow
5. Test conversational interface

## Disclaimer

SpineAI is an experimental clinical decision support tool designed for research and educational purposes.

**Important Limitations:**
- Not a substitute for professional medical advice
- AI-generated recommendations may contain errors
- Always consult qualified healthcare providers
- Intended for demonstration purposes only
- Patient data sent to backend services for processing

Users must review and comply with the [OpenAI API data usage policies](https://openai.com/policies/api-data-usage-policies) when using this application.

## HealthKit Integration

SpineAI requires access to FHIR health records stored in Apple Health. Users can control which health record types the application can access.

For testing without real health data, the application supports [Synthea](https://doi.org/10.1093/jamia/ocx079)-based synthetic patients via [SpeziFHIRMockPatients](https://github.com/StanfordSpezi/SpeziFHIR/tree/main/Sources/SpeziFHIRMockPatients).

## Security and Privacy

- On-device FHIR processing
- Minimal data transmission (anonymized clinical context)
- JWT-based authentication
- Self-hosted infrastructure option
- No persistent storage of patient health information

## Contributing

This project builds on the [Stanford LLM on FHIR](https://github.com/PSchmiedmayer/LLMonFHIR) application and extends it with RAG capabilities for spine surgery decision support.

## License

This project extends the LLM on FHIR application and maintains the MIT License.

See [LICENSE.md](LICENSE.md) for details.

## Acknowledgments

- Stanford Spezi Team for the application framework
- Stanford LLM on FHIR project as the foundation
- RAGFlow community for the open-source RAG engine
- Contributors listed in [CONTRIBUTORS.md](CONTRIBUTORS.md)

## Contact

For technical questions or issues:
- Review documentation in `ragflow-backend/` directory
- Consult [RAGFLOW_INTEGRATION.md](RAGFLOW_INTEGRATION.md) for technical details
- Check `proxy/app.py` for API documentation

---

**Version:** 1.0.0  
**Status:** Production Ready  
**Last Updated:** November 2025
