# In-App Purchase Customization Guide

## 💰 Pricing Customization

### Change the Price

The price is set in **App Store Connect**, not in code. Your code automatically shows the correct localized price.

#### In App Store Connect:
1. Go to your IAP → Pricing
2. Select **Price Tier** or **Custom Price**
3. Common options:
   ```
   Tier 5:  $4.99 USD
   Tier 10: $9.99 USD
   Tier 15: $14.99 USD
   Tier 20: $19.99 USD
   Tier 30: $29.99 USD
   ```

#### The code automatically handles it:
```swift
// In AISettingsView.swift (already implemented)
if let product = viewModel.premiumProduct {
    Text(product.displayPrice)  // Shows "$4.99" or "€4,99" etc.
}
```

### Localized Pricing

StoreKit automatically converts prices:
- US: $4.99
- UK: £4.99
- EU: €4,99
- JP: ¥600
- etc.

---

## 🎨 UI Customization

### Option 1: Change the Product Name

Currently: "DeepSeek Pro"

**To change to "AI Premium", "Pro Access", etc:**

```swift
// In AISettingsView.swift, line ~169
VStack(alignment: .leading, spacing: 4) {
    Text("AI Premium")  // ← Change this
        .font(.title2)
        .fontWeight(.bold)
        .foregroundStyle(.primary)
    Text("Unlock All AI Models")  // ← And this
        .font(.subheadline)
        .foregroundStyle(.secondary)
}
```

### Option 2: Change the Button Text

Currently: "Purchase DeepSeek Pro"

```swift
// In AISettingsView.swift, line ~223
Button {
    Task { await viewModel.purchasePremium() }
} label: {
    HStack {
        Image(systemName: "cart.fill")
        Text("Upgrade to Premium")  // ← Change this
            .fontWeight(.semibold)
    }
    .frame(maxWidth: .infinity)
    .padding()
    .background(viewModel.premiumProduct == nil ? Color.gray : Color.accentColor)
    .foregroundStyle(.white)
    .cornerRadius(12)
}
```

### Option 3: Customize Features List

Currently shows 4 features. Add, remove, or modify:

```swift
// In AISettingsView.swift, line ~197
VStack(alignment: .leading, spacing: 10) {
    Text("Pro Features:")
        .font(.headline)
        .foregroundStyle(.primary)
    
    // Existing features
    FeatureRow(icon: "brain.head.profile", text: "Compare Multiple AI Models", color: .blue)
    FeatureRow(icon: "key.fill", text: "Use Your Own API Keys", color: .green)
    FeatureRow(icon: "text.bubble.fill", text: "Customize Analysis Prompts", color: .orange)
    FeatureRow(icon: "chart.line.uptrend.xyaxis", text: "Advanced Portfolio Insights", color: .purple)
    
    // Add new features:
    FeatureRow(icon: "star.fill", text: "Priority Support", color: .yellow)
    FeatureRow(icon: "bolt.fill", text: "Faster API Response Times", color: .red)
    FeatureRow(icon: "calendar.badge.plus", text: "Advanced Scheduling", color: .indigo)
}
```

### Option 4: Change Colors and Icons

**Crown icon** (currently yellow):
```swift
// Line ~17
Image(systemName: "crown.fill")
    .foregroundStyle(.purple)  // ← Change to purple, blue, etc.
```

**Button color** (currently accent color):
```swift
// Line ~227
.background(viewModel.premiumProduct == nil ? Color.gray : Color.purple)  // ← Custom color
```

**Feature icons** - Browse SF Symbols app for alternatives:
```swift
// Some good alternatives:
"sparkles"          // AI/Magic
"wand.and.stars"    // Premium
"diamond.fill"      // Luxury
"trophy.fill"       // Achievement
"medal.fill"        // Premium badge
"flame.fill"        // Hot feature
"bolt.shield.fill"  // Power/Protection
```

### Option 5: Alternative Layout Styles

#### Compact Style (Less Vertical Space):

