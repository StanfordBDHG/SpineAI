//
// This source file is part of the SpineAI project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import SwiftUI
import SpeziChat
import SpeziFHIR

/// Enhanced chat view that uses RAG for more informed responses
struct RAGEnhancedChatView: View {
    @Environment(RAGFlowModule.self) private var ragflowModule
    @Environment(FHIRStore.self) private var fhirStore
    
    @State private var messages: [ChatMessage] = []
    @State private var inputText: String = ""
    @State private var isProcessing: Bool = false
    @State private var showingSources: Bool = false
    @State private var lastSources: [RAGSource] = []
    
    var body: some View {
        VStack(spacing: 0) {
            // Chat messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(messages) { message in
                            ChatMessageBubble(message: message)
                                .id(message.id)
                        }
                        
                        if isProcessing {
                            TypingIndicator()
                        }
                    }
                    .padding()
                }
                .onChange(of: messages.count) { _, _ in
                    if let lastMessage = messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            // Sources section (collapsible)
            if !lastSources.isEmpty {
                sourcesSection
            }
            
            Divider()
            
            // Input area
            inputSection
        }
        .navigationTitle("RAG-Enhanced Chat")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: clearChat) {
                        Label("Clear Chat", systemImage: "trash")
                    }
                    
                    Button(action: { showingSources.toggle() }) {
                        Label(showingSources ? "Hide Sources" : "Show Sources", systemImage: "doc.text")
                    }
                    .disabled(lastSources.isEmpty)
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .onAppear {
            addWelcomeMessage()
        }
    }
    
    // MARK: - View Components
    
    private var sourcesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: { showingSources.toggle() }) {
                HStack {
                    Label("Evidence Sources (\(lastSources.count))", systemImage: "doc.text.magnifyingglass")
                        .font(.caption)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Image(systemName: showingSources ? "chevron.up" : "chevron.down")
                        .font(.caption)
                }
            }
            .foregroundColor(.accentColor)
            
            if showingSources {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(lastSources) { source in
                            SourceChipView(source: source)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGroupedBackground))
    }
    
    private var inputSection: some View {
        HStack(spacing: 12) {
            TextField("Ask about treatment options...", text: $inputText, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...4)
                .disabled(isProcessing || !ragflowModule.ragflowClient.isConnected)
            
            Button(action: sendMessage) {
                Image(systemName: isProcessing ? "stop.circle.fill" : "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundColor(canSend ? .accentColor : .gray)
            }
            .disabled(!canSend)
        }
        .padding()
    }
    
    private var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isProcessing && ragflowModule.ragflowClient.isConnected
    }
    
    // MARK: - Actions
    
    private func addWelcomeMessage() {
        if messages.isEmpty {
            let welcomeText = """
            Welcome to RAG-Enhanced Chat! 👋
            
            I can help you with evidence-based treatment recommendations for spine surgery. \
            I'll search through medical literature and clinical guidelines to provide you with \
            informed answers.
            
            Try asking:
            • "What are the treatment options for lumbar spinal stenosis?"
            • "What are the success rates of spinal fusion surgery?"
            • "When is conservative treatment preferred over surgery?"
            """
            
            messages.append(ChatMessage(
                role: .assistant,
                content: welcomeText,
                timestamp: Date()
            ))
        }
    }
    
    private func sendMessage() {
        guard canSend else { return }
        
        let userMessage = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        inputText = ""
        
        // Add user message
        messages.append(ChatMessage(
            role: .user,
            content: userMessage,
            timestamp: Date()
        ))
        
        // Get RAG-enhanced response
        Task {
            await getRAGResponse(for: userMessage)
        }
    }
    
    private func getRAGResponse(for query: String) async {
        isProcessing = true
        
        do {
            // Extract patient context from FHIR resources
            let context = extractPatientContext()
            
            // Query RAGFlow
            let response = try await ragflowModule.ragflowClient.performQuery(
                query: query,
                context: context
            )
            
            // Add assistant response
            messages.append(ChatMessage(
                role: .assistant,
                content: response.answer,
                timestamp: Date(),
                confidence: response.confidence
            ))
            
            // Update sources
            lastSources = response.sources
            
        } catch {
            let errorMessage = """
                I apologize, but I encountered an error: \(error.localizedDescription). \
                Please try again or check your connection to the RAGFlow service.
                """
            messages.append(ChatMessage(
                role: .assistant,
                content: errorMessage,
                timestamp: Date()
            ))
        }
        
        isProcessing = false
    }
    
    private func extractPatientContext() -> PatientContext? {
        let resources = fhirStore.llmRelevantResources
        
        var age: Int?
        var diagnosis: String?
        
        // Extract patient age
        if let patientResource = resources.first(where: { $0.resourceType == .patient }),
           let birthDateString = patientResource.birthDate?.description {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withFullDate]
            if let birthDate = formatter.date(from: birthDateString) {
                age = Calendar.current.dateComponents([.year], from: birthDate, to: Date()).year
            }
        }
        
        // Extract primary diagnosis
        if let condition = resources.first(where: { $0.resourceType == .condition }) {
            diagnosis = condition.code?.text
        }
        
        return PatientContext(
            age: age,
            diagnosis: diagnosis,
            imagingFindings: nil,
            medicalHistory: nil
        )
    }
    
    private func clearChat() {
        messages.removeAll()
        lastSources.removeAll()
        addWelcomeMessage()
    }
}

// MARK: - Supporting Models

struct ChatMessage: Identifiable {
    let id = UUID()
    let role: MessageRole
    let content: String
    let timestamp: Date
    let confidence: Double?
    
    init(role: MessageRole, content: String, timestamp: Date, confidence: Double? = nil) {
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.confidence = confidence
    }
    
    enum MessageRole {
        case user
        case assistant
    }
}

// MARK: - Supporting Views

struct ChatMessageBubble: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.role == .user {
                Spacer()
            }
            
            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .padding()
                    .background(message.role == .user ? Color.accentColor : Color(.systemGray5))
                    .foregroundColor(message.role == .user ? .white : .primary)
                    .cornerRadius(16)
                
                HStack(spacing: 4) {
                    Text(formatTime(message.timestamp))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    
                    if let confidence = message.confidence {
                        Text("• \(Int(confidence * 100))% confidence")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            if message.role == .assistant {
                Spacer()
            }
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct TypingIndicator: View {
    @State private var animating = false
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.gray)
                    .frame(width: 8, height: 8)
                    .scaleEffect(animating ? 1.0 : 0.5)
                    .animation(
                        .easeInOut(duration: 0.6)
                            .repeatForever()
                            .delay(Double(index) * 0.2),
                        value: animating
                    )
            }
        }
        .padding()
        .background(Color(.systemGray5))
        .cornerRadius(16)
        .onAppear {
            animating = true
        }
    }
}

struct SourceChipView: View {
    let source: RAGSource
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let title = source.title {
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(2)
            }
            
            if let relevance = source.relevanceScore {
                HStack(spacing: 2) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.caption2)
                    Text("\(Int(relevance * 100))%")
                        .font(.caption2)
                }
                .foregroundColor(.green)
            }
        }
        .padding(8)
        .frame(width: 150)
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .shadow(radius: 1)
    }
}

#Preview {
    NavigationStack {
        RAGEnhancedChatView()
    }
}

