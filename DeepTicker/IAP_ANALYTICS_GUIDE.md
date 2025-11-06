# In-App Purchase Analytics & Tracking Guide

## 📊 Why Track IAP Events?

Understanding your purchase funnel helps you:
- 🎯 Optimize conversion rates
- 💰 Identify pricing sweet spots
- 🐛 Debug purchase failures
- 📈 Measure revenue and growth
- 🔄 Improve restore purchase experience

---

## 1️⃣ Basic Analytics (Built-In Apple Analytics)

### App Store Connect Analytics

Apple automatically tracks (free):
- Units sold
- Revenue
- Conversion rate
- Proceeds
- Geographic breakdown
- Refund rates

**Access it:**
1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. Select your app
3. Go to **App Analytics** tab
4. Filter by **In-App Purchases**

**What you'll see:**
```
Purchases: 1,234 units
Revenue: $6,170
Conversion: 2.5%
Proceeds (your cut): $4,319 (after Apple's 30%)
```

---

## 2️⃣ Add Event Tracking to Your Code

### Simple Console Logging (Already Included)

Your code already has basic logging:

```swift
// In PurchaseManager.swift
print("[PurchaseManager] ✅ Successfully loaded \(products.count) products")
print("[AISettingsViewModel] 🎯 App Mode: \(self.isPremium ? "PREMIUM" : "FREE")")
```

### Enhanced Event Tracking

Let's add comprehensive analytics events:

```swift
// Add this to AISettingsViewModel.swift

// MARK: - Analytics Events
private func trackEvent(_ event: AnalyticsEvent, parameters: [String: Any] = [:]) {
    #if DEBUG
    print("📊 [Analytics] \(event.name): \(parameters)")
    #endif
    
    // Send to your analytics service
    // Examples: Firebase, Mixpanel, Amplitude, or custom backend
    // FirebaseAnalytics.Analytics.logEvent(event.name, parameters: parameters)
    // Mixpanel.mainInstance().track(event: event.name, properties: parameters)
}

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
```

### Track Purchase Flow

Update your purchase methods:

```swift
// In AISettingsViewModel.swift
@MainActor
func purchasePremium() async {
    trackEvent(.purchaseButtonTapped, parameters: [
        "product_id": Self.premiumProductID,
        "price": premiumProduct?.displayPrice ?? "unknown",
        "currency": premiumProduct?.priceFormatStyle.currencyCode ?? "USD"
    ])
    
    purchaseError = nil
    trackEvent(.purchaseStarted)
    
    do {
        try await purchaseManager.purchasePremium()
        syncPurchaseStateFromManager()
        
        if isPremium {
            trackEvent(.purchaseCompleted, parameters: [
                "product_id": Self.premiumProductID,
                "revenue": premiumProduct?.price ?? 0,
                "currency": premiumProduct?.priceFormatStyle.currencyCode ?? "USD"
            ])
        }
    } catch {
        print("[AISettingsViewModel] Purchase failed: \(error)")
        purchaseError = error.localizedDescription
        
        // Determine failure reason
        let failureReason: String
        if error.localizedDescription.contains("cancelled") {
            failureReason = "user_cancelled"
            trackEvent(.purchaseCancelled)
        } else {
            failureReason = error.localizedDescription
            trackEvent(.purchaseFailed, parameters: [
                "error": failureReason,
                "error_code": (error as NSError).code
            ])
        }
    }
}

@MainActor
func restorePurchases() async {
    trackEvent(.restoreButtonTapped)
    purchaseError = nil
    
    await purchaseManager.restore()
    syncPurchaseStateFromManager()
    
    if isPremium {
        trackEvent(.restoreCompleted, parameters: [
            "product_id": Self.premiumProductID
        ])
    } else {
        trackEvent(.restoreFailed, parameters: [
            "reason": "no_purchases_found"
        ])
    }
}
```

### Track View Events

```swift
// In AISettingsView.swift
var body: some View {
    Form {
        // ... existing content ...
    }
    .navigationTitle("AI Settings")
    .onAppear {
        viewModel.trackEvent(.settingsViewed, parameters: [
            "is_premium": viewModel.isPremium,
            "selected_provider": viewModel.selectedAPIProvider.rawValue
        ])
    }
}

// Track when upgrade section is seen
if !viewModel.isPremium {
    Section {
        upgradeSection
            .onAppear {
                viewModel.trackEvent(.upgradeSectionViewed, parameters: [
                    "product_loaded": viewModel.premiumProduct != nil,
                    "price": viewModel.premiumProduct?.displayPrice ?? "unknown"
                ])
            }
    }
}
```

