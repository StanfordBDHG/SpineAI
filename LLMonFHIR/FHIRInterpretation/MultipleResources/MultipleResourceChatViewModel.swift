//
// This source file is part of the Stanford Spezi project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import Foundation
import SpeziChat
import SpeziLLM
import SwiftUI

/// View model for the MultipleResourcesChatView.
///
/// This view model coordinates between the UI and the FHIRMultipleResourceInterpreter.
/// It provides UI-specific computed properties and methods while delegating
/// LLM operations and persistence to the underlying interpreter.
@MainActor
@Observable
class MultipleResourcesChatViewModel {
    let interpreter: FHIRMultipleResourceInterpreter
    var processingState: ProcessingState = .processingSystemPrompts
    
    /// Direct access to the current LLM session for observing state changes
    var llmSession: LLMSession {
        interpreter.llmSession
    }
    
    /// Indicates if the LLM is currently processing or generating a response
    /// This property directly reflects the LLM session's state
    var isProcessing: Bool {
        llmSession.state.representation == .processing
    }
    
    /// Determines whether to display a typing indicator in the chat interface.
    var showTypingIndicator: Bool {
        processingState.isProcessing
    }
    
    /// The title displayed in the navigation bar
    let navigationTitle: String
    
    /// Provides a binding to the chat messages for use in SwiftUI views
    ///
    /// This binding allows the ChatView component to both display messages
    /// and add new user messages to the conversation.
    var chatBinding: Binding<Chat> {
        Binding(
            get: { [weak self] in
                self?.interpreter.llmSession.context.chat ?? []
            },
            set: { [weak self] newChat in
                self?.interpreter.llmSession.context.chat = newChat
            }
        )
    }
    
    private var shouldGenerateResponse: Bool {
        if llmSession.state == .generating || isProcessing {
            return false
        }
        
        // Check if the last message is from a user (needs a response)
        let lastMessageIsUser = interpreter.llmSession.context.last?.role == .user
        
        // Check if there are no assistant messages yet (initial prompt needs a response)
        let noAssistantMessages = !interpreter.llmSession.context.contains(where: { $0.role == .assistant() })
        
        // Generate if last message is from user or if there are no assistant messages yet
        return (lastMessageIsUser || noAssistantMessages)
    }
    
    /// Creates a view model with the specified interpreter and settings.
    ///
    /// - Parameters:
    ///   - interpreter: The FHIR resource interpreter to use for LLM operations
    ///   - navigationTitle: The title to display in the navigation bar
    init(interpreter: FHIRMultipleResourceInterpreter, navigationTitle: String) {
        self.interpreter = interpreter
        self.navigationTitle = navigationTitle
    }
    
    /// Starts a new conversation by clearing all user and assistant messages
    ///
    /// This preserves system messages but removes all conversation history,
    /// providing the user with a fresh chat while maintaining the interpreter context.
    func startNewConversation() {
        interpreter.startNewConversation()
    }
    
    /// Cancels any ongoing operations and dismisses the current view
    ///
    /// - Parameter dismiss: The dismiss action from the environment to close the view
    func dismiss(_ dismiss: DismissAction) {
        interpreter.cancel()
        dismiss()
    }
    
    /// Generates an assistant response  for the current context    
    func generateAssistantResponse(preProcessingStateUpdate: @escaping () async -> Void = {}) async -> LLMContextEntity? {
        await preProcessingStateUpdate()
        processingState = await processingState.calculateNewProcessingState(basedOn: llmSession)
        
        guard shouldGenerateResponse else {
            return nil
        }

        processingState = .processingSystemPrompts
        
        // Check if SpineAI RAG is enabled
        let spineAIEnabled = UserDefaults.standard.bool(forKey: StorageKeys.spineAIEnabled)
        
        if spineAIEnabled {
            // Use SpineAI RAG for response
            return await generateSpineAIResponse()
        }

        // Use default LLM interpreter
        guard let response = await interpreter.generateAssistantResponse() else {
            return nil
        }
        
        await preProcessingStateUpdate()
        processingState = await processingState.calculateNewProcessingState(basedOn: llmSession)

        return response
    }
    
    /// Generates a response using SpineAI RAG system
    private func generateSpineAIResponse() async -> LLMContextEntity? {
        // Get the last user message
        guard let lastUserMessage = llmSession.context.last(where: { $0.role == .user }) else {
            return nil
        }
        
        let question = lastUserMessage.content
        
        do {
            // Query SpineAI RAGFlow
            let ragResponse = try await queryRAGFlow(question: question)
            
            // Add the response to the chat context
            llmSession.context.append(assistantOutput: ragResponse)
            llmSession.context.completeAssistantStreaming()
            
            return llmSession.context.last
        } catch {
            // If RAG fails, add error message to chat
            let errorMessage = "SpineAI is temporarily unavailable. Error: \(error.localizedDescription)"
            llmSession.context.append(assistantOutput: errorMessage)
            llmSession.context.completeAssistantStreaming()
            
            return llmSession.context.last
        }
    }
}
