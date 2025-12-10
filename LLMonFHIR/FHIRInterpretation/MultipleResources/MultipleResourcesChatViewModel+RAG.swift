//
// This source file is part of the Stanford Spezi project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation

/// Extension to add RAG (Retrieval-Augmented Generation) capabilities via SpineAI proxy
extension MultipleResourcesChatViewModel {
    /// Query RAGFlow for spine imaging clinical guidance
    ///
    /// This method:
    /// 1. Sends the question to the SpineAI RAG proxy
    /// 2. Receives answer with citations from clinical guidelines
    /// 3. Returns formatted response for display in chat
    ///
    /// - Parameter question: The clinical question to ask
    /// - Returns: Answer with references from clinical guidelines
    func queryRAGFlow(question: String) async throws -> String {
        let proxyService = SpineAIProxyService()
        
        // Query RAGFlow via proxy
        let response = try await proxyService.query(question: question)
        
        // Format response with citations
        var formattedResponse = response.answer
        
        if !response.references.isEmpty {
            formattedResponse += "\n\n**References:**\n"
            for (index, reference) in response.references.enumerated() {
                formattedResponse += "\n[\(index + 1)] \(reference.content)"
                if let source = reference.source {
                    formattedResponse += " (Source: \(source)"
                    if let page = reference.page {
                        formattedResponse += ", p. \(page)"
                    }
                    formattedResponse += ")"
                }
            }
        }
        
        return formattedResponse
    }
}
