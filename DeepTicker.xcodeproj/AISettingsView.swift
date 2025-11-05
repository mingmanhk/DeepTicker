// AISettingsView.swift
// DeepTicker
//
// Settings & Paywall UI for Free vs Pro modes.

import SwiftUI

struct AISettingsView: View {
    @EnvironmentObject private var store: StoreManager
    @StateObject private var vm = AISettingsViewModel()

    var body: some View {
        List {
            if store.hasProAI == false {
                Section("AI Settings") {
                    LabeledContent("Current model", value: "DeepSeek (default)")
                    Text("Unlock AI Pro Access to add your own AI API key and use a custom analysis prompt.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Section {
                    Button {
                        Task { await store.purchasePro() }
                    } label: {
                        HStack {
                            if store.purchaseInFlight { ProgressView().padding(.trailing, 8) }
                            Text("Unlock AI Pro Access")
                                .font(.headline)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(store.purchaseInFlight)
                }
            } else {
                Section("Model Source") {
                    // For now we show a static label. You can replace with a Picker if you add more options.
                    LabeledContent("Source", value: "Custom Model via API Key")
                }

                Section("API Key") {
                    SecureField("Enter API Key", text: $vm.apiKey)
                        .textContentType(.password)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .onChange(of: vm.apiKey) { newValue in
                            store.updateAPIKey(newValue)
                        }
                }

                Section("Custom AI Analysis Prompt") {
                    TextEditor(text: $vm.customPrompt)
                        .frame(minHeight: 120)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.secondary.opacity(0.2))
                        )
                        .font(.body)
                        .onChange(of: vm.customPrompt) { newValue in
                            store.updateCustomPrompt(newValue)
                        }
                }
            }

            if let message = store.lastMessage, !message.isEmpty {
                Section("Status") {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("AI Settings")
        .task { await store.loadProducts() }
    }
}

#Preview {
    NavigationStack { AISettingsView() }
        .environmentObject(StoreManager())
}
