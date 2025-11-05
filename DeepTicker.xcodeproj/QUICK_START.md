# 🚀 Quick Start - Get Purchase Button Working

## 1️⃣ Configure Xcode (ONE TIME)
```
Product → Scheme → Edit Scheme → Run → Options
Set "StoreKit Configuration" to: Configuration.storekit
```

## 2️⃣ Clean & Build
```
⇧⌘K  (Clean)
⌘B   (Build)
⌘R   (Run)
```

## 3️⃣ Find Purchase Button
```
Open App → Settings → AI Settings
Scroll down to "DeepSeek Pro" section
```

## ✅ You Should See:
- 👑 "Upgrade to DeepSeek Pro" button
- 🛒 "Quick Purchase" button
- 🔄 "Restore Purchases" button
- Feature list explaining what unlocks

## ❌ If Button Doesn't Show:

### Check Console for:
```
[PurchaseManager] ✅ Successfully loaded 1 products
```

### If you see error instead:
1. Restart Xcode
2. Delete app from simulator
3. Clean Build Folder (⇧⌘K)
4. Rebuild (⌘B)
5. Run (⌘R)

### If already marked as Pro:
```
Settings → Developer Tools → IAP Debug Tool → Reset Premium Status
```

---

## 🧪 Test Purchase Flow

1. Tap "Upgrade to DeepSeek Pro"
2. See beautiful purchase screen with features
3. Complete test purchase in simulator
4. ✅ All AI models unlock
5. ✅ Custom prompts become editable
6. ✅ Upgrade section disappears

---

## 🆘 Emergency Debug

### Open IAP Debug Tool:
```
Settings → Developer Tools → IAP Debug Tool
```

This shows:
- Purchase status
- Product information
- Current entitlements
- Buttons to reload/reset

### Console Command to Reset:
```swift
expr UserDefaults.standard.set(false, forKey: "PremiumUnlocked")
```

---

## 📋 Product Information

- **ID**: `com.deepticker.aiProAccess`
- **Name**: DeepSeek Pro
- **Price**: $4.99
- **Type**: Non-Consumable (one-time purchase)

---

## ✨ What Gets Unlocked

**Free (Default):**
- Built-in DeepSeek model only
- Preset prompts

**Pro (After Purchase):**
- ✅ OpenAI, Qwen, Anthropic, Google, Azure
- ✅ Use your own API keys
- ✅ Custom AI prompts
- ✅ Compare multiple AI models

---

**Need more help?** Check `DEEPSECK_PRO_SETUP.md` for detailed guide.
