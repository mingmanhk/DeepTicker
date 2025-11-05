# IAP Setup and Troubleshooting Guide

## ✅ What I Fixed

### 1. Updated Product ID
- Changed from placeholder to your actual product ID: `com.deepticker.aiProAccess`
- Location: `AISettingsViewModel.swift`

### 2. Created StoreKit Configuration File
- Created `Configuration.storekit` with your product details
- Product ID: `com.deepticker.aiProAccess`
- Internal ID: `6754631245`
- Type: Non-Consumable
- Price: $4.99

### 3. Enhanced Error Handling & Logging
- Added comprehensive console logging throughout `PurchaseManager`
- Added `lastError` property to track issues
- Added loading states to show when products are being fetched

### 4. Improved UI
- Updated `AISettingsView` with better purchase UI
- Created `ProAIPurchaseView` - a beautiful, dedicated purchase screen
- Added error messages and loading indicators
- Shows premium benefits clearly

### 5. Created Debug Tools
- Created `IAPDebugView` - comprehensive IAP debugging interface
- Added to Developer Tools section in Settings
- Shows product status, entitlements, and purchase state

## 🚀 Steps to Test Your IAP

### Step 1: Configure Xcode Scheme
1. In Xcode, go to **Product → Scheme → Edit Scheme**
2. Select **Run** in the left sidebar
3. Go to the **Options** tab
4. Under "StoreKit Configuration", select `Configuration.storekit`
5. Click **Close**

### Step 2: Clean Build
1. **Product → Clean Build Folder** (Shift + Cmd + K)
2. **Product → Build** (Cmd + B)

### Step 3: Run the App
1. Run your app in the simulator or on a device
2. Navigate to Settings → AI Settings (or wherever your purchase UI is)
3. You should now see the "Upgrade to Pro" section

