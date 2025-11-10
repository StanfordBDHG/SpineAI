//
// This source file is part of the SpineAI project
//
// SPDX-FileCopyrightText: 2025 Stanford University
//
// SPDX-License-Identifier: MIT
//

// swiftlint:disable file_length type_body_length closure_body_length

import SwiftUI
import SpeziFHIR

/// View for displaying spine surgery treatment recommendations enhanced with RAG
struct SpineSurgeryRecommendationView: View {
    @Environment(RAGFlowModule.self) private var ragflowModule
    @Environment(FHIRStore.self) private var fhirStore
    
    @State private var isLoading: Bool = false
    @State private var recommendation: SpineRecommendationResponse?
    @State private var errorMessage: String?
    @State private var showingSources: Bool = false
    
    // Patient data inputs
    @State private var patientAge: String = ""
    @State private var diagnosis: String = ""
    @State private var symptoms: String = ""
    @State private var imagingFindings: String = ""
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                headerSection
                
                if !ragflowModule.ragflowClient.isConnected {
                    notConnectedSection
                } else {
                    inputSection
                    
                    if let errorMessage = errorMessage {
                        errorSection(errorMessage)
                    }
                    
                    if isLoading {
                        loadingSection
                    } else if let recommendation = recommendation {
                        recommendationSection(recommendation)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Spine Surgery Recommendations")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            loadPatientDataFromFHIR()
        }
    }
    
