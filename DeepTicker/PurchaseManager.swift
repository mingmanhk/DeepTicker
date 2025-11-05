import Foundation
import Combine
import StoreKit

@MainActor
final class PurchaseManager: ObservableObject {
    var objectWillChange = ObservableObjectPublisher()
    
    static let shared = PurchaseManager()

    @Published private(set) var premiumProduct: Product?
    @Published private(set) var isPurchased: Bool = false
    @Published var lastError: String?

    private var updatesTask: Task<Void, Never>?

    private init() {
        print("[PurchaseManager] Initialized")
    }

    func configure(productID: String) async {
        print("[PurchaseManager] Configuring with product ID: \(productID)")
        await loadProducts(productIDs: [productID])
        updatesTask?.cancel()
        updatesTask = Task { [weak self] in
            await self?.listenForTransactions()
        }
        // Also check current entitlements at launch
        await refreshEntitlements()
        print("[PurchaseManager] Configuration complete. Product loaded: \(premiumProduct != nil)")
    }

    func loadProducts(productIDs: [String]) async {
        print("[PurchaseManager] Loading products: \(productIDs)")
        do {
            let products = try await Product.products(for: productIDs)
            print("[PurchaseManager] ✅ Successfully loaded \(products.count) products")
            for product in products {
                print("[PurchaseManager]   - \(product.id): \(product.displayName) - \(product.displayPrice)")
            }
            self.premiumProduct = products.first
            self.lastError = nil
        } catch {
            print("[PurchaseManager] ❌ Failed to load products: \(error)")
            self.lastError = error.localizedDescription
        }
    }

    func purchasePremium() async throws {
        guard let product = premiumProduct else { throw NSError(domain: "Purchase", code: -1, userInfo: [NSLocalizedDescriptionKey: "Product not loaded"]) }
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await transaction.finish()
            await refreshEntitlements()
        case .userCancelled:
            break
        case .pending:
            break
        @unknown default:
            break
        }
    }

    func restore() async {
        // StoreKit 2: iterate current entitlements
        await refreshEntitlements()
    }

    private func listenForTransactions() async {
        for await result in Transaction.updates {
            do {
                let transaction = try checkVerified(result)
                await transaction.finish()
                await refreshEntitlements()
            } catch {
                print("[PurchaseManager] Transaction verification failed: \(error)")
            }
        }
    }

    private func refreshEntitlements() async {
        var hasPremium = false
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                // If your premium is a non-consumable or auto-renewing subscription, mark purchased
                if transaction.productID == AISettingsViewModel.premiumProductID {
                    hasPremium = true
                }
            } catch {
                print("[PurchaseManager] Entitlement verification failed: \(error)")
            }
        }
        self.isPurchased = hasPremium
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw NSError(domain: "Purchase", code: -2, userInfo: [NSLocalizedDescriptionKey: "Unverified transaction"]) 
        case .verified(let safe):
            return safe
        }
    }
}

