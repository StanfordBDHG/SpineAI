//
// This source file is part of the Stanford LLM on FHIR project
//
// SPDX-FileCopyrightText: 2023 Stanford University
//
// SPDX-License-Identifier: MIT
//

import SpeziFHIR
import SpeziFHIRMockPatients
import SwiftUI


struct ResourceView: View {
    @Environment(LLMonFHIRStandard.self) private var standard
    @Environment(FHIRStore.self) private var fhirStore
    @AppStorage(StorageKeys.spineAIEnabled) private var spineAIEnabled = StorageKeys.Defaults.spineAIEnabled
    @Binding var showMultipleResourcesChat: Bool
    
    
    var body: some View {
        FHIRResourcesView(
            navigationTitle: "Your Health Records",
            contentView: {
                FHIRResourcesInstructionsView()
            }
        ) {
            chatWithAllResourcesButton
                .padding(-18)
        }
            .task {
                if FeatureFlags.testMode {
                    await fhirStore.loadTestingResources()
                }
            }
    }
    
    private var chatWithAllResourcesButton: some View {
        Group {
            if #available(iOS 26.0, *) {
                _chatWithAllResourcesButton
                #if swift(>=6.2)
                    .buttonStyle(.glassProminent)
                #else
                    .buttonStyle(.borderedProminent)
                    .padding(-8)
                #endif
            } else {
                _chatWithAllResourcesButton
                    .buttonStyle(.borderedProminent)
                    .padding(-8)
            }
        }
    }
    
    private var _chatWithAllResourcesButton: some View {
        Button {
            showMultipleResourcesChat.toggle()
        } label: {
            HStack(spacing: 8) {
                if !spineAIEnabled && standard.waitingState.isWaiting {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .controlSize(.regular)
                }
                Text(buttonText)
            }
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
        }
            .controlSize(.extraLarge)
            .buttonBorderShape(.capsule)
            .disabled(!spineAIEnabled && standard.waitingState.isWaiting)
            .animation(.default, value: standard.waitingState.isWaiting)
    }
    
    private var buttonText: String {
        if spineAIEnabled {
            return "Chat with SpineAI"
        } else if standard.waitingState.isWaiting {
            return "Loading Resources"
        } else {
            return "Chat with all Resources"
        }
    }
}