    // MARK: - View Components
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "waveform.path.ecg.rectangle.fill")
                    .font(.title2)
                    .foregroundColor(.accentColor)
                
                Text("AI-Powered Analysis")
                    .font(.title2)
                    .fontWeight(.bold)
            }
            
            Text("Get evidence-based treatment recommendations for spine surgery decisions using RAG-enhanced AI analysis.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    private var notConnectedSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 50))
                .foregroundColor(.orange)
            
            Text("RAGFlow Not Connected")
                .font(.headline)
            
            Text("Please configure and connect to RAGFlow in Settings to use this feature.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            NavigationLink(destination: RAGFlowSettingsView()) {
                Label("Open Settings", systemImage: "gear")
                    .padding()
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemGroupedBackground))
        .cornerRadius(12)
    }
    
    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Patient Information")
                .font(.headline)
            
            VStack(spacing: 12) {
                inputField(
                    title: "Age",
                    placeholder: "e.g., 65",
                    text: $patientAge,
                    icon: "person.fill"
                )
                
                inputField(
                    title: "Diagnosis",
                    placeholder: "e.g., Lumbar Spinal Stenosis",
                    text: $diagnosis,
                    icon: "cross.case.fill"
                )
                
                inputField(
                    title: "Symptoms",
                    placeholder: "e.g., Back pain, leg numbness",
                    text: $symptoms,
                    icon: "list.bullet.clipboard.fill",
                    axis: .vertical
                )
                
                inputField(
                    title: "Imaging Findings",
                    placeholder: "e.g., MRI shows central canal stenosis at L4-L5",
                    text: $imagingFindings,
                    icon: "camera.metering.matrix",
                    axis: .vertical
                )
            }
            
            Button(action: {
                Task {
                    await getRecommendations()
                }
            }) {
                HStack {
                    Image(systemName: "sparkles")
                    Text("Get AI Recommendations")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.accentColor)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .disabled(isLoading || patientAge.isEmpty || diagnosis.isEmpty)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    private func inputField(
        title: String,
        placeholder: String,
        text: Binding<String>,
        icon: String,
        axis: Axis = .horizontal
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            TextField(placeholder, text: text, axis: axis)
                .textFieldStyle(.roundedBorder)
                .lineLimit(axis == .vertical ? 3...5 : 1...1)
        }
    }
    
    private func errorSection(_ message: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(10)
    }
    
    private var loadingSection: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(.circular)
                .scaleEffect(1.5)
            
            Text("Analyzing patient data and searching medical literature...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
        .frame(maxWidth: .infinity)
        .background(Color(.systemGroupedBackground))
        .cornerRadius(12)
    }
    
    private func recommendationSection(_ rec: SpineRecommendationResponse) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Confidence Score
            HStack {
                Text("Confidence Score")
                    .font(.headline)
                
                Spacer()
                
                ConfidenceScoreView(score: rec.confidenceScore)
            }
            
            Divider()
            
            // Recommendations
            VStack(alignment: .leading, spacing: 8) {
                Text("Recommendations")
                    .font(.headline)
                
                Text(rec.recommendations)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Divider()
            
            // Evidence Sources
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Evidence Sources")
                        .font(.headline)
                    
                    Spacer()
                    
                    Button(action: {
                        showingSources.toggle()
                    }) {
                        Label(showingSources ? "Hide" : "Show", systemImage: showingSources ? "chevron.up" : "chevron.down")
                            .font(.caption)
                    }
                }
                
                if showingSources {
                    ForEach(rec.evidenceSources) { source in
                        SourceCard(source: source)
                    }
                }
            }
            
            // Timestamp
            Text("Generated: \(formatTimestamp(rec.timestamp))")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    // MARK: - Actions
    
    private func loadPatientDataFromFHIR() {
        // Extract patient data from FHIR resources if available
        let resources = fhirStore.llmRelevantResources
        
        // Find patient resource
        if let patientResource = resources.first(where: { $0.resourceType == .patient }) {
            // Extract age from birth date
            if let birthDateString = patientResource.birthDate?.description {
                // Calculate age (simplified)
                patientAge = calculateAge(from: birthDateString)
            }
        }
        
        // Find conditions (diagnoses)
        let conditions = resources.filter { $0.resourceType == .condition }
        if !conditions.isEmpty {
            // Get the most recent condition
            diagnosis = conditions.first?.code?.text ?? ""
        }
    }
    
    private func calculateAge(from birthDateString: String) -> String {
        // Simplified age calculation
        // In production, use proper date parsing
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        
        if let birthDate = formatter.date(from: birthDateString) {
            let age = Calendar.current.dateComponents([.year], from: birthDate, to: Date()).year ?? 0
            return "\(age)"
        }
        
        return ""
    }
    
    private func getRecommendations() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let patientData = SpinePatientData(
                age: Int(patientAge),
                diagnosis: diagnosis,
                symptoms: symptoms.split(separator: ",").map { String($0.trimmingCharacters(in: .whitespaces)) },
                imaging: ["MRI": imagingFindings],
                medicalHistory: nil
            )
            
            let response = try await ragflowModule.ragflowClient.getSpineSurgeryRecommendation(
                patientData: patientData
            )
            
            recommendation = response
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    private func formatTimestamp(_ timestamp: String) -> String {
        // Format ISO timestamp to readable format
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: timestamp) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .short
            return displayFormatter.string(from: date)
        }
        return timestamp
    }
}

// MARK: - Supporting Views

struct ConfidenceScoreView: View {
    let score: Double
    
    var scoreColor: Color {
        switch score {
        case 0.8...:
            return .green
        case 0.6..<0.8:
            return .orange
        default:
            return .red
        }
    }
    
    var body: some View {
        HStack(spacing: 8) {
            ProgressView(value: score, total: 1.0)
                .progressViewStyle(.linear)
                .tint(scoreColor)
                .frame(width: 100)
            
            Text("\(Int(score * 100))%")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(scoreColor)
        }
    }
}

struct SourceCard: View {
    let source: RAGSource
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let title = source.title {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            
            if let content = source.content {
                Text(content)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
            
            if let relevance = source.relevanceScore {
                HStack {
                    Text("Relevance:")
                    ProgressView(value: relevance, total: 1.0)
                        .progressViewStyle(.linear)
                        .frame(width: 60)
                    Text("\(Int(relevance * 100))%")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGroupedBackground))
        .cornerRadius(8)
    }
}

#Preview {
    NavigationStack {
        SpineSurgeryRecommendationView()
    }
}

