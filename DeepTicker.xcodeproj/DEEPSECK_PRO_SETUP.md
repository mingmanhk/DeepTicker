# DeepSeek Pro - IAP Setup Guide

## ✅ Your Product Details

- **Product ID**: `com.deepticker.aiProAccess`
- **Reference Name**: DeepSeek Pro
- **Internal ID**: 6754631245
- **Type**: Non-Consumable (One-time purchase)
- **Price**: $4.99

## 🎯 Feature Purpose

**DeepSeek Pro** unlocks advanced AI customization:

### Free Version (Built-in):
- ✅ Built-in DeepSeek AI model
- ✅ Basic portfolio analysis
- ✅ Preset AI prompts

### Pro Version (After Purchase):
- ✅ Compare multiple AI models (OpenAI, Qwen, etc.)
- ✅ Use your own API keys for each model
- ✅ Customize AI analysis prompts
- ✅ Tailor insights to your investment strategy

## 🚀 Quick Start Guide

### Step 1: Configure Xcode for Testing
1. Open your project in Xcode
2. Go to **Product → Scheme → Edit Scheme**
3. Select **Run** in the sidebar
4. Go to **Options** tab
5. Under "StoreKit Configuration", select **Configuration.storekit**
6. Click **Close**

### Step 2: Build and Run
1. Clean: **Product → Clean Build Folder** (⇧⌘K)
2. Build: **Product → Build** (⌘B)
3. Run: **Product → Run** (⌘R)

### Step 3: Navigate to Purchase Screen
1. Open the app
2. Go to **Settings → AI Settings**
3. You should see:
   - "AI Model" section (locked to DeepSeek)
   - "Your API Key" section
   - "Custom Prompt" section (disabled)
   - **"DeepSeek Pro"** upgrade section with purchase buttons

### Step 4: Test Purchase
1. Tap "Upgrade to DeepSeek Pro" (shows beautiful purchase screen)
   - OR tap "Quick Purchase" (direct purchase)
2. In simulator/test device, Apple's StoreKit dialog will appear
3. Complete the test purchase
4. ✅ All AI models should unlock
5. ✅ Custom prompts should become editable

## 🔍 Troubleshooting

### ❌ Problem: Purchase button not showing

**Check Console Logs:**
```
[PurchaseManager] Configuring with product ID: com.deepticker.aiProAccess
[PurchaseManager] Loading products: ["com.deepticker.aiProAccess"]
```

**Expected (Good):**
```
[PurchaseManager] ✅ Successfully loaded 1 products
[PurchaseManager]   - com.deepticker.aiProAccess: DeepSeek Pro - $4.99
```

**Error (Bad):**
```
[PurchaseManager] ❌ Failed to load products: <error>
```

**Solutions:**
1. ✅ Verify StoreKit configuration is selected in scheme
2. ✅ Check product ID is exactly: `com.deepticker.aiProAccess`
3. ✅ Restart Xcode and simulator
4. ✅ Delete app and reinstall

### ❌ Problem: Button shows but already marked as Pro

**Solution - Use Debug Tool:**
1. Go to **Settings → Developer Tools → IAP Debug Tool**
2. Check "Purchase Status" section:
   - Shows current premium state
   - Shows product information
   - Shows entitlements
3. Tap **"Reset Premium Status"** button
4. Return to AI Settings - button should now show

**Alternative - Console Command:**
```swift
// While app is running in Xcode:
expr UserDefaults.standard.set(false, forKey: "PremiumUnlocked")
```

### ❌ Problem: Product shows but purchase doesn't work

**Check:**
1. Console for transaction errors
2. StoreKit configuration file is in your project
3. Simulator has internet connection
4. Try on a real device

## 🧪 Test Scenarios

### ✅ Test 1: Fresh Install
- Delete app
- Reinstall
- Navigate to AI Settings
- Should see "DeepSeek Pro" upgrade section
- Only DeepSeek provider available
- Prompts are read-only

### ✅ Test 2: Purchase Flow
- Tap "Upgrade to DeepSeek Pro"
- Beautiful purchase screen appears
- Shows features and pricing
- Complete test purchase
- All AI providers unlock immediately
- Custom prompts become editable
- Upgrade section disappears

### ✅ Test 3: App Restart
- Make purchase
- Force quit app
- Reopen app
- Pro status should persist
- All features remain unlocked

### ✅ Test 4: Restore Purchases
- Use debug tool to reset premium
- Tap "Restore Purchases"
- Pro status restores without repurchasing

## 📱 What You'll See

### Before Purchase (Free):
```
AI Model
├─ Provider: [DeepSeek ▼]  🔒 Upgrade to compare multiple AI models

Your API Key
├─ [Enter API Key...]
└─ 🔒 DeepSeek Pro required to use your own API keys

Custom Prompt
├─ [Read-only preview of prompt...]
└─ 🔒 DeepSeek Pro required to customize AI prompts

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

DeepSeek Pro
├─ 👑 Upgrade to DeepSeek Pro              ›
├─ ━━━━━━━━━━━━━━━━━━━━━━━━━━
├─ 🛒 Quick Purchase
└─ 🔄 Restore Purchases

DeepSeek Pro unlocks:
• Compare multiple AI models (OpenAI, Qwen, etc.)
• Use your own API keys for each model
• Customize AI analysis prompts
• Tailor insights to your investment strategy

Free version includes built-in DeepSeek model with preset prompts.
```

