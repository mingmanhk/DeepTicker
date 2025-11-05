import SwiftUI
import StoreKit

struct AISettingsView: View {
    @StateObject private var viewModel = AISettingsViewModel()
    // Note: Removed showingPurchaseView as ProAIPurchaseView doesn't exist yet
    // All purchase actions are handled inline in the form

    var body: some View {
        Form {
            Section("AI Model") {
                Picker("Provider", selection: $viewModel.selectedAPIProvider) {
                    ForEach(viewModel.availableAPIProviders) { provider in
                        Text(provider.rawValue).tag(provider)
                    }
                }
                .pickerStyle(.menu)
                if !viewModel.isPremium {
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

            Section("Your API Key") {
                TextField("Enter API Key", text: $viewModel.apiKey)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .disabled(!viewModel.isPremium && viewModel.selectedAPIProvider != .deepseek)
                if !viewModel.isPremium && viewModel.selectedAPIProvider != .deepseek {
                    HStack(spacing: 8) {
                        Image(systemName: "lock.fill")
                            .foregroundStyle(.orange)
                            .font(.caption)
                        Text("DeepSeek Pro required to use your own API keys for other models")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Custom Prompt") {
                TextEditor(text: $viewModel.customPrompt)
                    .frame(minHeight: 140)
                    .disabled(!viewModel.isPromptEditingEnabled)
                if !viewModel.isPromptEditingEnabled {
                    HStack(spacing: 8) {
                        Image(systemName: "lock.fill")
                            .foregroundStyle(.orange)
                            .font(.caption)
                        Text("DeepSeek Pro required to customize AI prompts")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if !viewModel.isPremium {
                Section {
                    // Featured upgrade information
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "crown.fill")
                                .foregroundStyle(.yellow)
                                .font(.title2)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Upgrade to DeepSeek Pro")
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text("Unlock all AI models and customization")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 8)
                        
                        // Price display
                        if let product = viewModel.premiumProduct {
                            HStack {
                                Text("Price:")
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(product.displayPrice)
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.primary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    
                    Divider()
                    
                    if viewModel.isLoadingProducts {
                        HStack {
                            ProgressView()
                            Text("Loading products...")
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                    } else {
                        // Purchase button
                        Button {
                            Task { await viewModel.purchasePremium() }
                        } label: {
                            HStack {
                                Spacer()
                                Label("Purchase DeepSeek Pro", systemImage: "cart.fill")
                                    .font(.headline)
                                Spacer()
                            }
                            .padding()
                            .background(Color.accentColor)
                            .foregroundStyle(.white)
                            .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                        .disabled(viewModel.isLoadingProducts || viewModel.premiumProduct == nil)
                        
                        // Restore button
                        Button {
                            Task { await viewModel.restorePurchases() }
                        } label: {
                            HStack {
                                Spacer()
                                Label("Restore Purchases", systemImage: "arrow.clockwise")
                                Spacer()
                            }
                        }
                        .disabled(viewModel.isLoadingProducts)
                        
                        // Product not available warning
                        if viewModel.premiumProduct == nil && !viewModel.isLoadingProducts {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.orange)
                                Text("Product not available. Please check your internet connection.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 8)
                        }
                    }
                    
                    if let error = viewModel.purchaseError {
                        HStack(spacing: 8) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.red)
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                        .padding(.vertical, 8)
                    }
                } header: {
                    Text("DeepSeek Pro")
                } footer: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("DeepSeek Pro unlocks:")
                            .fontWeight(.semibold)
                        Text("• Compare multiple AI models (OpenAI, Anthropic, Google, Azure)")
                        Text("• Use your own API keys for each model")
                        Text("• Customize AI analysis prompts")
                        Text("• Tailor insights to your investment strategy")
                        Text("\nFree version includes built-in DeepSeek model with preset prompts.")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            
            #if DEBUG
            // Debug section to check premium status
            Section("Debug Info") {
                HStack {
                    Text("Premium Status:")
                    Spacer()
                    Text(viewModel.isPremium ? "✅ Premium" : "❌ Free")
                        .foregroundStyle(viewModel.isPremium ? .green : .orange)
                }
                
                HStack {
                    Text("Product Loaded:")
                    Spacer()
                    Text(viewModel.premiumProduct != nil ? "✅ Yes" : "❌ No")
                        .foregroundStyle(viewModel.premiumProduct != nil ? .green : .red)
                }
                
                if let product = viewModel.premiumProduct {
                    HStack {
                        Text("Product ID:")
                        Spacer()
                        Text(product.id)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Button("Reset Premium Status (Testing)") {
                    viewModel.resetPremiumStatus()
                }
                .foregroundStyle(.red)
            }
            #endif
        }
        .navigationTitle("AI Settings")
    }
}

#Preview("Normal View") {
    NavigationStack { AISettingsView() }
}

#Preview("Force Free User") {
    let vm = AISettingsViewModel()
    // Force free status for preview
    UserDefaults.standard.set(false, forKey: "PremiumUnlocked")
    return NavigationStack { 
        AISettingsView() 
    }
}
