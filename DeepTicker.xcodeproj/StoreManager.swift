// StoreManager.swift
// DeepTicker
//
// Manages StoreKit 2 product loading and purchase flow for Pro AI access.

import Foundation
import StoreKit

@MainActor
final class StoreManager: ObservableObject {
    // NOTE: The requirement mentions product id `com.deepticker.aiProAccess`.
    // If your App Store Connect ID differs, update this constant.
    static let proProductID = "com.deepticker.aiProAccess"

    @Published private(set) var product: Product?
    @Published var hasProAI: Bool {
        didSet { Persistence.setHasProAI(hasProAI) }
    }

    @Published var isLoading = false
    @Published var purchaseInFlight = false
    @Published var lastMessage: String?

    init() {
        self.hasProAI = Persistence.getHasProAI()
    }

    // Load product metadata from the App Store
    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let products = try await Product.products(for: [Self.proProductID])
            self.product = products.first
            if product == nil {
                lastMessage = "Unable to find product: \(Self.proProductID)"
            }
        } catch {
            lastMessage = "Failed to load products: \(error.localizedDescription)"
        }
    }

    // Trigger purchase flow using StoreKit 2
    func purchasePro() async {
        guard let product else {
            lastMessage = "Product not loaded yet."
            return
        }
        purchaseInFlight = true
        defer { purchaseInFlight = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                // Verify the transaction
                if let transaction = try? checkVerified(verification) {
                    // Treat as feature unlock in app state
                    hasProAI = true
                    await transaction.finish()
                    lastMessage = "AI Pro Access unlocked."
                } else {
                    lastMessage = "Purchase could not be verified."
                }

            case .userCancelled:
                lastMessage = "Purchase cancelled by user."

            case .pending:
                lastMessage = "Purchase is pending."

            @unknown default:
                lastMessage = "Unknown purchase result."
            }
        } catch {
            lastMessage = "Purchase failed: \(error.localizedDescription)"
        }
    }

    // Helper to verify StoreKit 2 transactions
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let safe):
            return safe
        }
    }
}

// MARK: - Simple Persistence facade
enum Persistence {
    private static let hasProKey = "hasProAI"

    static func getHasProAI() -> Bool {
        UserDefaults.standard.bool(forKey: hasProKey)
    }

    static func setHasProAI(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: hasProKey)
    }
}
