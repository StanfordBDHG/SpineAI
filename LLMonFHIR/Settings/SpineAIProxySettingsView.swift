//
// This source file is part of the Stanford Spezi project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

import SwiftUI


// MARK: - Connection Status

enum ConnectionStatus {
    case success(ragflowConfigured: Bool, gcsConfigured: Bool)
    case failure(String)
}


// MARK: - SpineAI Proxy Settings View

/// Settings view for configuring the SpineAI RAG proxy connection
struct SpineAIProxySettingsView: View {
    @AppStorage(StorageKeys.proxyURL) private var proxyURL = StorageKeys.Defaults.proxyURL
    @State private var isTestingConnection = false
    @State private var connectionStatus: ConnectionStatus?
    
    var body: some View {
        Form {
            proxySection
            testSection
            aboutSection
        }
        .navigationTitle("SpineAI Proxy")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var proxySection: some View {
        Section {
            TextField("Proxy URL", text: $proxyURL)
                .textContentType(.URL)
                .keyboardType(.URL)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
        } header: {
            Text("SpineAI RAG Proxy")
        } footer: {
            Text("Enter the URL of your SpineAI RAG proxy server (e.g., https://proxy.spineai.stanford.edu)")
        }
    }
    
    private var testSection: some View {
        Section {
            Button {
                Task {
                    await testConnection()
                }
            } label: {
                HStack {
                    Text("Test Connection")
                    Spacer()
                    if isTestingConnection {
                        ProgressView()
                    }
                }
            }
            .disabled(isTestingConnection || proxyURL.isEmpty)
            
            if let status = connectionStatus {
                ConnectionStatusRow(status: status)
            }
        }
    }
    
    private var aboutSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text("About SpineAI RAG")
                    .font(.headline)
                Text("The SpineAI proxy connects to RAGFlow for evidence-based spine imaging guidance.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    @MainActor
    private func testConnection() async {
        isTestingConnection = true
        connectionStatus = nil
        
        do {
            let service = SpineAIProxyService(proxyURL: proxyURL)
            let health = try await service.healthCheck()
            
            if health.status == "ok" {
                connectionStatus = .success(
                    ragflowConfigured: health.config.ragflowConfigured,
                    gcsConfigured: health.config.gcsConfigured
                )
            } else {
                connectionStatus = .failure("Server returned non-OK status")
            }
        } catch {
            connectionStatus = .failure(error.localizedDescription)
        }
        
        isTestingConnection = false
    }
}


// MARK: - Connection Status Row

struct ConnectionStatusRow: View {
    let status: ConnectionStatus
    
    var body: some View {
        switch status {
        case let .success(ragflowConfigured, gcsConfigured):
            successView(ragflowConfigured: ragflowConfigured, gcsConfigured: gcsConfigured)
        case let .failure(message):
            failureView(message: message)
        }
    }
    
    private func successView(ragflowConfigured: Bool, gcsConfigured: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("Connection Successful", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
            
            if !ragflowConfigured {
                Label("RAGFlow not configured", systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            
            if !gcsConfigured {
                Label("Cloud storage not configured", systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }
    
    private func failureView(message: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("Connection Failed", systemImage: "xmark.circle.fill")
                .foregroundStyle(.red)
            
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}


#Preview {
    NavigationStack {
        SpineAIProxySettingsView()
    }
}