```swift
// Replace the upgradeSection with:
private var upgradeSection: some View {
    VStack(spacing: 12) {
        // Header
        HStack {
            Image(systemName: "crown.fill")
                .foregroundStyle(.yellow)
                .font(.title)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("DeepSeek Pro")
                    .font(.headline)
                    .fontWeight(.bold)
                Text("Unlock all features")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            if let product = viewModel.premiumProduct {
                Text(product.displayPrice)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.tint)
            }
        }
        
        // Single purchase button
        Button {
            Task { await viewModel.purchasePremium() }
        } label: {
            Text("Upgrade Now")
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.accentColor)
                .foregroundStyle(.white)
                .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }
    .padding()
    .background(Color.accentColor.opacity(0.1))
    .cornerRadius(12)
}
```

#### Card Style with Shadow:

```swift
private var upgradeSection: some View {
    VStack(spacing: 16) {
        // ... existing content ...
    }
    .padding(20)
    .background(Color(.systemBackground))
    .cornerRadius(16)
    .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
    .overlay(
        RoundedRectangle(cornerRadius: 16)
            .stroke(Color.accentColor.opacity(0.3), lineWidth: 2)
    )
}
```

---

## 🎯 Feature Gating Customization

### Current Free vs Premium Split:

```
FREE:                    PREMIUM:
✅ DeepSeek             ✅ DeepSeek
❌ OpenAI               ✅ OpenAI
❌ Anthropic            ✅ Anthropic
❌ Google               ✅ Google
❌ Azure OpenAI         ✅ Azure OpenAI
❌ Custom prompts       ✅ Custom prompts
```

### Option 1: Offer More in Free Version

**Allow 2 providers free, rest premium:**

```swift
// In AISettingsViewModel.swift, applyEntitlementGating()
private func applyEntitlementGating() {
    if isPremium {
        availableAPIProviders = APIProvider.allCases
        isPromptEditingEnabled = true
    } else {
        // Offer DeepSeek AND OpenAI for free
        availableAPIProviders = [.deepseek, .openAI]
        isPromptEditingEnabled = false
        
        // Force to available options if needed
        if !availableAPIProviders.contains(selectedAPIProvider) {
            selectedAPIProvider = .deepseek
        }
    }
}
```

### Option 2: Offer Limited Custom Prompts in Free

**Allow editing but with character limit:**

```swift
// Add to AISettingsViewModel.swift
private(set) var maxPromptLength: Int = 0

private func applyEntitlementGating() {
    if isPremium {
        availableAPIProviders = APIProvider.allCases
        isPromptEditingEnabled = true
        maxPromptLength = 10000  // No real limit
    } else {
        availableAPIProviders = [.deepseek]
        isPromptEditingEnabled = true  // Allow editing
        maxPromptLength = 200  // But limit to 200 characters
        if selectedAPIProvider != .deepseek {
            selectedAPIProvider = .deepseek
        }
    }
}

// Update customPrompt setter:
@Published var customPrompt: String {
    didSet {
        // Enforce character limit for free users
        if customPrompt.count > maxPromptLength {
            customPrompt = String(customPrompt.prefix(maxPromptLength))
        }
        UserDefaults.standard.set(customPrompt, forKey: Self.promptKey)
    }
}
```

**In AISettingsView.swift:**
```swift
Section("Custom Prompt") {
    TextEditor(text: $viewModel.customPrompt)
        .frame(minHeight: 140)
        .disabled(!viewModel.isPromptEditingEnabled)
    
    if !viewModel.isPremium {
        HStack {
            Text("\(viewModel.customPrompt.count) / \(viewModel.maxPromptLength)")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text("Upgrade for unlimited")
                .font(.caption)
                .foregroundStyle(.orange)
        }
    }
}
```

### Option 3: Trial Period (Time-Based)

**Give 7 days of premium free, then require purchase:**

