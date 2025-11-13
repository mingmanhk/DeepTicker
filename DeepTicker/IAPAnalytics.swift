import Foundation

/// Helper for tracking IAP events (ready for analytics integration)
@MainActor
final class IAPAnalytics {
    static let shared = IAPAnalytics()
    
    private init() {}
    
    // MARK: - Purchase Events
    
    func trackUpgradeScreenViewed(source: String) {
        log("upgrade_screen_viewed", parameters: ["source": source])
        // TODO: Integrate with your analytics service
        // Example: Analytics.logEvent("upgrade_screen_viewed", parameters: ["source": source])
    }
    
    func trackPurchaseStarted(productID: String) {
        log("purchase_started", parameters: ["product_id": productID])
    }
    
    func trackPurchaseCompleted(productID: String, price: String) {
        log("purchase_completed", parameters: [
            "product_id": productID,
            "price": price
        ])
    }
    
    func trackPurchaseFailed(productID: String, error: String) {
        log("purchase_failed", parameters: [
            "product_id": productID,
            "error": error
        ])
    }
    
    func trackPurchaseCancelled(productID: String) {
        log("purchase_cancelled", parameters: ["product_id": productID])
    }
    
    func trackRestoreStarted() {
        log("restore_started", parameters: [:])
    }
    
    func trackRestoreCompleted(hadPurchases: Bool) {
        log("restore_completed", parameters: ["had_purchases": hadPurchases])
    }
    
    // MARK: - Feature Usage (Pro Features)
    
    func trackProFeatureUsed(feature: String) {
        log("pro_feature_used", parameters: ["feature": feature])
    }
    
    func trackProFeatureBlocked(feature: String) {
        log("pro_feature_blocked", parameters: ["feature": feature])
        // This tells you which features drive conversions
    }
    
    // MARK: - Conversion Funnel
    
    func trackPaywallDismissed(viewDuration: TimeInterval) {
        log("paywall_dismissed", parameters: ["view_duration": viewDuration])
    }
    
    func trackProBadgeTapped(location: String) {
        log("pro_badge_tapped", parameters: ["location": location])
    }
    
    // MARK: - Internal Logging
    
    private func log(_ event: String, parameters: [String: Any]) {
        print("[IAPAnalytics] 📊 \(event): \(parameters)")
        
        // TODO: Add your analytics service here
        // Examples:
        // - Firebase Analytics: Analytics.logEvent(event, parameters: parameters)
        // - Mixpanel: Mixpanel.mainInstance().track(event: event, properties: parameters)
        // - TelemetryDeck: TelemetryManager.send(event, with: parameters)
    }
}

// MARK: - Convenience Extensions

extension IAPAnalytics {
    /// Track when user views a feature that requires Pro
    func trackProGateShown(feature: String, location: String) {
        log("pro_gate_shown", parameters: [
            "feature": feature,
            "location": location
        ])
    }
}