### Track Feature Blocking

```swift
// Track when users try to use premium features
// In AISettingsView.swift, add to locked features:

Section("Custom Prompt") {
    TextEditor(text: $viewModel.customPrompt)
        .frame(minHeight: 140)
        .disabled(!viewModel.isPromptEditingEnabled)
        .simultaneousGesture(
            TapGesture().onEnded {
                if !viewModel.isPromptEditingEnabled {
                    viewModel.trackEvent(.premiumFeatureAttempted, parameters: [
                        "feature": "custom_prompt",
                        "is_premium": false
                    ])
                }
            }
        )
    
    if !viewModel.isPromptEditingEnabled {
        HStack(spacing: 8) {
            Image(systemName: "lock.fill")
                .foregroundStyle(.orange)
                .font(.caption)
            Text("DeepSeek Pro required to customize AI prompts")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .onTapGesture {
            viewModel.trackEvent(.premiumFeatureAttempted, parameters: [
                "feature": "custom_prompt_info_tapped",
                "is_premium": false
            ])
        }
    }
}
```

---

## 3️⃣ Firebase Analytics Integration

### Step 1: Add Firebase to Your Project

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Create project or select existing
3. Add iOS app
4. Download `GoogleService-Info.plist`
5. Add to Xcode project

### Step 2: Install Firebase SDK

**Using Swift Package Manager:**
1. File → Add Package Dependencies
2. Enter: `https://github.com/firebase/firebase-ios-sdk`
3. Select: **FirebaseAnalytics**

### Step 3: Initialize Firebase

```swift
// In your main App file (e.g., DeepTickerApp.swift)
import SwiftUI
import FirebaseCore

@main
struct DeepTickerApp: App {
    init() {
        FirebaseApp.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

### Step 4: Update Analytics Function

```swift
// In AISettingsViewModel.swift
import FirebaseAnalytics

private func trackEvent(_ event: AnalyticsEvent, parameters: [String: Any] = [:]) {
    #if DEBUG
    print("📊 [Analytics] \(event.name): \(parameters)")
    #endif
    
    // Send to Firebase
    Analytics.logEvent(event.name, parameters: parameters)
}

// Special: Track revenue
private func trackRevenue(productID: String, value: Decimal, currency: String) {
    Analytics.logEvent(AnalyticsEventPurchase, parameters: [
        AnalyticsParameterTransactionID: UUID().uuidString,
        AnalyticsParameterValue: value,
        AnalyticsParameterCurrency: currency,
        AnalyticsParameterItems: [
            [
                AnalyticsParameterItemID: productID,
                AnalyticsParameterItemName: "DeepSeek Pro",
                AnalyticsParameterItemCategory: "premium_access",
                AnalyticsParameterPrice: value,
                AnalyticsParameterQuantity: 1
            ]
        ]
    ])
}
```

### Step 5: View Analytics in Firebase

**Dashboard shows:**
- 👥 Active users
- 💰 Purchase revenue
- 📊 Event counts
- 🔄 User retention
- 📈 Conversion funnels

**Key Metrics to Watch:**
```
Funnel Analysis:
settings_viewed: 1,000 users (100%)
  ↓
upgrade_section_viewed: 600 users (60%)
  ↓
purchase_button_tapped: 150 users (15%)
  ↓
purchase_started: 120 users (12%)
  ↓
purchase_completed: 90 users (9%) ✅

Conversion Rate: 9%
Drop-off Points: Between button tap and start (20% abandon)
```

---

## 4️⃣ Custom Analytics Backend

### Simple REST API Tracking

```swift
// In AISettingsViewModel.swift

private func trackEvent(_ event: AnalyticsEvent, parameters: [String: Any] = [:]) {
    #if DEBUG
    print("📊 [Analytics] \(event.name): \(parameters)")
    #endif
    
    // Send to your own backend
    Task {
        await sendEventToServer(event: event, parameters: parameters)
    }
}