```swift
// Add to AISettingsViewModel.swift
private static let firstLaunchKey = "FirstLaunchDate"

init() {
    // ... existing init code ...
    
    // Check if user is in trial period
    let firstLaunch = UserDefaults.standard.object(forKey: Self.firstLaunchKey) as? Date ?? Date()
    if UserDefaults.standard.object(forKey: Self.firstLaunchKey) == nil {
        UserDefaults.standard.set(firstLaunch, forKey: Self.firstLaunchKey)
    }
    
    let trialDays = 7.0
    let trialEnds = firstLaunch.addingTimeInterval(trialDays * 24 * 60 * 60)
    let isInTrialPeriod = Date() < trialEnds
    
    // Apply premium during trial
    if isInTrialPeriod && !self.isPremium {
        print("[AISettingsViewModel] 🎁 Trial period active until \(trialEnds)")
        // Don't set isPremium, but allow features
        self.isInTrial = true
    }
    
    // ... rest of init ...
}

// Add published property
@Published private(set) var isInTrial: Bool = false

// Update gating
private func applyEntitlementGating() {
    if isPremium || isInTrial {
        availableAPIProviders = APIProvider.allCases
        isPromptEditingEnabled = true
    } else {
        availableAPIProviders = [.deepseek]
        isPromptEditingEnabled = false
        if selectedAPIProvider != .deepseek {
            selectedAPIProvider = .deepseek
        }
    }
}

// Add computed property for trial status
var trialDaysRemaining: Int {
    guard let firstLaunch = UserDefaults.standard.object(forKey: Self.firstLaunchKey) as? Date else {
        return 0
    }
    let trialEnds = firstLaunch.addingTimeInterval(7 * 24 * 60 * 60)
    let remaining = trialEnds.timeIntervalSince(Date())
    return max(0, Int(remaining / (24 * 60 * 60)))
}
```

**In AISettingsView.swift, show trial banner:**
```swift
if viewModel.isInTrial {
    Section {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "gift.fill")
                    .foregroundStyle(.green)
                Text("Trial Active")
                    .fontWeight(.semibold)
                Spacer()
                Text("\(viewModel.trialDaysRemaining) days left")
                    .foregroundStyle(.secondary)
            }
            Text("You're enjoying all Pro features for free!")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    } header: {
        Text("Free Trial")
    }
}
```

### Option 4: Usage-Based Limits

**Allow 10 free AI analyses per day, unlimited with premium:**

```swift
// Add to AISettingsViewModel.swift
private static let dailyUsageKey = "DailyAIUsageCount"
private static let usageDateKey = "LastUsageResetDate"
private let maxFreeUsagePerDay = 10

var remainingFreeUsages: Int {
    guard !isPremium else { return .max }
    
    let today = Calendar.current.startOfDay(for: Date())
    let lastReset = UserDefaults.standard.object(forKey: Self.usageDateKey) as? Date ?? Date.distantPast
    let lastResetDay = Calendar.current.startOfDay(for: lastReset)
    
    // Reset counter if it's a new day
    if today > lastResetDay {
        UserDefaults.standard.set(0, forKey: Self.dailyUsageKey)
        UserDefaults.standard.set(today, forKey: Self.usageDateKey)
    }
    
    let used = UserDefaults.standard.integer(forKey: Self.dailyUsageKey)
    return max(0, maxFreeUsagePerDay - used)
}

func trackAIUsage() {
    guard !isPremium else { return }
    
    let used = UserDefaults.standard.integer(forKey: Self.dailyUsageKey)
    UserDefaults.standard.set(used + 1, forKey: Self.dailyUsageKey)
}

var hasReachedDailyLimit: Bool {
    remainingFreeUsages <= 0
}
```

**Show in UI:**
```swift
if !viewModel.isPremium {
    Section {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Daily AI Analyses")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("\(viewModel.remainingFreeUsages) remaining today")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if viewModel.hasReachedDailyLimit {
                Button("Upgrade for Unlimited") {
                    // Scroll to upgrade section
                }
                .font(.caption)
                .foregroundStyle(.orange)
            }
        }
    } header: {
        Text("Free Usage")
    }
}
```

---

## 🎁 Promotional Offers

### Option 1: Launch Discount

**Show special launch pricing:**

```swift
// In AISettingsView.swift, modify price display:
if let product = viewModel.premiumProduct {
    HStack(alignment: .firstTextBaseline, spacing: 4) {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                Text(product.displayPrice)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundStyle(.tint)
                
                // Crossed-out original price
                Text("$9.99")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .strikethrough()
            }
            
            HStack(spacing: 4) {
                Image(systemName: "tag.fill")
                    .font(.caption2)
                    .foregroundStyle(.green)
                Text("50% Launch Discount")
                    .font(.caption)
                    .foregroundStyle(.green)
                    .fontWeight(.semibold)
            }
        }
        Spacer()
    }
    .padding(.vertical, 8)
    .padding(.horizontal, 12)
    .background(Color.green.opacity(0.1))
    .cornerRadius(8)
}
```

