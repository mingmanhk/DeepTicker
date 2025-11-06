# Testing In-App Purchases Guide

## 🧪 Sandbox Testing (Recommended for Development)

### Step 1: Create a StoreKit Configuration File

1. **In Xcode**: File → New → File
2. Search for **"StoreKit Configuration File"**
3. Name it: `DeepTickerStore.storekit`
4. Click **Create**

### Step 2: Configure Your Product

Add this to your `.storekit` file (or edit in the visual editor):

```json
{
  "identifier" : "DeepTickerStore",
  "nonRenewingSubscriptions" : [],
  "products" : [
    {
      "displayPrice" : "4.99",
      "familyShareable" : false,
      "internalID" : "6670432889",
      "localizations" : [
        {
          "description" : "Unlock all AI providers, custom prompts, and advanced analysis features",
          "displayName" : "DeepSeek Pro",
          "locale" : "en_US"
        }
      ],
      "productID" : "com.deepticker.aiProAccess",
      "referenceName" : "DeepSeek Pro",
      "type" : "NonConsumable"
    }
  ],
  "settings" : {
    "_applicationInternalID" : "6670432889",
    "_developerTeamID" : "YOUR_TEAM_ID",
    "_failTransactionsEnabled" : false,
    "_lastSynchronizedDate" : 752198400.0,
    "_locale" : "en_US",
    "_storefront" : "USA",
    "_storeKitErrors" : [
      {
        "current" : null,
        "enabled" : false,
        "name" : "Load Products"
      },
      {
        "current" : null,
        "enabled" : false,
        "name" : "Purchase"
      },
      {
        "current" : null,
        "enabled" : false,
        "name" : "Verification"
      },
      {
        "current" : null,
        "enabled" : false,
        "name" : "App Store Sync"
      },
      {
        "current" : null,
        "enabled" : false,
        "name" : "Subscription Status"
      },
      {
        "current" : null,
        "enabled" : false,
        "name" : "App Transaction"
      },
      {
        "current" : null,
        "enabled" : false,
        "name" : "Manage Subscriptions Sheet"
      },
      {
        "current" : null,
        "enabled" : false,
        "name" : "Refund Request Sheet"
      },
      {
        "current" : null,
        "enabled" : false,
        "name" : "Offer Code Redeem Sheet"
      }
    ]
  },
  "subscriptions" : [],
  "version" : {
    "major" : 3,
    "minor" : 0
  }
}
```

### Step 3: Enable StoreKit Testing in Xcode

1. **Edit your scheme**: Product → Scheme → Edit Scheme... (or ⌘+<)
2. Select **Run** in the left sidebar
3. Go to **Options** tab
4. Under **StoreKit Configuration**, select: `DeepTickerStore.storekit`
5. Click **Close**

### Step 4: Run and Test

```
Build and Run (⌘+R)
  ↓
Navigate to Settings → AI Settings
  ↓
See "Upgrade to Pro" section
  ↓
Tap "Purchase DeepSeek Pro"
  ↓
StoreKit Sandbox sheet appears
  ↓
Tap "Subscribe" or "Buy" (no real money!)
  ↓
Confirm (no Face ID needed in simulator)
  ↓
App unlocks premium features ✅
```

### Step 5: Test Scenarios

#### ✅ Successful Purchase
- Tap purchase → Should complete instantly
- Check Debug section → Premium Status: ✅ Premium
- All AI providers should appear
- Custom prompt should be editable

#### ✅ Restore Purchase
1. Purchase the product
2. Delete the app
3. Reinstall and run
4. Tap "Restore Purchases"
5. Premium should unlock again

#### ✅ Transaction Updates
1. Purchase the product
2. Keep app running
3. StoreKit should automatically detect the entitlement
4. App should update without restart

#### ⚠️ Failure Scenarios (Advanced)
In the StoreKit configuration editor:
1. Enable "Load Products" error → Should show "Product not available"
2. Enable "Purchase" error → Should show error message
3. Enable "Verification" error → Should reject transaction

### Step 6: Debug Console Monitoring

Watch for these logs:

```
✅ Success Flow:
[PurchaseManager] Configuring with product ID: com.deepticker.aiProAccess
[PurchaseManager] ✅ Successfully loaded 1 products
[PurchaseManager]   - com.deepticker.aiProAccess: DeepSeek Pro - $4.99
[AISettingsViewModel] 🎯 App Mode: FREE (Default)
[AISettingsViewModel] 📦 Product Loaded: YES
[PurchaseManager] Transaction verified and finished
[AISettingsViewModel] 🎯 App Mode: PREMIUM

❌ Failure Flow:
[PurchaseManager] ❌ Failed to load products: <error>
[AISettingsViewModel] ⚠️ Premium product not loaded. Check product ID
[AISettingsViewModel] 🎯 App Mode: FREE (Default)
```

---

## 🏪 App Store Connect Testing (Before Release)

