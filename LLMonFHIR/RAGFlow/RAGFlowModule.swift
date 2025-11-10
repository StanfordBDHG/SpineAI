//
// This source file is part of the SpineAI project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Spezi
import SpeziLocalStorage
import SwiftUI

/// Module that provides RAG (Retrieval-Augmented Generation) functionality via RAGFlow
class RAGFlowModule: Module, DefaultInitializable, EnvironmentAccessible {
    @Dependency(LocalStorage.self) private var localStorage
    
    @Model private var ragflowClient: RAGFlowClient
    
    required init() {}
    
    func configure() {
        // Initialize RAGFlow client with stored configuration
        let baseURL = UserDefaults.standard.string(forKey: "ragflow_base_url") ?? "http://localhost:5000"
        let apiKey = UserDefaults.standard.string(forKey: "ragflow_api_key")
        
        ragflowClient = RAGFlowClient(baseURL: baseURL, apiKey: apiKey)
        
        // Attempt to authenticate if API key is available
        if let apiKey = apiKey {
            Task { @MainActor in
                do {
                    try await ragflowClient.authenticate(apiKey: apiKey)
                } catch {
                    print("Failed to authenticate with RAGFlow: \(error)")
                }
            }
        }
    }
}

