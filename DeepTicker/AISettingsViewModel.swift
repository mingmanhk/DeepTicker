// AISettingsViewModel.swift
// DeepTicker
//
// Holds settings state for API key and custom prompt with simple persistence.

import Foundation
import Combine
import StoreKit

@MainActor
final class AISettingsViewModel: ObservableObject {
    enum APIProvider: String, CaseIterable, Identifiable, Codable {
        case deepseek = "DeepSeek"
        case openAI = "OpenAI"
        case anthropic = "Anthropic"
        case google = "Google"
        case azureOpenAI = "Azure OpenAI"

        var id: String { rawValue }
    }

    // Premium gating
    @Published var isPremium: Bool {
        didSet { UserDefaults.standard.set(isPremium, forKey: Self.premiumKey) }
    }

    // Expose available providers depending on premium state
    @Published private(set) var availableAPIProviders: [APIProvider] = []

    // Selected provider
    @Published var selectedAPIProvider: APIProvider {
        didSet { UserDefaults.standard.set(selectedAPIProvider.rawValue, forKey: Self.providerKey) }
    }

    // Whether prompt editing is enabled
    @Published private(set) var isPromptEditingEnabled: Bool = false

    // StoreKit identifiers
    static let premiumProductID = "com.deepticker.aiProAccess"

    private static let premiumKey = "PremiumUnlocked"
    private static let providerKey = "SelectedAPIProvider"

    static let promptKey = "CustomAIAnalysisPrompt"
    static let apiKeyAccount = "AI_API_KEY"

    private let purchaseManager = PurchaseManager.shared

    @Published var apiKey: String {
        didSet { saveAPIKey() }
    }
    @Published var customPrompt: String {
        didSet { UserDefaults.standard.set(customPrompt, forKey: Self.promptKey) }
    }

    init() {
        self.isPremium = UserDefaults.standard.bool(forKey: Self.premiumKey)

        // Load API key from keychain
        self.apiKey = (try? keychain.get(account: Self.apiKeyAccount)) ?? ""

        // Load custom prompt
        self.customPrompt = UserDefaults.standard.string(forKey: Self.promptKey) ?? ""

        // Load selected provider (default to DeepSeek for free users)
        if let saved = UserDefaults.standard.string(forKey: Self.providerKey), let provider = APIProvider(rawValue: saved) {
            self.selectedAPIProvider = provider
        } else {
            self.selectedAPIProvider = .deepseek
        }

        // Apply gating
        applyEntitlementGating()

        Task { [weak self] in
            guard let self else { return }
            self.isLoadingProducts = true
            await purchaseManager.configure(productID: Self.premiumProductID)
            self.isLoadingProducts = false
            // Reflect current purchase state into our gating
            self.isPremium = purchaseManager.isPurchased || UserDefaults.standard.bool(forKey: Self.premiumKey)
            self.applyEntitlementGating()
            
            // Debug: Log product availability
            if purchaseManager.premiumProduct == nil {
                print("[AISettingsViewModel] ⚠️ Premium product not loaded. Check product ID and StoreKit configuration.")
            }
        }
    }

    private func applyEntitlementGating() {
        // Free: only DeepSeek, prompt editing disabled
        // Premium: all providers, prompt editing enabled
        if isPremium {
            availableAPIProviders = APIProvider.allCases
            isPromptEditingEnabled = true
        } else {
            availableAPIProviders = [.deepseek]
            isPromptEditingEnabled = false
            // Force provider to DeepSeek if not premium
            if selectedAPIProvider != .deepseek {
                selectedAPIProvider = .deepseek
            }
        }
    }

    private func syncPurchaseStateFromManager() {
        let purchased = purchaseManager.isPurchased
        if purchased != isPremium {
            isPremium = purchased
            applyEntitlementGating()
        }
    }

    // MARK: - Purchase Flow (wire this to StoreKit elsewhere)
    @MainActor
    func purchasePremium() async {
        purchaseError = nil
        do {
            try await purchaseManager.purchasePremium()
            syncPurchaseStateFromManager()
        } catch {
            // Keep free state on failure
            print("[AISettingsViewModel] Purchase failed: \(error)")
            purchaseError = error.localizedDescription
        }
    }

    @MainActor
    func restorePurchases() async {
        purchaseError = nil
        await purchaseManager.restore()
        syncPurchaseStateFromManager()
    }
    
    // MARK: - Debug Helper (Remove in production)
    #if DEBUG
    func resetPremiumStatus() {
        isPremium = false
        UserDefaults.standard.set(false, forKey: Self.premiumKey)
        applyEntitlementGating()
        print("[AISettingsViewModel] 🔄 Premium status reset for testing")
    }
    #endif

    private let keychain = KeychainStore()

    @Published var isLoadingProducts = false
    @Published var purchaseError: String?
    
    // Expose the product for price display
    var premiumProduct: Product? {
        purchaseManager.premiumProduct
    }

    private func saveAPIKey() {
        // In free version, only allow API key for DeepSeek provider
        if !isPremium && selectedAPIProvider != .deepseek {
            return
        }
        if apiKey.isEmpty {
            // Remove from Keychain when cleared
            try? keychain.delete(account: Self.apiKeyAccount)
        } else {
            try? keychain.set(apiKey, account: Self.apiKeyAccount)
        }
    }
}