### Step 4: Use the Debug Tool
1. Go to **Settings → Developer Tools**
2. Tap **IAP Debug Tool**
3. Check the status:
   - ✅ "Is Premium" should show "❌ No" (if you haven't purchased yet)
   - ✅ "Product Information" should show your product with price $4.99
   - ❌ If product shows "not loaded", there's a configuration issue

### Step 5: Test Purchase
1. From AISettingsView, tap "Upgrade to Pro" or use `ProAIPurchaseView`
2. In the simulator/test device, you should see Apple's StoreKit test purchase dialog
3. Complete the test purchase
4. The app should automatically detect the purchase and unlock premium features

## 🔍 Troubleshooting

### Problem: "Product not loaded" or button not showing

**Check These:**
1. **Scheme Configuration**: Make sure StoreKit configuration is selected in your scheme
2. **Product ID Match**: Verify `com.deepticker.aiProAccess` is exactly the same in:
   - `AISettingsViewModel.swift`
   - `Configuration.storekit`
   - App Store Connect (when ready for production)
3. **Check Console Logs**: Look for lines starting with `[PurchaseManager]`

**Expected Console Output:**
```
[PurchaseManager] Initialized
[PurchaseManager] Configuring with product ID: com.deepticker.aiProAccess
[PurchaseManager] Loading products: ["com.deepticker.aiProAccess"]
[PurchaseManager] ✅ Successfully loaded 1 products
[PurchaseManager]   - com.deepticker.aiProAccess: AI Pro Access - $4.99
[PurchaseManager] Configuration complete. Product loaded: true
```

**Bad Console Output:**
```
[PurchaseManager] ❌ Failed to load products: <error>
```
→ This means the product ID doesn't match or StoreKit config isn't loaded

### Problem: Button shows but purchase doesn't complete

**Possible Causes:**
1. **StoreKit test environment issue**: Restart Xcode and the simulator
2. **Previous test purchase in memory**: Delete the app and reinstall
3. **Transaction verification failing**: Check console for verification errors

### Problem: Already marked as premium (button doesn't show)

**Solution - Reset for Testing:**
1. Use the Debug Tool: Settings → Developer Tools → IAP Debug Tool
2. Tap "Reset Premium Status"
3. Or run this in Xcode console while app is running:
```swift
UserDefaults.standard.set(false, forKey: "PremiumUnlocked")
```

## 📱 Testing in Different Scenarios

### Test 1: Fresh Install (No Purchase)
- Delete app from device/simulator
- Reinstall
- Navigate to AI Settings
- ✅ Should see "Upgrade to Pro" section
- ✅ Should show product with price

### Test 2: Complete Purchase
- Tap "Upgrade to Pro" or "Quick Purchase"
- Complete the StoreKit test purchase
- ✅ Premium features should unlock immediately
- ✅ Button section should disappear
- ✅ All AI providers should become available

### Test 3: Restore Purchase
- Reset premium status using debug tool
- Tap "Restore Purchases"
- ✅ Should restore premium status without repurchasing

### Test 4: App Restart After Purchase
- Make a test purchase
- Force quit the app
- Relaunch the app
- ✅ Premium status should persist
- ✅ No "Upgrade" section should show

## 🏪 Production Checklist (App Store Connect)

Before releasing to the App Store, ensure:

1. **Product Created in App Store Connect**
   - Go to App Store Connect → Your App → Features → In-App Purchases
   - Create new Non-Consumable product
   - Product ID: `com.deepticker.aiProAccess`
   - Reference Name: Can be anything (e.g., "AI Pro Access")
   - Add pricing (Tier 5 = $4.99)
   - Add localizations and descriptions
   - Submit for review with your app

2. **Test with Sandbox Account**
   - Create a Sandbox tester in App Store Connect
   - Sign out of App Store on your test device
   - Test purchase flow with sandbox account
   - Verify purchase persists after app restart

3. **Remove Debug Code** (Optional but recommended)
   - The `#if DEBUG` sections will be automatically excluded in release builds
   - But you may want to remove `IAPDebugView.swift` entirely for App Store submission

4. **Update Terms & Privacy Links**
   - In `ProAIPurchaseView.swift`, add your actual terms and privacy policy URLs

## 📋 Files Modified/Created

### Modified:
- ✅ `AISettingsViewModel.swift` - Updated product ID, added error handling
- ✅ `PurchaseManager.swift` - Enhanced logging and error tracking
- ✅ `AISettingsView.swift` - Improved purchase UI with sheet presentation
- ✅ `SettingsUpgradeSnippet.swift` - Added loading states
- ✅ `ComprehensiveSettingsView.swift` - Added debug tool link

### Created:
- ✅ `Configuration.storekit` - StoreKit test configuration
- ✅ `IAPDebugView.swift` - Debugging interface
- ✅ `ProAIPurchaseView.swift` - Beautiful purchase screen
- ✅ `IAP_SETUP_GUIDE.md` - This guide

## 🎯 Quick Debug Commands

### View Current Purchase State
Open the IAP Debug Tool in app, or check console logs.

### Reset Premium for Testing
```swift
// In Xcode console while app is running:
expr UserDefaults.standard.set(false, forKey: "PremiumUnlocked")
```

### Check Current Entitlements
Use the "Refresh Entitlements" button in IAP Debug Tool.

## 📞 If You're Still Having Issues

Run through this checklist:
1. ⬜ StoreKit configuration file is selected in scheme
2. ⬜ Product ID matches exactly: `com.deepticker.aiProAccess`
3. ⬜ App has been cleaned and rebuilt
4. ⬜ Console shows "[PurchaseManager] ✅ Successfully loaded 1 products"
5. ⬜ IAP Debug Tool shows product information correctly
6. ⬜ Premium status is not already set to true

If all above are checked and it still doesn't work:
- Check console logs for specific error messages
- Try testing on a real device instead of simulator
- Ensure your Apple Developer account is active and in good standing

## 💡 Tips

- **Always test purchases in a test environment first** (StoreKit Configuration or Sandbox)
- **Never test with your real Apple ID** - always use sandbox accounts for production testing
- **The "Quick Purchase" button** in AI Settings provides immediate purchase without the fancy UI
- **The "Upgrade to Pro" button** presents the beautiful `ProAIPurchaseView` sheet
- **Use the IAP Debug Tool** whenever something seems wrong - it shows exactly what's happening

---

Good luck! Your IAP should now be working. 🎉
