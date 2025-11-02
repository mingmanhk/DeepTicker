# DeepTicker 📈

A privacy-focused, AI-powered iOS investment portfolio tracker that helps you monitor your stock investments and get intelligent market insights.

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

### Installation

1. **Clone the Repository**
   ```bash
   git clone https://github.com/yourusername/DeepTicker.git
   cd DeepTicker
   ```

2. **Open in Xcode**
   ```bash
   open DeepTicker.xcodeproj
   ```

3. **Configure API Keys** (Optional for Development)
   - Create a `Secrets.plist` file in the project root
   - Add your API keys using these exact key names:
     ```xml
     <?xml version="1.0" encoding="UTF-8"?>
     <plist version="1.0">
     <dict>
         <key>DeepSeekAPIKey</key>
         <string>your_deepseek_key_here</string>
         <key>AlphaVantageAPIKey</key>
         <string>your_alpha_vantage_key_here</string>
         <!-- Add other keys as needed -->
     </dict>
     </plist>
     ```

4. **Build and Run**
   - Select your target device or simulator
   - Press `⌘+R` to build and run

## 🏗️ Project Structure

```
DeepTicker/
├── Core/
│   ├── SecureConfigurationManager.swift    # API key management
│   ├── UnifiedPortfolioManager.swift       # Portfolio data management
│   └── DataRefreshManager.swift            # Data synchronization
├── Services/
│   ├── AlphaVantageService.swift          # Market data API
│   ├── StockPriceService.swift            # Price fetching
│   └── AIMarketSignalFramework.swift      # AI integration
├── Views/
│   ├── ModernMyInvestmentTab.swift        # Main portfolio view
│   ├── AddStockView.swift                 # Stock addition interface
│   ├── ComprehensiveSettingsView.swift    # Settings and configuration
│   └── EnhancedAIInsightsTab.swift        # AI analysis interface
├── Extensions/
│   └── LiquidGlassExtensions.swift        # Modern UI effects
└── Resources/
    ├── privacy-policy.html                # Privacy policy
    └── API_KEYS_README.md                 # API setup guide
```

## 🔧 Configuration

### API Key Priority
The app loads API keys in this order:
1. **Keychain** (user-entered keys in settings) - *Highest Priority*
2. **Environment Variables** (for development)
3. **Secrets.plist** (default/fallback keys) - *Lowest Priority*

### Prompt Templates
Customize AI analysis prompts for different use cases:
- **Profit Confidence**: Analyze investment confidence levels
- **Risk Assessment**: Evaluate portfolio risk factors
- **Movement Prediction**: Predict stock price movements with JSON output
- **Portfolio Overview**: Comprehensive portfolio health analysis

### Data Sources
Primary data sources (configurable in settings):
- **Yahoo Finance**: Primary stock price data
- **Alpha Vantage**: Backup and additional market data
- **RapidAPI**: Extended market information

## 🤖 AI Integration

### Supported Providers
| Provider | Features | Best For |
|----------|----------|----------|
| **DeepSeek** | Fast, cost-effective | Daily analysis |
| **OpenAI** | Advanced reasoning | Complex analysis |
| **Qwen** | Multilingual support | Global markets |
| **OpenRouter** | Multiple models | Flexibility |

### Analysis Types
- **Risk Assessment**: Portfolio diversification and risk factors
- **Profit Predictions**: Movement direction and confidence levels
- **Market Insights**: Current trends and recommendations
- **Portfolio Health**: Overall investment strategy evaluation

## 📱 Usage

### Adding Stocks
1. Tap the "Add" button in the portfolio view
2. Search for stocks by symbol or company name
3. Enter the number of shares and purchase price
4. The app will automatically fetch current market data

### Getting AI Insights
1. Navigate to the "AI Insights" tab
2. Select your preferred AI provider
3. Choose the type of analysis you want
4. Review the generated insights and recommendations

### Managing Settings
1. Open the Settings tab
2. Configure API keys securely
3. Customize AI prompt templates
4. Adjust app preferences and data sources

## 🔒 Privacy & Security

DeepTicker is built with privacy as a core principle:

- **Local Data Storage**: All portfolio information stays on your device
- **Secure API Keys**: Stored in iOS Keychain with hardware-level security
- **No Personal Data Collection**: We never collect identifying information
- **Transparent Third-Party Usage**: Clear documentation of external services
- **User Control**: Full control over data sharing and AI provider selection

For complete details, see our [Privacy Policy](privacy-policy.html).

## 🛠️ Development

### Key Components

#### SecureConfigurationManager
Handles secure storage and management of API keys with keychain integration.

#### UnifiedPortfolioManager
Manages portfolio data with local persistence and real-time updates.

#### AI Integration Framework
Modular system supporting multiple AI providers with customizable prompts.

### Building for Release

1. **Configure Release Settings**
   - Update version and build numbers
   - Set release configuration
   - Configure code signing

2. **API Key Management**
   - Ensure no development keys in release build
   - Users must configure their own API keys

3. **Testing**
   - Test with various API key configurations
   - Verify offline functionality
   - Test privacy compliance

## 🤝 Contributing

We welcome contributions to DeepTicker! Here's how you can help:

### Reporting Issues
- Use the in-app feedback system (Settings → Support & Feedback)
- Email [victor.lam@pinkkamii.com](mailto:victor.lam@pinkkamii.com)
- Include app version, iOS version, and reproduction steps

### Feature Requests
- Submit via the app's feedback system
- Describe the feature and its benefits
- Consider privacy implications

### Development Contributions
- Fork the repository
- Create a feature branch
- Follow Swift and iOS development best practices
- Submit a pull request with clear description

## 📄 License

This project is proprietary software. All rights reserved.

For licensing inquiries, contact [victor.lam@pinkkamii.com](mailto:victor.lam@pinkkamii.com).

## 📞 Support

### Getting Help
- **In-App Feedback**: Settings → Support & Feedback
- **Email**: [victor.lam@pinkkamii.com](mailto:victor.lam@pinkkamii.com)
- **Response Time**: Within 48 hours for most inquiries

### Common Issues
- **API Key Problems**: Check the API Keys README for setup instructions
- **Data Not Updating**: Verify internet connection and API key validity
- **AI Analysis Errors**: Ensure selected AI provider API key is configured

## 🚀 Roadmap

### Upcoming Features
- **Apple Watch Support**: Portfolio monitoring on your wrist
- **Widget Extensions**: Home screen portfolio widgets
- **Advanced Charts**: Interactive price charts and technical indicators
- **Automated Alerts**: Price and portfolio performance notifications
- **Export Functionality**: Portfolio data export capabilities

### Long-term Goals
- **Multi-Currency Support**: International portfolio tracking
- **Social Features**: Community insights and sharing
- **Advanced AI**: Predictive modeling and trend analysis
- **Apple Intelligence Integration**: Native iOS AI features

## 🎯 Vision

DeepTicker aims to democratize intelligent investment analysis while maintaining the highest standards of privacy and user control. We believe everyone should have access to sophisticated financial tools without sacrificing their personal data.

---

**Built with ❤️ in Swift for iOS**

*Last Updated: October 31, 2025*