private func sendEventToServer(event: AnalyticsEvent, parameters: [String: Any]) async {
    guard let url = URL(string: "https://your-api.com/analytics") else { return }
    
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    
    let payload: [String: Any] = [
        "event": event.name,
        "parameters": parameters,
        "timestamp": ISO8601DateFormatter().string(from: Date()),
        "platform": "ios",
        "app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
        "device_id": UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
    ]
    
    do {
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        let (_, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
            #if DEBUG
            print("✅ Analytics sent successfully")
            #endif
        }
    } catch {
        #if DEBUG
        print("❌ Failed to send analytics: \(error)")
        #endif
    }
}
```

### Your Backend Endpoint Example (Node.js):

```javascript
// server.js
const express = require('express');
const app = express();

app.use(express.json());

app.post('/analytics', (req, res) => {
    const { event, parameters, timestamp, platform, app_version, device_id } = req.body;
    
    console.log(`📊 Event: ${event}`);
    console.log(`   Platform: ${platform}`);
    console.log(`   Time: ${timestamp}`);
    console.log(`   Data:`, parameters);
    
    // Store in database
    // db.collection('analytics').insertOne({ event, parameters, timestamp, platform, app_version, device_id });
    
    res.status(200).json({ success: true });
});

app.listen(3000);
```

---

## 5️⃣ Key Metrics to Track

### Purchase Funnel Metrics

```swift
// Track these events to build your funnel:

1. settings_viewed
   ↓ (What % see upgrade section?)
2. upgrade_section_viewed
   ↓ (What % tap purchase?)
3. purchase_button_tapped
   ↓ (What % complete StoreKit flow?)
4. purchase_started
   ↓ (What % successfully verify?)
5. purchase_completed ← Success!

// Also track:
- purchase_failed (why?)
- purchase_cancelled (how often?)
```

### Revenue Metrics

```swift
// Track with each purchase:
- Revenue amount (product price)
- Currency
- Product ID
- User lifetime value
- Days since install
- Previous attempts

// Calculate:
- Average Revenue Per User (ARPU)
- Average Revenue Per Paying User (ARPPU)
- Lifetime Value (LTV)
- Payback period
```

### Feature Usage Metrics

```swift
// Track what drives purchases:
- Which AI provider users prefer
- How often they hit free limits
- Which premium features they try when locked
- Time spent in settings
- Days between install and purchase

// Example:
trackEvent(.premiumFeatureAttempted, parameters: [
    "feature": "openai_provider",
    "days_since_install": daysSinceInstall,
    "total_analyses": totalAnalysesCount
])
```

### Retention Metrics

```swift
// Track premium user retention:
- Day 1 retention
- Day 7 retention
- Day 30 retention
- Churn rate
- Reactivation rate

// Example:
if isPremium {
    trackEvent(.dailyActiveUser, parameters: [
        "days_since_purchase": daysSincePurchase,
        "usage_frequency": usageThisWeek
    ])
}
```

---

## 6️⃣ A/B Testing Your IAP

### Test Different Prices

```swift
// Randomly assign users to price test groups
enum PriceTestGroup: Int {
    case control = 0  // $4.99
    case testA = 1    // $2.99
    case testB = 2    // $7.99
}

var priceTestGroup: PriceTestGroup {
    let stored = UserDefaults.standard.integer(forKey: "PriceTestGroup")
    if let group = PriceTestGroup(rawValue: stored) {
        return group
    } else {
        // Assign random group on first launch
        let newGroup = PriceTestGroup(rawValue: Int.random(in: 0...2)) ?? .control
        UserDefaults.standard.set(newGroup.rawValue, forKey: "PriceTestGroup")
        return newGroup
    }
}

// Create different product IDs for each price
var productIDForTestGroup: String {
    switch priceTestGroup {
    case .control: return "com.deepticker.aiProAccess"
    case .testA: return "com.deepticker.aiProAccess.testA"
    case .testB: return "com.deepticker.aiProAccess.testB"
    }
}

// Track which group purchases
trackEvent(.purchaseCompleted, parameters: [
    "price_test_group": priceTestGroup.rawValue,
    "price": premiumProduct?.displayPrice ?? "unknown"
])
```

### Test Different Copy

```swift
enum UpgradeCopyVariant: Int {
    case control = 0  // "DeepSeek Pro"
    case testA = 1    // "AI Premium"
    case testB = 2    // "Unlimited Access"
}

var copyVariant: UpgradeCopyVariant {
    // Similar assignment logic
}

var upgradeTitleText: String {
    switch copyVariant {
    case .control: return "DeepSeek Pro"
    case .testA: return "AI Premium"
    case .testB: return "Unlimited Access"
    }
}