### Option 2: Seasonal Offers

```swift
// Add to AISettingsViewModel.swift
var currentPromotion: String? {
    let calendar = Calendar.current
    let month = calendar.component(.month, from: Date())
    
    switch month {
    case 11: return "🦃 Black Friday Special - 40% Off!"
    case 12: return "🎄 Holiday Sale - Limited Time!"
    case 1: return "🎊 New Year Offer - Start Fresh!"
    default: return nil
    }
}
```

**Display in view:**
```swift
if let promo = viewModel.currentPromotion {
    Text(promo)
        .font(.subheadline)
        .fontWeight(.semibold)
        .foregroundStyle(.orange)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(8)
}
```

---

## 🔧 Advanced Customization

### Option 1: Multiple IAP Tiers

**Offer Basic and Ultimate tiers:**

```swift
// Add to AISettingsViewModel.swift
enum PremiumTier: String, CaseIterable {
    case free = "Free"
    case basic = "Basic"
    case ultimate = "Ultimate"
}

static let basicProductID = "com.deepticker.basicAccess"
static let ultimateProductID = "com.deepticker.ultimateAccess"

@Published private(set) var currentTier: PremiumTier = .free
@Published private(set) var basicProduct: Product?
@Published private(set) var ultimateProduct: Product?

// Load both products
func configure() async {
    await purchaseManager.configure(productIDs: [
        Self.basicProductID,
        Self.ultimateProductID
    ])
    
    basicProduct = purchaseManager.product(for: Self.basicProductID)
    ultimateProduct = purchaseManager.product(for: Self.ultimateProductID)
    
    // Determine tier based on purchases
    if purchaseManager.isPurchased(Self.ultimateProductID) {
        currentTier = .ultimate
    } else if purchaseManager.isPurchased(Self.basicProductID) {
        currentTier = .basic
    } else {
        currentTier = .free
    }
}
```

**Show comparison table:**
```swift
// In AISettingsView.swift
struct TierComparisonView: View {
    let basic: Product?
    let ultimate: Product?
    
    var body: some View {
        VStack(spacing: 0) {
            // Headers
            HStack {
                Text("Feature")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Free")
                    .frame(width: 60)
                Text("Basic")
                    .frame(width: 60)
                Text("Ultimate")
                    .frame(width: 70)
            }
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.vertical, 8)
            .background(Color.secondary.opacity(0.1))
            
            Divider()
            
            // Feature rows
            TierRow(feature: "DeepSeek", free: true, basic: true, ultimate: true)
            TierRow(feature: "OpenAI & Anthropic", free: false, basic: true, ultimate: true)
            TierRow(feature: "All AI Models", free: false, basic: false, ultimate: true)
            TierRow(feature: "Custom Prompts", free: false, basic: true, ultimate: true)
            TierRow(feature: "Priority Support", free: false, basic: false, ultimate: true)
            
            Divider()
            
            // Pricing
            HStack {
                Text("")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("$0")
                    .frame(width: 60)
                    .font(.caption)
                Text(basic?.displayPrice ?? "—")
                    .frame(width: 60)
                    .font(.caption)
                    .fontWeight(.semibold)
                Text(ultimate?.displayPrice ?? "—")
                    .frame(width: 70)
                    .font(.caption)
                    .fontWeight(.semibold)
            }
            .padding(.vertical, 8)
        }
    }
}

struct TierRow: View {
    let feature: String
    let free: Bool
    let basic: Bool
    let ultimate: Bool
    
    var body: some View {
        HStack {
            Text(feature)
                .frame(maxWidth: .infinity, alignment: .leading)
                .font(.caption)
            
            Image(systemName: free ? "checkmark" : "xmark")
                .frame(width: 60)
                .foregroundStyle(free ? .green : .secondary)
            
            Image(systemName: basic ? "checkmark" : "xmark")
                .frame(width: 60)
                .foregroundStyle(basic ? .green : .secondary)
            
            Image(systemName: ultimate ? "checkmark" : "xmark")
                .frame(width: 70)
                .foregroundStyle(ultimate ? .green : .secondary)
        }
        .padding(.vertical, 6)
    }
}
```

---

**Save these customizations and mix-and-match to create your perfect IAP experience!** 🎨