### After Purchase (Pro):
```
AI Model
└─ Provider: [DeepSeek ▼ OpenAI, Qwen, Anthropic, Google, Azure]

Your API Key
└─ [Enter API Key...] ← Editable for all providers

Custom Prompt
└─ [Fully editable prompt text...] ← Can customize
```

## 🎨 UI Components Created

### 1. **ProAIPurchaseView** (Main Purchase Screen)
- Beautiful gradient hero section
- Feature list with icons
- Free vs Pro comparison table
- Pricing card
- Purchase and restore buttons
- Error handling
- Debug menu (DEBUG builds only)

### 2. **AISettingsView** (Settings Integration)
- "Upgrade to DeepSeek Pro" featured button (opens ProAIPurchaseView)
- "Quick Purchase" direct button
- "Restore Purchases" button
- Loading states
- Error messages
- Lock icons on restricted features

### 3. **IAPDebugView** (Developer Tool)
- Real-time purchase status
- Product information display
- Entitlements viewer
- Reset premium status
- Reload product
- Force restore

## 🏪 Production Checklist

### Before App Store Submission:

1. **App Store Connect Setup**
   - Create IAP in App Store Connect
   - Product ID: `com.deepticker.aiProAccess`
   - Reference Name: DeepSeek Pro
   - Type: Non-Consumable
   - Price: $4.99 (Tier 5)
   - Add descriptions and screenshots
   - Submit for review

2. **Test with Sandbox Account**
   - Create sandbox tester in App Store Connect
   - Sign out of App Store on test device
   - Test complete purchase flow
   - Verify restoration works
   - Test app restart persistence

3. **Update Terms Links** (Optional)
   In `ProAIPurchaseView.swift`, update these URLs:
   ```swift
   // Line ~250
   if let url = URL(string: "https://yourapp.com/terms") {
   if let url = URL(string: "https://yourapp.com/privacy") {
   ```

4. **Code Cleanup** (Optional)
   - Debug tools are already wrapped in `#if DEBUG`
   - They won't appear in App Store builds
   - But you can remove `IAPDebugView.swift` if preferred

## 🎯 Console Commands (While Debugging)

### Check Product Loading
Look for these logs when app launches:
```
[PurchaseManager] Initialized
[PurchaseManager] Configuring with product ID: com.deepticker.aiProAccess
[PurchaseManager] ✅ Successfully loaded 1 products
```

### Reset Premium Status
```swift
expr UserDefaults.standard.set(false, forKey: "PremiumUnlocked")
```

### Check UserDefaults
```swift
po UserDefaults.standard.bool(forKey: "PremiumUnlocked")
```

## 📊 Files Modified

### Updated:
- ✅ `PurchaseManager.swift` - Enhanced logging, error tracking
- ✅ `AISettingsViewModel.swift` - Product ID, loading states
- ✅ `AISettingsView.swift` - Beautiful purchase UI, messaging
- ✅ `SettingsUpgradeSnippet.swift` - Updated messaging
- ✅ `ComprehensiveSettingsView.swift` - Added debug tool link

### Created:
- ✅ `Configuration.storekit` - Test configuration
- ✅ `ProAIPurchaseView.swift` - Main purchase screen
- ✅ `IAPDebugView.swift` - Debug interface
- ✅ `IAP_SETUP_GUIDE.md` - This guide

## 🎉 Success Criteria

Your IAP is working correctly when:

1. ✅ Console shows: "Successfully loaded 1 products"
2. ✅ AI Settings shows "DeepSeek Pro" section
3. ✅ Tapping "Upgrade" shows purchase screen with $4.99
4. ✅ Test purchase unlocks all features immediately
5. ✅ Features remain unlocked after app restart
6. ✅ "Restore Purchases" works correctly
7. ✅ Free users see lock icons on Pro features

## 🆘 Still Having Issues?

### Use the Debug Tool:
1. Settings → Developer Tools → IAP Debug Tool
2. Check all status indicators
3. Tap "Reload Product"
4. Check entitlements
5. Try "Reset Premium Status"

### Check This Checklist:
- [ ] StoreKit config selected in scheme
- [ ] Product ID is exactly: `com.deepticker.aiProAccess`
- [ ] App cleaned and rebuilt
- [ ] Console shows successful product load
- [ ] Not already marked as premium in UserDefaults

### Common Fixes:
1. Restart Xcode
2. Delete app from simulator
3. Clean build folder (⇧⌘K)
4. Rebuild and run
5. Check console for specific errors

---

## 💡 Pro Tips

- **Always test in StoreKit environment first** before sandbox/production
- **Use the Debug Tool** - it shows everything happening with IAP
- **Featured button** (Upgrade to DeepSeek Pro) shows beautiful UI
- **Quick Purchase** button is faster for testing
- **Lock icons** (🔒) clearly show users what's restricted
- **Console logs** tell you exactly what's happening

---

🎊 **Your IAP is now fully configured and should be working!**

Run the app, navigate to AI Settings, and you should see the purchase button.

If you see the "DeepSeek Pro" section with pricing, you're all set! 🚀
