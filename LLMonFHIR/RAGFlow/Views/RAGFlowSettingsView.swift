//
// This source file is part of the SpineAI project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

// swiftlint:disable closure_body_length

import SwiftUI

/// Settings view for RAGFlow configuration
struct RAGFlowSettingsView: View {
    @AppStorage("ragflow_base_url") private var baseURL: String = "http://localhost:5000"
    @AppStorage("ragflow_api_key") private var apiKey: String = ""
    @AppStorage("ragflow_enabled") private var isEnabled: Bool = false
    
    @Environment(RAGFlowModule.self) private var ragflowModule
    @State private var showingAPIKeyField: Bool = false
    @State private var connectionStatus: ConnectionStatus = .unknown
    @State private var isTestingConnection: Bool = false
    
    enum ConnectionStatus {
        case unknown
        case connected
        case disconnected
        case testing
        
        var color: Color {
            switch self {
            case .connected: return .green
            case .disconnected: return .red
            case .testing: return .orange
            case .unknown: return .gray
            }
        }
        
        var text: String {
            switch self {
            case .connected: return "Connected"
            case .disconnected: return "Disconnected"
            case .testing: return "Testing..."
            case .unknown: return "Unknown"
            }
        }
    }
    
    var body: some View {
        Form {
            enabledSection
            connectionSection
            configurationSection
            aboutSection
        }
        .navigationTitle("RAG Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var enabledSection: some View {
        Section {
            Toggle("Enable RAG Enhancement", isOn: $isEnabled)
        } footer: {
            Text("Enable Retrieval-Augmented Generation to enhance treatment recommendations with evidence-based medical literature.")
        }
    }
    
    private var connectionSection: some View {
        Section("Connection Status") {
            HStack {
                Circle()
                    .fill(connectionStatus.color)
                    .frame(width: 10, height: 10)
                
                Text(connectionStatus.text)
                    .foregroundStyle(connectionStatus.color)
                
                Spacer()
                
                if isTestingConnection {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(0.8)
                }
            }
            
            Button("Test Connection") {
                Task {
                    await testConnection()
                }
            }
            .disabled(isTestingConnection || baseURL.isEmpty)
        }
    }
    
    private var configurationSection: some View {
        Section("Configuration") {
            VStack(alignment: .leading, spacing: 4) {
                Text("Server URL")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                TextField("http://localhost:5000", text: $baseURL)
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("API Key")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    Button(showingAPIKeyField ? "Hide" : "Show") {
                        showingAPIKeyField.toggle()
                    }
                    .font(.caption)
                }
                
                if showingAPIKeyField {
                    TextField("Enter API Key", text: $apiKey)
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                } else {
                    SecureField("Enter API Key", text: $apiKey)
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                }
            }
            
            Button("Save & Authenticate") {
                Task {
                    await authenticate()
                }
            }
            .disabled(apiKey.isEmpty || baseURL.isEmpty)
        } footer: {
            Text("Enter your RAGFlow proxy API key to enable enhanced medical recommendations.")
        }
    }
    
    private var aboutSection: some View {
        Section("About RAG") {
            VStack(alignment: .leading, spacing: 12) {
                Label("Evidence-Based", systemImage: "book.fill")
                Text("RAG retrieves relevant medical literature and clinical guidelines to support treatment recommendations.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Divider()
                
                Label("Improved Accuracy", systemImage: "checkmark.seal.fill")
                Text("Combines AI reasoning with verified medical knowledge for more accurate and trustworthy recommendations.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Divider()
                
                Label("Source Citations", systemImage: "doc.text.magnifyingglass")
                Text("Provides references to source materials, allowing you to verify recommendations independently.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    // MARK: - Actions
    
    private func testConnection() async {
        isTestingConnection = true
        connectionStatus = .testing
        
        // Give UI time to update
        try? await Task.sleep(nanoseconds: 100_000_000)
        
        await ragflowModule.ragflowClient.checkConnection()
        
        connectionStatus = ragflowModule.ragflowClient.isConnected ? .connected : .disconnected
        isTestingConnection = false
    }
    
    private func authenticate() async {
        guard !apiKey.isEmpty else { return }
        
        do {
            try await ragflowModule.ragflowClient.authenticate(apiKey: apiKey)
            await testConnection()
        } catch {
            connectionStatus = .disconnected
            print("Authentication failed: \(error)")
        }
    }
}

#Preview {
    NavigationStack {
        RAGFlowSettingsView()
    }
}

