import SwiftUI
import StoreKit

/// A modern, attractive purchase view for the DeepSeek Pro feature
struct ProAIPurchaseView: View {
    @StateObject private var viewModel = AISettingsViewModel()
    @ObservedObject private var purchaseManager = PurchaseManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var isPurchasing = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Hero Section
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [.purple, .blue],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 120, height: 120)
                            
                            Image(systemName: "brain.head.profile")
                                .font(.system(size: 50))
                                .foregroundStyle(.white)
                        }
                        .shadow(radius: 10)
                        
                        VStack(spacing: 8) {
                            Text("DeepSeek Pro")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                            
                            Text("Unlock advanced AI customization")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.top, 32)
                    
                    // Features List
                    VStack(spacing: 20) {
                        ProAIPurchaseFeatureRow(
                            icon: "square.stack.3d.up.fill",
                            title: "Compare AI Models",
                            description: "Use your own API keys to compare OpenAI, Qwen, and other AI models side-by-side"
                        )
                        
                        ProAIPurchaseFeatureRow(
                            icon: "doc.text.fill",
                            title: "Custom Prompts",
                            description: "Customize AI analysis prompts to tailor portfolio insights to your strategy"
                        )
                        
                        ProAIPurchaseFeatureRow(
                            icon: "key.fill",
                            title: "Your Own API Keys",
                            description: "Bring your own AI provider keys for complete control and flexibility"
                        )
                        
                        ProAIPurchaseFeatureRow(
                            icon: "lock.shield.fill",
                            title: "One-Time Purchase",
                            description: "Pay once, use forever. No subscription required"
                        )
                    }
                    .padding(.horizontal)
                    
                    // Free vs Pro Comparison
                    VStack(spacing: 16) {
                        Text("What's Included")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                        
                        VStack(spacing: 12) {
                            ProAIPurchaseComparisonRow(
                                feature: "Built-in DeepSeek Model",
                                free: true,
                                pro: true
                            )
                            ProAIPurchaseComparisonRow(
                                feature: "OpenAI, Qwen & Other AI Models",
                                free: false,
                                pro: true
                            )
                            ProAIPurchaseComparisonRow(
                                feature: "Custom AI Prompts",
                                free: false,
                                pro: true
                            )
                            ProAIPurchaseComparisonRow(
                                feature: "Compare Multiple AI Results",
                                free: false,
                                pro: true
                            )
                        }
                        .padding()
                        .background(.regularMaterial)
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                    
                    // Pricing Card
                    if let product = purchaseManager.premiumProduct {
                        VStack(spacing: 16) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(product.displayName)
                                        .font(.headline)
                                    Text("One-time purchase • No subscription")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                
                                Spacer()
                                
                                Text(product.displayPrice)
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.purple)
                            }
                            .padding()
                            .background(.regularMaterial)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(.purple.opacity(0.3), lineWidth: 2)
                            )
                        }
                        .padding(.horizontal)
                    } else if viewModel.isLoadingProducts {
                        ProgressView("Loading product...")
                            .padding()
                    } else {
                        VStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.title)
                                .foregroundStyle(.orange)
                            Text("Unable to load product")
                                .font(.headline)
                            Text("Please check your connection and try again")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                            
                            Button("Retry") {
                                Task {
                                    await purchaseManager.configure(productID: AISettingsViewModel.premiumProductID)
                                }
                            }
                            .buttonStyle(.bordered)
                            .padding(.top, 8)
                        }
                        .padding()
                    }
                    
                    // Purchase Button
                    if purchaseManager.premiumProduct != nil {
                        VStack(spacing: 12) {
                            Button {
                                Task {
                                    await handlePurchase()
                                }
                            } label: {
                                HStack {
                                    if isPurchasing {
                                        ProgressView()
                                            .tint(.white)
                                    } else {
                                        Image(systemName: "crown.fill")
                                        Text("Get DeepSeek Pro")
                                            .fontWeight(.semibold)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    LinearGradient(
                                        colors: [.purple, .blue],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .foregroundStyle(.white)
                                .cornerRadius(12)
                            }
                            .disabled(isPurchasing || viewModel.isLoadingProducts)
                            
                            Button {
                                Task {
                                    await handleRestore()
                                }
                            } label: {
                                Text("Restore Purchases")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .disabled(isPurchasing)
                        }
                        .padding(.horizontal)
                    }
                    
                    // Error Alert
                    if showError {
                        VStack(spacing: 8) {
                            HStack {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .foregroundStyle(.red)
                                Text(errorMessage)
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }
                            .padding()
                            .background(.red.opacity(0.1))
                            .cornerRadius(8)
                        }
                        .padding(.horizontal)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    
                    // Info Box
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "info.circle.fill")
                                .foregroundStyle(.blue)
                            Text("Why upgrade?")
                                .font(.headline)
                        }
                        
                        Text("Without DeepSeek Pro, DeepTicker uses only the built-in DeepSeek model with preset prompts. Upgrade to compare multiple AI models and customize prompts for insights tailored to your investment strategy.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(.blue.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    
                    // Terms & Privacy
                    VStack(spacing: 8) {
                        Text("By purchasing, you agree to the Terms of Service and Privacy Policy")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        
                        HStack(spacing: 16) {
                            Button("Terms") {
                                // Open terms URL
                                if let url = URL(string: "https://yourapp.com/terms") {
                                    UIApplication.shared.open(url)
                                }
                            }
                            .font(.caption2)
                            
                            Button("Privacy") {
                                // Open privacy URL
                                if let url = URL(string: "https://yourapp.com/privacy") {
                                    UIApplication.shared.open(url)
                                }
                            }
                            .font(.caption2)
                        }
                        .foregroundStyle(.blue)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 32)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                #if DEBUG
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Reset Premium Status") {
                            viewModel.resetPremiumStatus()
                        }
                        Button("Reload Product") {
                            Task {
                                await purchaseManager.configure(productID: AISettingsViewModel.premiumProductID)
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
                #endif
            }
        }
        .onAppear {
            // Check if already purchased
            if viewModel.isPremium || purchaseManager.isPurchased {
                dismiss()
            }
        }
    }
    
    private func handlePurchase() async {
        isPurchasing = true
        showError = false
        
        do {
            try await purchaseManager.purchasePremium()
            
            // Check if purchase was successful
            if purchaseManager.isPurchased {
                // Success! Dismiss the view
                dismiss()
            }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        
        isPurchasing = false
    }
    
    private func handleRestore() async {
        isPurchasing = true
        showError = false
        
        await purchaseManager.restore()
        
        if purchaseManager.isPurchased {
            dismiss()
        } else {
            errorMessage = "No previous purchases found"
            showError = true
        }
        
        isPurchasing = false
    }
}

// Renamed to avoid conflicts with other FeatureRow structs in the project
private struct ProAIPurchaseFeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                Circle()
                    .fill(.purple.opacity(0.1))
                    .frame(width: 48, height: 48)
                
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(.purple)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
    }
}

private struct ProAIPurchaseComparisonRow: View {
    let feature: String
    let free: Bool
    let pro: Bool
    
    var body: some View {
        HStack {
            Text(feature)
                .font(.subheadline)
            
            Spacer()
            
            HStack(spacing: 24) {
                // Free column
                Image(systemName: free ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(free ? .green : .secondary)
                    .frame(width: 24)
                
                // Pro column
                Image(systemName: pro ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(pro ? .purple : .secondary)
                    .frame(width: 24)
            }
        }
    }
}

#Preview {
    ProAIPurchaseView()
}
