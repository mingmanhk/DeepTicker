import SwiftUI
import SwiftUI
import StoreKit

#if DEBUG
/// Debug view to help troubleshoot IAP issues
/// Add this to your settings or as a developer tool
struct IAPDebugView: View {
    @StateObject private var viewModel = AISettingsViewModel()
    @ObservedObject private var purchaseManager = PurchaseManager.shared
    
    @State private var productInfo: String = "Loading..."
    @State private var entitlements: String = "Checking..."
    @State private var showResetConfirmation = false
    
    var body: some View {
        List {
            Section("Purchase Status") {
                HStack {
                    Text("Is Premium")
                    Spacer()
                    Text(viewModel.isPremium ? "✅ Yes" : "❌ No")
                        .foregroundStyle(viewModel.isPremium ? .green : .red)
                }
                
                HStack {
                    Text("Is Purchased (StoreKit)")
                    Spacer()
                    Text(purchaseManager.isPurchased ? "✅ Yes" : "❌ No")
                        .foregroundStyle(purchaseManager.isPurchased ? .green : .red)
                }
                
                HStack {
                    Text("UserDefaults Premium")
                    Spacer()
                    Text(UserDefaults.standard.bool(forKey: "PremiumUnlocked") ? "✅ Yes" : "❌ No")
                        .foregroundStyle(UserDefaults.standard.bool(forKey: "PremiumUnlocked") ? .green : .red)
                }
            }
            
            Section("Product Information") {
                if let product = purchaseManager.premiumProduct {
                    VStack(alignment: .leading, spacing: 8) {
                        DetailRow(label: "Product ID", value: product.id)
                        DetailRow(label: "Display Name", value: product.displayName)
                        DetailRow(label: "Description", value: product.description)
                        DetailRow(label: "Price", value: product.displayPrice)
                        DetailRow(label: "Type", value: "\(product.type)")
                    }
                } else {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("Product not loaded")
                            .foregroundStyle(.secondary)
                    }
                    
                    Text("Product ID: com.deepticker.aiProAccess")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                if let error = purchaseManager.lastError {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Last Error:")
                            .font(.caption)
                            .foregroundStyle(.red)
                        Text(error)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            Section("Current Entitlements") {
                Button("Refresh Entitlements") {
                    Task {
                        await checkCurrentEntitlements()
                    }
                }
                
                Text(entitlements)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Section("Available Providers") {
                ForEach(viewModel.availableAPIProviders) { provider in
                    HStack {
                        Text(provider.rawValue)
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }
                
                if viewModel.availableAPIProviders.count == 1 {
                    Text("Only DeepSeek available (Free tier)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("All \(viewModel.availableAPIProviders.count) providers available")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }
            
            Section("Debug Actions") {
                Button("Reload Product") {
                    Task {
                        await purchaseManager.configure(productID: AISettingsViewModel.premiumProductID)
                        await checkCurrentEntitlements()
                    }
                }
                
                Button("Force Restore Purchases") {
                    Task {
                        await viewModel.restorePurchases()
                        await checkCurrentEntitlements()
                    }
                }
                
                Button("Reset Premium Status", role: .destructive) {
                    showResetConfirmation = true
                }
                .confirmationDialog("Reset Premium Status?", isPresented: $showResetConfirmation) {
                    Button("Reset (for testing)", role: .destructive) {
                        viewModel.resetPremiumStatus()
                        Task {
                            await checkCurrentEntitlements()
                        }
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This will reset your premium status to free tier. Use this for testing only.")
                }
                
                Button("Copy Product ID") {
                    UIPasteboard.general.string = AISettingsViewModel.premiumProductID
                }
            }
            
            Section("Console Logs") {
                Text("Check Xcode console for detailed logs starting with [PurchaseManager] and [AISettingsViewModel]")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("IAP Debug")
        .task {
            await checkCurrentEntitlements()
        }
    }
    
    private func checkCurrentEntitlements() async {
        var result = "Checking current entitlements...\n\n"
        var count = 0
        
        for await verificationResult in Transaction.currentEntitlements {
            count += 1
            switch verificationResult {
            case .verified(let transaction):
                result += "✅ Transaction \(count):\n"
                result += "  Product: \(transaction.productID)\n"
                result += "  Date: \(transaction.purchaseDate.formatted())\n"
                result += "  Type: \(transaction.productType)\n\n"
            case .unverified(let transaction, let error):
                result += "⚠️ Unverified Transaction \(count):\n"
                result += "  Product: \(transaction.productID)\n"
                result += "  Error: \(error.localizedDescription)\n\n"
            }
        }
        
        if count == 0 {
            result = "No current entitlements found.\n\nThis means you haven't made any purchases yet, or they haven't synced."
        } else {
            result = "Found \(count) entitlement(s):\n\n" + result
        }
        
        entitlements = result
    }
}

private struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline)
        }
    }
}

#Preview {
    NavigationStack {
        IAPDebugView()
    }
}
#endif
