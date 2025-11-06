import SwiftUI
import StoreKit

struct AISettingsView: View {
    @StateObject private var viewModel = AISettingsViewModel()
    
    var body: some View {
        Form {
            // ALWAYS show upgrade section at the top for free users
            if !viewModel.isPremium {
                Section {
                    upgradeSection
                } header: {
                    HStack {
                        Image(systemName: "crown.fill")
                            .foregroundStyle(.yellow)
                        Text("Upgrade to Pro")
                            .font(.headline)
                    }
                }
            }
            
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
                    // Detailed upgrade information in footer
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Free version includes:")
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                        Text("• Built-in DeepSeek AI model")
                            .foregroundStyle(.secondary)
                        Text("• Preset analysis prompts")
                            .foregroundStyle(.secondary)
                    }
                    .font(.caption)
                    .padding(.vertical, 4)
                } header: {
                    Text("Current Plan: Free")
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
    
    // MARK: - Upgrade Section
    private var upgradeSection: some View {
        VStack(spacing: 16) {
            // Hero section
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    Image(systemName: "crown.fill")
                        .foregroundStyle(.yellow)
                        .font(.system(size: 40))
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("DeepSeek Pro")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(.primary)
                        Text("Unlock Premium AI Features")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                
                // Price display
                if let product = viewModel.premiumProduct {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("One-Time Purchase")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(product.displayPrice)
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundStyle(.tint)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(Color.accentColor.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            
            Divider()
            
            // Features list
            VStack(alignment: .leading, spacing: 10) {
                Text("Pro Features:")
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                FeatureRow(icon: "brain.head.profile", text: "Compare Multiple AI Models", color: .blue)
                FeatureRow(icon: "key.fill", text: "Use Your Own API Keys", color: .green)
                FeatureRow(icon: "text.bubble.fill", text: "Customize Analysis Prompts", color: .orange)
                FeatureRow(icon: "chart.line.uptrend.xyaxis", text: "Advanced Portfolio Insights", color: .purple)
            }
            
            Divider()
            
            // Purchase buttons
            VStack(spacing: 12) {
                if viewModel.isLoadingProducts {
                    HStack {
                        ProgressView()
                        Text("Loading...")
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                } else {
                    // Main purchase button
                    Button {
                        Task { await viewModel.purchasePremium() }
                    } label: {
                        HStack {
                            Image(systemName: "cart.fill")
                            Text("Purchase DeepSeek Pro")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(viewModel.premiumProduct == nil ? Color.gray : Color.accentColor)
                        .foregroundStyle(.white)
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.isLoadingProducts || viewModel.premiumProduct == nil)
                    
                    // Restore button
                    Button {
                        Task { await viewModel.restorePurchases() }
                    } label: {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Restore Purchases")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .foregroundStyle(.tint)
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.isLoadingProducts)
                    
                    // Product not available warning
                    if viewModel.premiumProduct == nil && !viewModel.isLoadingProducts {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text("Product not available. Check your connection.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                // Error display
                if let error = viewModel.purchaseError {
                    HStack(spacing: 8) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.red)
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Feature Row Component
struct FeatureRow: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(color)
                .frame(width: 28)
            
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.primary)
            
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.system(size: 16))
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Previews

#Preview("Free User (Default)") {
    NavigationStack { AISettingsView() }
}

#Preview("Force Free User") {
    // Force free status for preview
    UserDefaults.standard.set(false, forKey: "PremiumUnlocked")
    return NavigationStack { 
        AISettingsView() 
    }
}
