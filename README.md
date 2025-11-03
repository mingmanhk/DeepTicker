# DeepTicker 📈

A privacy-focused, AI-powered iOS investment portfolio tracker that helps you monitor your stock investments and get intelligent market insights.

## 📸 Screenshots

### My Investment
![Screenshot - My Investment](Screenshots/Screenshot%20-%20My%20Investment.png)

Track holdings, returns, and daily movement.

### AI Insights
![Screenshot - AI Insights](Screenshots/Screenshot%20-%20AI%20Insights.png)

Provider-selected portfolio summary and stock-level insights.

### Settings
![Screenshot - Settings](Screenshots/Screenshot%20-%20Settings.png)

Configure API keys, prompts, and data sources.

## 🌟 Features

### Portfolio Management
- **Track Your Investments**: Add stocks with purchase price, quantity, and date
- **Real-Time Updates**: Live stock prices and market data
- **Performance Analytics**: Daily gains/losses, total returns, and portfolio health
- **Smart Caching**: Efficient data management for optimal performance

### AI-Powered Insights
- **Multiple AI Providers**: Choose from DeepSeek, OpenAI, Qwen, or OpenRouter
- **Custom Prompts**: Personalize AI analysis with custom prompt templates
- **Market Analysis**: 
  - Profit confidence predictions
  - Risk assessments
  - Movement predictions with JSON formatting
  - Comprehensive portfolio overviews

### Privacy & Security
- **Local-First**: All portfolio data stored securely on your device
- **Keychain Security**: API keys protected with iOS Keychain
- **No Tracking**: Zero collection of personal data
- **Full Control**: Complete ownership of your financial information

### Modern iOS Experience
- **SwiftUI Interface**: Native iOS design with smooth animations
- **Liquid Glass Effects**: Modern, translucent design elements
- **Dark/Light Mode**: Automatic theme adaptation
- **Accessibility**: VoiceOver and accessibility feature support

## 🚀 Getting Started

### Prerequisites
- iOS 16.0 or later
- Xcode 15.0 or later (for development)
- Swift 5.9 or later

### Quick Start
1. Clone the repo and open in Xcode
2. Add your DeepSeek API key in-app (Settings → API Keys) or in Secrets.plist
3. Add at least one stock in My Investment
4. Open AI Insights — DeepSeek auto-selects if the key is valid
5. Tap Refresh to fetch the latest analysis

### API Keys Setup
DeepTicker requires API keys from third-party services. You can configure these in the app settings or via configuration files:

#### Required Keys
- **Alpha Vantage**: Stock market data ([Get Your Key](https://www.alphavantage.co/support/#api-key))
- **DeepSeek**: Primary AI analysis provider ([Get Your Key](https://platform.deepseek.com/api_keys))

#### Optional Keys
- **OpenAI**: Alternative AI provider ([Get Your Key](https://platform.openai.com/api-keys))
- **Qwen**: Alibaba's AI model ([Get Your Key](https://modelstudio.console.alibabacloud.com/#/api-key))
- **OpenRouter**: Multi-model AI access ([Get Your Key](https://openrouter.ai/settings/keys))
- **RapidAPI**: Additional market data ([Get Your Key](https://rapidapi.com/hub))

You can also set keys as environment variables for development (Product → Scheme → Edit Scheme… → Arguments → Environment Variables).

## 🤖 AI Integration

### Supported Providers

| Provider   | Description                        |
|------------|----------------------------------|
| DeepSeek   | Primary AI with deep portfolio insights |
| OpenAI     | Alternative AI for analysis       |
| Qwen       | Alibaba's AI model                |
| OpenRouter | Multi-model AI gateway            |

Default selection: If a valid DeepSeek key is present, DeepSeek is auto-selected. If no provider is available or selected, the AI Insights tab shows neutral empty states until you choose a provider.

## 📱 Usage

### Getting AI Insights
1. Ensure at least one provider API key is configured (DeepSeek recommended)
2. Open AI Insights — DeepSeek auto-selects if the key is valid
3. Tap Refresh to force a fresh fetch as needed

## 🧰 Troubleshooting
- AI Insights shows no data: Ensure a provider key is configured. DeepSeek auto-selects if valid; otherwise select a provider manually, verify network, and tap Refresh.
- Provider selected but insights not updating: Tap Refresh; check API key validity and any rate limits.
- Prices not updating: Verify your Alpha Vantage key and data source selections in Settings.

## 🔒 Privacy & Security
- **Local-First**: All portfolio data stored securely on your device
- **Keychain Security**: API keys protected with iOS Keychain
- **No Server Uploads**: Portfolio data and positions are never transmitted to our servers. Only essential requests are sent to third-party APIs for market data and AI analysis.
- **No Tracking**: Zero collection of personal data
- **Full Control**: Complete ownership of your financial information

*Last Updated: November 3, 2025*
