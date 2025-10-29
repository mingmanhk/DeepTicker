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

---

## For Developers: Providing Default Keys

As a developer, you can pre-populate the app with default API keys using a `Config.plist` file. This is useful for testing and development.

**Note:** Keys provided in `Config.plist` act as *defaults*. If a user enters their own key in the app, the user's key will always be used.

### Setup Instructions

1.  **Create the File**: In the project's root directory, copy the template file.
    ```bash
    cp Config.plist.template Config.plist
