import SwiftUI

struct SettingsUpgradeSnippet: View {
    @StateObject private var vm = AISettingsViewModel()

    var body: some View {
        Form {
            Section("API Provider") {
                Picker("Provider", selection: $vm.selectedAPIProvider) {
                    ForEach(vm.availableAPIProviders) { provider in
                        Text(provider.rawValue).tag(provider)
                    }
                }
                .pickerStyle(.menu)
                if !vm.isPremium {
                    HStack(spacing: 8) {
                        Image(systemName: "lock.fill")
                            .foregroundStyle(.orange)
                            .font(.caption)
                        Text("Upgrade to DeepSeek Pro to compare multiple AI models")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("API Key") {
                TextField("Enter API Key", text: $vm.apiKey)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .disabled(!vm.isPremium && vm.selectedAPIProvider != .deepseek)
                if !vm.isPremium {
                    Text("Premium required for other provider keys")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section("AI Prompt Template") {
                TextEditor(text: $vm.customPrompt)
                    .frame(minHeight: 120)
                    .disabled(!vm.isPromptEditingEnabled)
                if !vm.isPromptEditingEnabled {
                    Text("Premium required to customize the AI prompt")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            if !vm.isPremium {
                Section {
                    if vm.isLoadingProducts {
                        HStack {
                            ProgressView()
                            Text("Loading products...")
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Button(action: { Task { await vm.purchasePremium() } }) {
                            Label("Go Premium", systemImage: "crown.fill")
                        }
                        .disabled(vm.isLoadingProducts)
                        
                        Button(action: { Task { await vm.restorePurchases() } }) {
                            Label("Restore Purchases", systemImage: "arrow.clockwise")
                        }
                        .disabled(vm.isLoadingProducts)
                    }
                    
                    if let error = vm.purchaseError {
                        Text("Error: \(error)")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                } header: {
                    Text("DeepSeek Pro")
                } footer: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("DeepSeek Pro unlocks:")
                        Text("• Compare multiple AI models (OpenAI, Qwen, etc.)")
                        Text("• Use your own API keys for each model")
                        Text("• Customize AI analysis prompts")
                        Text("\nFree version includes built-in DeepSeek model.")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("AI Settings")
    }
}

#Preview {
    NavigationStack { SettingsUpgradeSnippet() }
}