// Track conversion by variant
trackEvent(.purchaseCompleted, parameters: [
    "copy_variant": copyVariant.rawValue,
    "title_text": upgradeTitleText
])
```

### Test Feature Highlighting

```swift
// Show different feature lists to different users
enum FeatureVariant: Int {
    case control = 0   // Standard 4 features
    case testA = 1     // Emphasize cost savings
    case testB = 2     // Emphasize quality
}

var featureHighlight: [String] {
    switch featureVariant {
    case .control:
        return ["Multiple AI Models", "Custom Keys", "Custom Prompts", "Advanced Insights"]
    case .testA:
        return ["Save $50/month", "Use Your Keys", "Unlimited Requests", "Priority Support"]
    case .testB:
        return ["Best AI Quality", "Pro Features", "Expert Analysis", "Premium Access"]
    }
}
```

---

## 7️⃣ Analytics Dashboard Example

### Simple SwiftUI Analytics View

```swift
struct AnalyticsDashboardView: View {
    @StateObject private var analytics = AnalyticsManager.shared
    
    var body: some View {
        List {
            Section("Revenue") {
                MetricRow(label: "Total Revenue", value: "$\(analytics.totalRevenue)")
                MetricRow(label: "Purchases", value: "\(analytics.purchaseCount)")
                MetricRow(label: "ARPU", value: "$\(analytics.arpu)")
            }
            
            Section("Conversion") {
                MetricRow(label: "Settings Views", value: "\(analytics.settingsViews)")
                MetricRow(label: "Purchase Taps", value: "\(analytics.purchaseTaps)")
                MetricRow(label: "Conversion Rate", value: "\(analytics.conversionRate)%")
            }
            
            Section("Funnel") {
                FunnelRow(step: "Viewed Settings", count: analytics.settingsViews, percentage: 100)
                FunnelRow(step: "Saw Upgrade", count: analytics.upgradeViews, percentage: analytics.upgradeViewPercentage)
                FunnelRow(step: "Tapped Purchase", count: analytics.purchaseTaps, percentage: analytics.purchaseTapPercentage)
                FunnelRow(step: "Completed", count: analytics.purchaseCount, percentage: analytics.purchasePercentage)
            }
        }
        .navigationTitle("Analytics")
    }
}

struct MetricRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
        }
    }
}

struct FunnelRow: View {
    let step: String
    let count: Int
    let percentage: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(step)
                Spacer()
                Text("\(count)")
                    .fontWeight(.semibold)
            }
            
            ProgressView(value: percentage / 100)
                .tint(.blue)
            
            Text("\(Int(percentage))% of users")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
```

---

## 8️⃣ Privacy Considerations

### App Tracking Transparency (ATT)

If using third-party analytics (Firebase, Mixpanel, etc.):

```swift
import AppTrackingTransparency

func requestTrackingPermission() async {
    if #available(iOS 14, *) {
        let status = await ATTrackingManager.requestTrackingAuthorization()
        switch status {
        case .authorized:
            print("✅ Tracking authorized")
            // Enable full analytics
        case .denied, .restricted:
            print("❌ Tracking denied")
            // Use privacy-safe analytics only
        case .notDetermined:
            break
        @unknown default:
            break
        }
    }
}
```

### Privacy-Safe Analytics

Always safe to track (no ATT needed):
- ✅ Events within your app
- ✅ Purchase events
- ✅ Feature usage
- ✅ App version and platform
- ✅ Anonymous aggregate data

Requires ATT permission:
- ❌ Cross-app tracking
- ❌ Sharing data with third parties for ads
- ❌ Device fingerprinting

---

## 📈 Success Metrics Benchmarks

### Good IAP Performance:

```
Conversion Rate:
• 1-3%: Good for utility apps
• 3-5%: Great performance
• 5%+: Excellent!

Your goal: 2-3% (free to paid)

ARPU (Average Revenue Per User):
• $0.50-$2: Standard for freemium
• $2-$5: Strong monetization
• $5+: Premium positioning

Your target: $1-$2 with $4.99 price

Restore Success Rate:
• 95%+: Expected
• 90-95%: Monitor for issues
• <90%: Investigate problems
```

---

**Your analytics are now comprehensive and actionable!** 📊✨

Next steps:
1. Implement basic event tracking
2. Choose analytics provider (Firebase recommended)
3. Monitor conversion funnel
4. Optimize based on data
5. A/B test improvements