### Step 1: Create Product in App Store Connect

1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. Select your app
3. Go to **In-App Purchases**
4. Click **+** to create new

### Configuration:
```
Type: Non-Consumable
Reference Name: DeepSeek Pro
Product ID: com.deepticker.aiProAccess

Pricing: $4.99 (or your choice)

Display Name (English): DeepSeek Pro
Description (English): Unlock all AI providers, custom prompts, and advanced portfolio analysis features

Review Screenshot: (Upload screenshot showing the feature)
Review Notes: This unlocks premium AI features including multiple providers and customization
```

### Step 2: Create Sandbox Tester

1. In App Store Connect → **Users and Access**
2. Select **Sandbox Testers** tab
3. Click **+** to add tester
4. Fill in:
   ```
   Email: test@example.com (fake email is fine)
   Password: TestPass123!
   First Name: Test
   Last Name: User
   Country/Region: United States
   ```

### Step 3: Test on Real Device

1. **Sign out of real Apple ID** in Settings → App Store
2. Build and run on device
3. When prompted to sign in to App Store, use **sandbox tester account**
4. Complete purchase (you won't be charged)
5. Verify premium unlocks

### Important Notes:
- ⚠️ **Never use sandbox tester in production App Store**
- ⚠️ **Product must be "Ready to Submit" state** to test
- ⚠️ **Takes 2-24 hours** for new products to sync
- ✅ **Test on real device**, not simulator (for App Store Connect testing)

---

## 🔄 Testing Reset Flow

### Quick Reset for Development:

Add this button to your debug section (already in AISettingsView.swift):

```swift
#if DEBUG
Button("Reset Premium Status (Testing)") {
    viewModel.resetPremiumStatus()
}
.foregroundStyle(.red)
#endif
```

This calls:
```swift
func resetPremiumStatus() {
    isPremium = false
    UserDefaults.standard.set(false, forKey: Self.premiumKey)
    applyEntitlementGating()
}
```

### Full App Reset:
1. Delete app from device/simulator
2. Clean build folder: Product → Clean Build Folder (⌘+Shift+K)
3. Build and run again
4. App starts fresh as free user

---

## ✅ Testing Checklist

### Before Every Release:

- [ ] Load products successfully
- [ ] Display correct price
- [ ] Complete purchase flow
- [ ] Verify transaction
- [ ] Unlock all premium features
- [ ] Restore purchases works
- [ ] Reject invalid transactions
- [ ] Handle network errors gracefully
- [ ] Handle user cancellation
- [ ] Test on multiple devices (iPhone, iPad)
- [ ] Test on different iOS versions
- [ ] Test with real App Store (not just StoreKit)

### Edge Cases:

- [ ] Purchase while offline → Should fail gracefully
- [ ] Purchase during app background → Should complete on foreground
- [ ] Multiple rapid purchase taps → Should handle duplicate attempts
- [ ] App deleted and reinstalled → Restore should work
- [ ] New device login → Restore should work

---

## 🐛 Common Issues & Solutions

### Issue: "Product not available"
**Solutions:**
- Check product ID matches exactly: `com.deepticker.aiProAccess`
- Wait 24 hours after creating product in App Store Connect
- Verify internet connection
- Check StoreKit configuration file is selected in scheme

### Issue: Purchase completes but doesn't unlock
**Solutions:**
- Check `refreshEntitlements()` is called
- Verify product ID matches in verification
- Check for transaction verification errors in console
- Ensure `isPurchased` syncs to `isPremium`

### Issue: Restore doesn't work
**Solutions:**
- Non-consumables should appear in `Transaction.currentEntitlements`
- Check you're iterating through all current entitlements
- Verify transaction is finished: `await transaction.finish()`

### Issue: Sandbox account issues
**Solutions:**
- Sign out completely from Settings → App Store
- Delete app and reinstall
- Create new sandbox tester account
- Wait 15 minutes after creating sandbox account

---

## 📊 Testing Report Template

Use this when submitting for review:

```
IAP Testing Report - DeepSeek Pro
Date: [Today's Date]

Product Details:
- Product ID: com.deepticker.aiProAccess
- Type: Non-Consumable
- Price: $4.99
- Features: All AI providers, custom prompts, advanced analysis

Testing Completed:
✅ Product loads successfully
✅ Price displays correctly
✅ Purchase flow completes
✅ Transaction verifies successfully
✅ Premium features unlock
✅ Restore purchases works
✅ Handles cancellation gracefully
✅ Handles errors appropriately
✅ Tested on iPhone (iOS XX.X)
✅ Tested on iPad (iOS XX.X)

Known Issues: None

Sandbox Tester Account: test@example.com

Notes:
Free version includes DeepSeek AI with preset prompts.
Premium unlocks 4 additional AI providers and customization.
```

---

**Your IAP is now fully testable!** 🎉

Next: Customization and Analytics...
