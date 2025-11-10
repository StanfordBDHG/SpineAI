//
// This source file is part of the SpineAI project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import Combine

/// Client for communicating with the RAGFlow backend service
@MainActor
class RAGFlowClient: ObservableObject {
    // MARK: - Published Properties
    
    @Published var isConnected: Bool = false
    @Published var lastError: String?
    
    // MARK: - Private Properties
    
    private let baseURL: URL
    private let session: URLSession
    private var authToken: String?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    /// Initialize the RAGFlow client
    /// - Parameters:
    ///   - baseURL: The base URL of the RAGFlow proxy service (default: http://localhost:5000)
    ///   - apiKey: The API key for authentication (stored in UserDefaults)
    init(baseURL: String = "http://localhost:5000", apiKey: String? = nil) {
        guard let url = URL(string: baseURL) else {
            fatalError("Invalid RAGFlow base URL: \(baseURL)")
        }
        
        self.baseURL = url
        
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: configuration)
        
        // Load stored auth token if available
        self.authToken = UserDefaults.standard.string(forKey: "ragflow_auth_token")
        
        Task {
            await checkConnection()
        }
    }
    
    // MARK: - Authentication
    
    /// Authenticate with the RAGFlow service
    /// - Parameters:
    ///   - apiKey: The API key for authentication
    ///   - userId: Optional user ID
    func authenticate(apiKey: String, userId: String = "default_user") async throws {
        let endpoint = baseURL.appendingPathComponent("auth/token")
        
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "api_key": apiKey,
            "user_id": userId
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw RAGFlowError.authenticationFailed
        }
        
        let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
        self.authToken = authResponse.token
        
        // Store token for future use
        UserDefaults.standard.set(authResponse.token, forKey: "ragflow_auth_token")
        
        isConnected = true
    }
    
    // MARK: - Health Check
    
    /// Check connection to RAGFlow service
    func checkConnection() async {
        let endpoint = baseURL.appendingPathComponent("health")
        
        do {
            let (data, response) = try await session.data(from: endpoint)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                isConnected = false
                return
            }
            
            let healthResponse = try JSONDecoder().decode(HealthResponse.self, from: data)
            isConnected = healthResponse.status == "healthy"
        } catch {
            isConnected = false
            lastError = "Failed to connect to RAGFlow service: \(error.localizedDescription)"
        }
    }
    
    // MARK: - RAG Query
    
    /// Perform a RAG-enhanced query
    /// - Parameters:
    ///   - query: The natural language query
    ///   - context: Optional patient context information
    ///   - knowledgeBaseId: Optional knowledge base ID to query
    /// - Returns: RAG query response with answer and sources
    func performQuery(
        query: String,
        context: PatientContext? = nil,
        knowledgeBaseId: String? = nil
    ) async throws -> RAGQueryResponse {
        guard let token = authToken else {
            throw RAGFlowError.notAuthenticated
        }
        
        let endpoint = baseURL.appendingPathComponent("rag/query")
        
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        var body: [String: Any] = ["query": query]
        
        if let context = context {
            body["context"] = [
                "patient_age": context.age ?? 0,
                "diagnosis": context.diagnosis ?? "",
                "imaging_findings": context.imagingFindings ?? "",
                "medical_history": context.medicalHistory ?? ""
            ]
        }
        
        if let kbId = knowledgeBaseId {
            body["knowledge_base_id"] = kbId
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw RAGFlowError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 401 {
                throw RAGFlowError.notAuthenticated
            }
            throw RAGFlowError.serverError(httpResponse.statusCode)
        }
        
        return try JSONDecoder().decode(RAGQueryResponse.self, from: data)
    }
    
    // MARK: - FHIR Analysis
    
    /// Analyze FHIR health records with RAG-enhanced insights
    /// - Parameters:
    ///   - fhirResources: Array of FHIR resources to analyze
    ///   - query: Optional specific query about the data
    /// - Returns: Analysis response with recommendations and sources
    func analyzeFHIRData(
        fhirResources: [[String: Any]],
        query: String = "What treatment recommendations can you provide based on this data?"
    ) async throws -> FHIRAnalysisResponse {
        guard let token = authToken else {
            throw RAGFlowError.notAuthenticated
        }
        
        let endpoint = baseURL.appendingPathComponent("rag/analyze-fhir")
        
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let body: [String: Any] = [
            "fhir_resources": fhirResources,
            "query": query
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw RAGFlowError.serverError((response as? HTTPURLResponse)?.statusCode ?? 500)
        }
        
        return try JSONDecoder().decode(FHIRAnalysisResponse.self, from: data)
    }
    
    // MARK: - Spine Surgery Recommendations
    
    /// Get specialized spine surgery treatment recommendations
    /// - Parameter patientData: Patient data including diagnosis, imaging, symptoms, etc.
    /// - Returns: Spine surgery recommendation response
    func getSpineSurgeryRecommendation(
        patientData: SpinePatientData
    ) async throws -> SpineRecommendationResponse {
        guard let token = authToken else {
            throw RAGFlowError.notAuthenticated
        }
        
        let endpoint = baseURL.appendingPathComponent("rag/spine-recommendation")
        
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let body = try encoder.encode(["patient_data": patientData])
        request.httpBody = body
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw RAGFlowError.serverError((response as? HTTPURLResponse)?.statusCode ?? 500)
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(SpineRecommendationResponse.self, from: data)
    }
    
    // MARK: - Knowledge Base Management
    
    /// Create a new knowledge base for medical documents
    /// - Parameters:
    ///   - name: Name of the knowledge base
    ///   - description: Description of the knowledge base
    /// - Returns: Knowledge base ID
    func createKnowledgeBase(name: String, description: String) async throws -> String {
        guard let token = authToken else {
            throw RAGFlowError.notAuthenticated
        }
        
        let endpoint = baseURL.appendingPathComponent("rag/knowledge-base")
        
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let body: [String: Any] = [
            "name": name,
            "description": description
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw RAGFlowError.serverError((response as? HTTPURLResponse)?.statusCode ?? 500)
        }
        
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let kbId = json["knowledge_base_id"] as? String {
            return kbId
        }
        
        throw RAGFlowError.invalidResponse
    }
}

