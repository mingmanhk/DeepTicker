// ContentView.swift
// DeepTicker
//
// Example usage of StoreManager to switch between Free and Pro behavior.

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: StoreManager
    @StateObject private var settingsVM = AISettingsViewModel()

    var body: some View {
        TabView {
            NavigationStack {
                VStack(spacing: 16) {
                    Text("DeepTicker")
                        .font(.largeTitle).bold()

                    GroupBox("AI Mode") {
                        VStack(alignment: .leading, spacing: 8) {
                            if store.hasProAI {
                                Text("Pro Mode Enabled")
                                    .font(.headline)
                                Text("Using your API key and custom prompt.")
                                    .foregroundStyle(.secondary)

                                // Example integration points
                                VStack(alignment: .leading, spacing: 6) {
                                    LabeledContent("API Key", value: settingsVM.apiKey.isEmpty ? "(not set)" : "••••••••")
                                    LabeledContent("Prompt", value: settingsVM.customPrompt.isEmpty ? "(not set)" : String(settingsVM.customPrompt.prefix(24)) + "…")
                                }
                            } else {
                                Text("Free Mode")
                                    .font(.headline)
                                Text("Using DeepSeek (default) and the default prompt.")
                                    .foregroundStyle(.secondary)
                            }

                            Divider()

                            Button("Simulate AI Call") {
                                simulateAICall()
                            }
                            .buttonStyle(.bordered)
                        }
                    }

                    Spacer()
                }
                .padding()
                .navigationTitle("Home")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        NavigationLink("AI Settings") { AISettingsView() }
                    }
                }
            }
            .tabItem { Label("Home", systemImage: "house") }

            NavigationStack {
                AISettingsView()
            }
            .tabItem { Label("Settings", systemImage: "gear") }
        }
    }

    // Stub demonstrating how the rest of the app would decide which model/prompt to use
    private func simulateAICall() {
        if store.hasProAI {
            // Use user's API key and custom prompt
            let apiKey = settingsVM.apiKey
            let prompt = settingsVM.customPrompt
            print("[AI] Pro call with key=\(apiKey.isEmpty ? "<missing>" : "<redacted>") prompt=\(prompt)")
        } else {
            // Use DeepSeek default
            let defaultPrompt = "Analyze my portfolio with a concise summary."
            print("[AI] Free call using DeepSeek with default prompt=\(defaultPrompt)")
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(StoreManager())
}
