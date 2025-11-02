# DeepTicker - API Key Configuration

Welcome to DeepTicker! To power its smart features like real-time stock data and AI-driven insights, the app needs API keys for various services. This guide explains how to set them up.

## How to Add Your API Keys

You can add your API keys directly within the app. They will be stored securely in your device's Keychain.

1.  Open the **DeepTicker** app.
2.  Navigate to the **Settings** tab.
3.  Tap on the **Accounts & APIs** tab at the top.
4.  Enter your API key into the corresponding field for each service.
5.  The app will save the keys automatically and securely.

---

## API Services

Here is a list of the services DeepTicker uses. You can get a free API key for each by following the links below.

### Required Keys

These keys are necessary for the app's core functionality.

-   **Alpha Vantage**
    -   **Purpose**: Provides real-time and historical stock market data.
    -   **Get Your Key**: [Alpha Vantage Support Page](https://www.alphavantage.co/support/#api-key)

-   **DeepSeek**
    -   **Purpose**: The default provider for AI-powered stock predictions and analysis.
    -   **Get Your Key**: [DeepSeek Platform](https://platform.deepseek.com/api_keys)

### Optional Keys

These keys enable alternative AI providers and additional features.

-   **OpenAI**
    -   **Purpose**: Use OpenAI's models (like GPT) for AI analysis.
    -   **Get Your Key**: [OpenAI API Keys](https://platform.openai.com/api-keys)

-   **Qwen (Alibaba Cloud)**
    -   **Purpose**: Use Alibaba's Qwen model for AI analysis.
    -   **Get Your Key**: [Qwen API Management](https://modelstudio.console.alibabacloud.com/?tab=playground#/api-key)

-   **OpenRouter**
    -   **Purpose**: Access a wide variety of AI models through a single service.
    -   **Get Your Key**: [OpenRouter Keys](https://openrouter.ai/settings/keys)

-   **RapidAPI**
    -   **Purpose**: Additional stock data provider and search capabilities.
    -   **Get Your Key**: [RapidAPI Hub](https://rapidapi.com/hub)

---

## For Developers: Providing Default Keys

As a developer, you can pre-populate the app with default API keys using a `Secrets.plist` file. This is the **ONLY** configuration file used by the app.

**Note:** Keys provided in `Secrets.plist` act as *defaults*. If a user enters their own key in the app, the user's key will always be used.

### Setup Instructions

1.  **Create the File**: In the project's root directory, copy the template file.
    ```bash
    cp Secrets.plist.template Secrets.plist
    ```

2.  **Edit the File**: Open `Secrets.plist` and replace the placeholder values with your actual API keys:
    ```xml
    <key>DEEPSEEK_API_KEY</key>
    <string>sk-your-actual-deepseek-key</string>
    
    <key>ALPHA_VANTAGE_API_KEY</key>
    <string>your-actual-alpha-vantage-key</string>
    
    <!-- Add other keys as needed -->
    ```

3.  **Important**: Add `Secrets.plist` to your `.gitignore` file to avoid committing real API keys to version control.

### Configuration Consolidation

All configuration has been consolidated into `Secrets.plist`:
- ✅ Single source of truth for all API keys
- ✅ Secure keychain storage for user modifications  
- ✅ No more multiple config files (Config.plist, etc.)
- ✅ Simplified setup and maintenance

The app automatically:
1. Reads default keys from `Secrets.plist`
2. Stores them securely in keychain
3. Allows users to override with their own keys
4. Maintains security and simplicity
