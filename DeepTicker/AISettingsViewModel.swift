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

    // Shared instance
    static let shared = AISettingsViewModel()

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
        // IMPORTANT: Default to FREE mode
        // Only set to premium if explicitly purchased and verified by StoreKit
        // DO NOT rely on UserDefaults - always start as free until StoreKit confirms
        self.isPremium = false

        // Load API key from keychain
        let service = Bundle.main.bundleIdentifier ?? "DeepTicker"
        self.apiKey = KeychainHelper.standard.read(service: service, account: Self.apiKeyAccount) ?? ""

        // Load custom prompt
        self.customPrompt = UserDefaults.standard.string(forKey: Self.promptKey) ?? ""

        // Load selected provider (default to DeepSeek for free users)
        if let saved = UserDefaults.standard.string(forKey: Self.providerKey), let provider = APIProvider(rawValue: saved) {
            self.selectedAPIProvider = provider
        } else {
            self.selectedAPIProvider = .deepseek
        }

        // Apply gating (defaults to free mode)
        applyEntitlementGating()

        Task { [weak self] in
            guard let self else { return }
            self.isLoadingProducts = true
            await purchaseManager.configure(productID: Self.premiumProductID)
            self.isLoadingProducts = false
            
            // ONLY set premium if StoreKit confirms the purchase
            // This ensures we don't have false positives
            self.isPremium = purchaseManager.isPurchased
            self.applyEntitlementGating()
            
            // Debug logging
            print("[AISettingsViewModel] 🎯 App Mode: \(self.isPremium ? "PREMIUM" : "FREE (Default)")")
            print("[AISettingsViewModel] 📦 Product Loaded: \(purchaseManager.premiumProduct != nil ? "YES" : "NO")")
            
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
            // Free version: Only DeepSeek for AI analysis
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
        trackAnalytics(.purchaseButtonTapped, parameters: [
            "product_id": Self.premiumProductID,
            "price": premiumProduct?.displayPrice ?? "unknown"
        ])
        
        purchaseError = nil
        trackAnalytics(.purchaseStarted)
        
        do {
            try await purchaseManager.purchasePremium()
            syncPurchaseStateFromManager()
            
            if isPremium {
                trackAnalytics(.purchaseCompleted, parameters: [
                    "product_id": Self.premiumProductID,
                    "price": premiumProduct?.displayPrice ?? "unknown"
                ])
            }
        } catch {
            // Keep free state on failure
            print("[AISettingsViewModel] Purchase failed: \(error)")
            purchaseError = error.localizedDescription
            
            // Track failure reason
            if error.localizedDescription.contains("cancel") {
                trackAnalytics(.purchaseCancelled)
            } else {
                trackAnalytics(.purchaseFailed, parameters: [
                    "error": error.localizedDescription,
                    "error_code": (error as NSError).code
                ])
            }
        }
    }

    @MainActor
    func restorePurchases() async {
        trackAnalytics(.restoreButtonTapped)
        purchaseError = nil
        
        await purchaseManager.restore()
        syncPurchaseStateFromManager()
        
        if isPremium {
            trackAnalytics(.restoreCompleted, parameters: [
                "product_id": Self.premiumProductID
            ])
        } else {
            trackAnalytics(.restoreFailed, parameters: [
                "reason": "no_purchases_found"
            ])
        }
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
        
        let service = Bundle.main.bundleIdentifier ?? "DeepTicker"
        
        if apiKey.isEmpty {
            // Remove from Keychain when cleared
            KeychainHelper.standard.delete(service: service, account: Self.apiKeyAccount)
        } else {
            KeychainHelper.standard.save(apiKey, service: service, account: Self.apiKeyAccount)
        }
    }
    
    // MARK: - Analytics Tracking
    
    /// Analytics events for IAP tracking
    enum AnalyticsEvent {
        case settingsViewed
        case upgradeSectionViewed
        case purchaseButtonTapped
        case purchaseStarted
        case purchaseCompleted
        case purchaseFailed
        case purchaseCancelled
        case restoreButtonTapped
        case restoreCompleted
        case restoreFailed
        case premiumFeatureAttempted
        
        var name: String {
            switch self {
            case .settingsViewed: return "settings_viewed"
            case .upgradeSectionViewed: return "upgrade_section_viewed"
            case .purchaseButtonTapped: return "purchase_button_tapped"
            case .purchaseStarted: return "purchase_started"
            case .purchaseCompleted: return "purchase_completed"
            case .purchaseFailed: return "purchase_failed"
            case .purchaseCancelled: return "purchase_cancelled"
            case .restoreButtonTapped: return "restore_button_tapped"
            case .restoreCompleted: return "restore_completed"
            case .restoreFailed: return "restore_failed"
            case .premiumFeatureAttempted: return "premium_feature_attempted"
            }
        }
    }
    
    /// Track analytics events with optional parameters
    /// - Parameters:
    ///   - event: The event to track
    ///   - parameters: Additional context data
    func trackAnalytics(_ event: AnalyticsEvent, parameters: [String: Any] = [:]) {
        #if DEBUG
        print("📊 [Analytics] \(event.name): \(parameters)")
        #endif
        
        // TODO: Integrate with your analytics service
        // Examples:
        // - Firebase: Analytics.logEvent(event.name, parameters: parameters)
        // - Mixpanel: Mixpanel.mainInstance().track(event: event.name, properties: parameters)
        // - Custom backend: sendEventToServer(event: event, parameters: parameters)
        
        // For now, just console logging in debug mode
    }
}

