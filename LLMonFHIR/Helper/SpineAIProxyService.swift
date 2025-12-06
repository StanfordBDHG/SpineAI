//
// This source file is part of the Stanford Spezi project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation


// MARK: - Errors

enum ProxyError: LocalizedError {
    case invalidResponse
    case serverError(statusCode: Int)
    case uploadFailed(statusCode: Int)
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            "Invalid response from proxy server"
        case .serverError(let statusCode):
            "Server error: \(statusCode)"
        case .uploadFailed(let statusCode):
            "Upload failed: \(statusCode)"
        case .networkError(let error):
            "Network error: \(error.localizedDescription)"
        }
    }
}


// MARK: - Response Models

/// Response from RAGFlow query
struct RAGFlowResponse: Codable {
    struct Reference: Codable {
        let content: String
        let source: String?
        let page: Int?
    }
    
    let answer: String
    let conversationId: String?
    let references: [Reference]
}


/// Response from upload URL request
struct UploadURLResponse: Codable {
    let uploadUrl: String
    let filename: String
    let bucket: String
    let expiresIn: Int
    
    var url: URL? {
        URL(string: uploadUrl)
    }
}


/// Health check response
struct HealthResponse: Codable {
    struct ConfigStatus: Codable {
        let ragflowConfigured: Bool
        let ragflowUrl: String
        let gcsConfigured: Bool
        let gcsBucket: String?
    }
    
    let status: String
    let service: String
    let version: String
    let config: ConfigStatus
}


// MARK: - SpineAI Proxy Service

/// Service to communicate with the SpineAI RAG proxy server
///
/// This service handles:
/// - Querying RAGFlow for spine imaging guidance via the proxy
/// - Generating signed upload URLs for storing encrypted chat results
@MainActor
class SpineAIProxyService {
    private let baseURL: URL
    private let session: URLSession
    
    /// Initialize with custom proxy URL
    /// - Parameter proxyURL: Base URL of the proxy server (e.g., "https://proxy.spineai.stanford.edu")
    init(proxyURL: String = StorageKeys.currentProxyURL) {
        guard let url = URL(string: proxyURL) else {
            fatalError("Invalid proxy URL: \(proxyURL)")
        }
        self.baseURL = url
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
    }
    
    // MARK: - Query RAGFlow
    
    /// Query RAGFlow for spine imaging guidance
    /// - Parameters:
    ///   - question: The clinical question to ask
    ///   - conversationID: Optional conversation ID to continue an existing conversation
    /// - Returns: RAGFlow response with answer and citations
    func query(question: String, conversationID: String? = nil) async throws -> RAGFlowResponse {
        let endpoint = baseURL.appendingPathComponent("query")
        
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var payload: [String: Any] = ["question": question]
        if let conversationID = conversationID {
            payload["conversation_id"] = conversationID
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ProxyError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw ProxyError.serverError(statusCode: httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(RAGFlowResponse.self, from: data)
    }
    
    // MARK: - Upload URL Generation
    
    /// Get a signed URL for uploading chat results to Google Cloud Storage
    /// - Parameter filename: Optional custom filename (defaults to timestamp-based name)
    /// - Returns: Signed upload URL and metadata
    func getUploadURL(filename: String? = nil) async throws -> UploadURLResponse {
        let endpoint = baseURL.appendingPathComponent("upload-url")
        
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var payload: [String: Any] = [:]
        if let filename = filename {
            payload["filename"] = filename
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ProxyError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw ProxyError.serverError(statusCode: httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(UploadURLResponse.self, from: data)
    }
    
    /// Upload encrypted chat data to GCS using a signed URL
    /// - Parameters:
    ///   - data: The encrypted chat data to upload
    ///   - uploadURL: The signed upload URL from getUploadURL()
    func uploadChatResults(data: Data, to uploadURL: URL) async throws {
        var request = URLRequest(url: uploadURL)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = data
        
        let (_, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ProxyError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw ProxyError.uploadFailed(statusCode: httpResponse.statusCode)
        }
    }
    
    // MARK: - Health Check
    
    /// Check if the proxy server is healthy and properly configured
    /// - Returns: Health status including configuration
    func healthCheck() async throws -> HealthResponse {
        let endpoint = baseURL.appendingPathComponent("health")
        
        let (data, response) = try await session.data(from: endpoint)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ProxyError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw ProxyError.serverError(statusCode: httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(HealthResponse.self, from: data)
    }
}
