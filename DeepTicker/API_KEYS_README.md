# DeepTicker - API Key Configuration

This document explains how to configure API keys for the DeepTicker investment tracking app using Config.plist.

## New Configuration Method

⚠️ **Important Change**: API keys are now configured via `Config.plist` file and are **read-only** in the app interface. Manual key entry through Settings has been removed for security.

## Security Features

- **File-Based Configuration**: API keys are loaded from Config.plist at app launch
- **Git Safety**: Config.plist is automatically ignored by Git
- **No Runtime Storage**: Keys are not saved to UserDefaults or Keychain by the app
- **Read-Only Interface**: Settings shows key status but doesn't allow editing

## Setup Instructions

### 1. Create Configuration File

1. **Use the provided template**:
   ```bash
   cp Config.plist.template Config.plist
   ```

2. **Edit Config.plist** with your actual API keys:
   - Open `Config.plist` in Xcode or any text editor
   - Replace empty string values with your real API keys
   - Save the file
   - **Add Config.plist to your .gitignore to prevent committing keys**

3. **Add to Xcode project**:
   - Drag Config.plist into your Xcode project
   - Ensure it's added to the app target
   - Verify the file appears in your app bundle

### 2. Required API Keys

#### **Alpha Vantage** (Required)
- **Purpose**: Stock market data access
- **Get Key**: [Alpha Vantage API Key](https://www.alphavantage.co/support/#api-key)
- **Free Tier**: 5 API requests per minute and 500 requests per day

#### **DeepSeek** (Required)
- **Purpose**: AI-powered stock predictions (default provider)
- **Get Key**: [DeepSeek Platform](https://platform.deepseek.com/api_keys)
- **Note**: Primary AI provider for predictions

### 3. Optional API Keys

#### **OpenAI** (Optional)
- **Purpose**: Alternative AI insights provider
- **Get Key**: [OpenAI API Keys](https://platform.openai.com/api-keys)
- **Note**: Enable GPT-powered analysis

#### **Qwen** (Optional)
- **Purpose**: Alternative AI insights provider
- **Get Key**: [Qwen API Management](https://help.aliyun.com/zh/dashscope/developer-reference/api-key-management)
- **Note**: Alibaba's AI model for analysis

#### **OpenRouter** (Optional)
- **Purpose**: Access to multiple AI models
- **Get Key**: [OpenRouter Keys](https://openrouter.ai/keys)
- **Note**: Gateway to various AI models

## Configuration File Structure

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>ALPHA_VANTAGE_API_KEY</key>
    <string>your-alpha-vantage-key-here</string>
    <key>DEEPSEEK_API_KEY</key>
    <string>your-deepseek-key-here</string>
    <key>OPENAI_API_KEY</key>
    <string>your-openai-key-here</string>
    <key>QWEN_API_KEY</key>
    <string>your-qwen-key-here</string>
    <key>OPENROUTER_API_KEY</key>
    <string>your-openrouter-key-here</string>
</dict>
</plist>
```

**Note**: Leave string values empty (`<string></string>`) for optional keys you don't want to use.

## Security Best Practices

### 1. File Security
- `Config.plist` contains actual API keys and should be Git-ignored
- Never commit `Config.plist` to version control
- Use `Config.plist.template` (empty keys) for sharing configuration structure
- Add `Config.plist` to your `.gitignore` file

### 2. Key Access
- Keys are loaded once at app startup from Config.plist
- If Config.plist is missing, all keys will be blank/empty
- Keys are read-only through the Settings interface
- To change keys, edit Config.plist directly and restart the app

### 3. Development Workflow
```bash
# Safe files to commit
git add Config.plist.template
git add .gitignore

# Files that should NEVER be committed
echo "Config.plist" >> .gitignore
# Any file containing actual API keys
```

## App Configuration Status

### 1. Settings Interface (Read-Only)
- Open the app and go to **Settings**
- Navigate to **Data & API Keys**
- View **API Keys** section to see configuration status
- Green checkmark: Key is configured in Config.plist
- Orange warning: Key is missing or empty in Config.plist

### 2. AI Features
- AI Predictions are **always enabled** (toggle removed)
- All configured AI providers are available automatically
- Primary provider preference determined by which keys are available

### 3. Configuration Validation
- The Settings interface shows whether Config.plist was found
- Individual key status (Configured/Missing) is displayed
- No actual key values are shown for security

## Troubleshooting

### Config.plist Not Found
1. Verify `Config.plist` exists in the project root
2. Check that the file is added to the Xcode project target
3. Ensure the file is included in the app bundle
4. Restart the app after adding the file

### Keys Not Loading
1. Verify the XML structure matches the template exactly
2. Check for typos in the key names (case-sensitive)
3. Ensure string tags are properly closed
4. Restart the app after making changes

### Keys Not Working
1. Verify keys are correctly formatted and active
2. Test keys with the respective API providers directly
3. Check that required keys (Alpha Vantage, DeepSeek) are configured

## Files Overview

- `Config.plist` - Your actual API keys (Git ignored, create from template)
- `Config.plist.template` - Template with empty keys (Git tracked)
- `.gitignore` - Should include Config.plist to protect keys
- `ConfigurationManager.swift` - Handles loading configuration from plist
- `SettingsManager.swift` - Manages key access (now read-only)
- `SettingsView.swift` - User interface showing key status (read-only)

## Support

If you encounter issues with API key configuration:
1. Check the configuration status in Settings > Data & API Keys
2. Verify Config.plist exists and is properly formatted
3. Ensure required keys (Alpha Vantage, DeepSeek) are configured with valid values
4. Review the troubleshooting section above
5. Remember to restart the app after changing Config.plist