// MARK: - Data Models

/// Patient context for RAG queries
struct PatientContext: Codable {
    let age: Int?
    let diagnosis: String?
    let imagingFindings: String?
    let medicalHistory: String?
}

/// Spine patient data for specialized recommendations
struct SpinePatientData: Codable {
    let age: Int?
    let diagnosis: String?
    let symptoms: [String]?
    let imaging: [String: String]?
    let medicalHistory: MedicalHistory?
    
    struct MedicalHistory: Codable {
        let summary: String?
        let previousSurgeries: [String]?
        let comorbidities: [String]?
    }
}

/// Response from authentication endpoint
struct AuthResponse: Codable {
    let token: String
    let expiresIn: Int
    
    enum CodingKeys: String, CodingKey {
        case token
        case expiresIn = "expires_in"
    }
}

/// Response from health check endpoint
struct HealthResponse: Codable {
    let status: String
    let service: String
    let timestamp: String
}

/// Response from RAG query
struct RAGQueryResponse: Codable {
    let answer: String
    let sources: [RAGSource]
    let confidence: Double?
    let timestamp: String
}

/// Source reference from RAG
struct RAGSource: Codable, Identifiable {
    let id: String
    let title: String?
    let content: String?
    let relevanceScore: Double?
    let url: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case content
        case relevanceScore = "relevance_score"
        case url
    }
}

/// Response from FHIR analysis
struct FHIRAnalysisResponse: Codable {
    let analysis: String
    let sources: [RAGSource]
    let patientSummary: String
    let timestamp: String
    
    enum CodingKeys: String, CodingKey {
        case analysis
        case sources
        case patientSummary = "patient_summary"
        case timestamp
    }
}

/// Response from spine surgery recommendation
struct SpineRecommendationResponse: Codable {
    let recommendations: String
    let evidenceSources: [RAGSource]
    let confidenceScore: Double
    let timestamp: String
    
    enum CodingKeys: String, CodingKey {
        case recommendations
        case evidenceSources = "evidence_sources"
        case confidenceScore = "confidence_score"
        case timestamp
    }
}

// MARK: - Errors

/// Errors that can occur when using RAGFlow client
enum RAGFlowError: LocalizedError {
    case notAuthenticated
    case authenticationFailed
    case invalidResponse
    case serverError(Int)
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Not authenticated. Please authenticate first."
        case .authenticationFailed:
            return "Authentication failed. Please check your API key."
        case .invalidResponse:
            return "Invalid response from server."
        case .serverError(let code):
            return "Server error: \(code)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

