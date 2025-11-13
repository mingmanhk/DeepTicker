import SwiftUI
import StoreKit

struct UpgradeToProView: View {
    @StateObject private var purchaseManager = PurchaseManager.shared
    @StateObject private var aiSettings = AISettingsViewModel.shared
    @State private var isPurchasing = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccess = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "star.circle.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.yellow, .orange],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    Text("Upgrade to Pro")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Unlock additional AI providers, AI Prompt Templates, and more")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top)
                
                // Features List
                VStack(alignment: .leading, spacing: 16) {
                    FeatureRow(
                        icon: "brain.head.profile",
                        iconColor: .purple,
                        title: "Advanced AI Providers",
                        description: "Free includes DeepSeek only. Unlock OpenAI, OpenRouter, and Qwen with Pro."
                    )
                    
                    FeatureRow(
                        icon: "chart.line.uptrend.xyaxis",
                        iconColor: .cyan,
                        title: "Market Data Access",
                        description: "Alpha Vantage included in both Free and Pro versions"
                    )
                    
                    FeatureRow(
                        icon: "text.badge.star",
                        iconColor: .orange,
                        title: "AI Prompt Templates (Pro only)",
                        description: "Create and customize AI analysis prompts for your portfolio"
                    )
                    
                    FeatureRow(
                        icon: "doc.text.fill",
                        iconColor: .blue,
                        title: "Custom Prompt Editing",
                        description: "Fine-tune AI responses to match your analysis style"
                    )
                    
                    FeatureRow(
                        icon: "sparkles",
                        iconColor: .pink,
                        title: "Future Premium Features",
                        description: "Get early access to all upcoming Pro features"
                    )
                }
                .padding()
                .background(.regularMaterial)
                .cornerRadius(16)
                
                // Purchase Status
                if aiSettings.isPremium {
                    // Already Premium
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.title2)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("You're all set!")
                                .font(.headline)
                            
                            Text("You have full access to all Pro features")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(12)
                } else {
                    // Purchase Options
                    VStack(spacing: 12) {
                        if let product = purchaseManager.premiumProduct {
                            // Show Product
                            VStack(spacing: 8) {
                                Text(product.displayName)
                                    .font(.headline)
                                
                                Text(product.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                                
                                Text(product.displayPrice)
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.tint)
                                    .padding(.top, 4)
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(.ultraThinMaterial)
                            .cornerRadius(12)
                            
                            // Purchase Button
                            Button {
                                Task {
                                    await purchaseProduct()
                                }
                            } label: {
                                HStack {
                                    if isPurchasing {
                                        ProgressView()
                                            .tint(.white)
                                    } else {
                                        Text("Upgrade Now")
                                            .fontWeight(.semibold)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    LinearGradient(
                                        colors: [.blue, .purple],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .foregroundStyle(.white)
                                .cornerRadius(12)
                            }
                            .disabled(isPurchasing)
                            
                            // Restore Button
                            Button {
                                Task {
                                    await restorePurchases()
                                }
                            } label: {
                                Text("Restore Purchases")
                                    .font(.subheadline)
                                    .foregroundStyle(.tint)
                            }
                            .disabled(isPurchasing)
                            
                        } else {
                            // Loading products
                            VStack(spacing: 12) {
                                ProgressView()
                                Text("Loading product information...")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding()
                        }
                    }
                }
                
                // Terms and Privacy
                VStack(spacing: 8) {
                    Text("One-time purchase. No subscriptions.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    HStack(spacing: 16) {
                        Button("Terms of Use") {
                            // Open terms
                            if let url = URL(string: "https://yourapp.com/terms") {
                                UIApplication.shared.open(url)
                            }
                        }
                        .font(.caption2)
                        
                        Button("Privacy Policy") {
                            // Open privacy
                            if let url = URL(string: "https://yourapp.com/privacy") {
                                UIApplication.shared.open(url)
                            }
                        }
                        .font(.caption2)
                    }
                }
                .padding(.bottom)
            }
            .padding()
        }
        .navigationTitle("Pro Features")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Purchase Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .fullScreenCover(isPresented: $showSuccess) {
            PurchaseSuccessView()
        }
    }
    
    private func purchaseProduct() async {
        isPurchasing = true
        defer { isPurchasing = false }
        
        do {
            try await purchaseManager.purchasePremium()
            // Show success celebration
            showSuccess = true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    private func restorePurchases() async {
        isPurchasing = true
        defer { isPurchasing = false }
        
        await purchaseManager.restore()
    }
}

struct FeatureRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(iconColor)
                .frame(width: 32)
            
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

#Preview {
    NavigationStack {
        UpgradeToProView()
    }
}

