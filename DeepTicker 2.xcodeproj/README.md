# DeepTicker 📈

**Predictive Stock Portfolio Tracker with Mascot-Driven Alerts and Alpha Vantage Integration**

DeepTicker is a playful yet powerful iOS app that helps users manage their stock portfolios, view real-time prices, and receive predictive alerts using DeepSeek AI. It features a unique mascot-driven interface that visualizes stock health with animated cues and color-coded warnings.

## Features 🎯

### Core Functionality
- **Portfolio Management**: Add/remove stocks manually with real-time price tracking
- **AI-Powered Predictions**: DeepSeek AI predicts daily stock movements with confidence ratings
- **Health Status Visualization**: Color-coded health indicators (🟢 Green = Stable, 🟠 Orange = Warning, 🔴 Red = Danger)
- **Custom Alerts**: Configurable notifications based on price changes and AI predictions
- **Real-time Data**: Alpha Vantage API integration for accurate stock prices

### Unique Features
- **Animated Mascot**: Zigzag-shaped character that responds to portfolio health
- **Predictive Engine**: AI-powered daily movement predictions with reasoning
- **Widget Support**: iOS widgets for quick portfolio glances
- **Dark Mode**: Full dark mode support with color-safe indicators

## Technical Architecture 🏗️

### API Integration
- **Alpha Vantage API**: Real-time stock quotes and historical data
- **DeepSeek AI API**: Stock predictions and portfolio analysis
- **Rate Limiting**: Built-in API rate limiting and caching

### Data Models
- **Stock**: Core model with price, shares, and health status
- **StockPrediction**: AI predictions with confidence and reasoning
- **PortfolioStats**: Aggregated portfolio health and performance
- **AlertConfig**: Customizable notification preferences

### Architecture Pattern
- **MVVM**: SwiftUI with ObservableObject managers
- **Async/Await**: Modern Swift concurrency throughout
- **UserDefaults**: Persistent data storage
- **Combine**: Reactive UI updates

## Project Structure 📁

```
DeepTicker/
├── DeepTickerApp.swift          # Main app entry point
├── ContentView.swift            # Root tab view
├── Models.swift                 # Core data models
├── Managers/
│   ├── PortfolioManager.swift   # Portfolio logic and data
│   ├── AlphaVantageManager.swift # Stock API integration
│   └── DeepSeekManager.swift    # AI predictions
├── Views/
│   ├── PortfolioView.swift      # Stock list and summary
│   ├── PredictionsView.swift    # AI predictions display
│   ├── MascotView.swift         # Animated mascot interface
│   └── SettingsView.swift       # Configuration panel
├── Widgets/
│   └── PortfolioWidget.swift    # Home screen widgets
└── Tests/
    └── DeepTickerTests.swift    # Swift Testing suite
```

## API Configuration 🔑

The app comes pre-configured with API keys:

- **Alpha Vantage API Key**: `E1ROYME4HFCB3C94`
- **DeepSeek AI API Key**: `sk-79819a28af4c4d3f8d79253b7a96bf22`

### API Limits
- **Alpha Vantage**: 5 requests/minute, 500/day (free tier)
- **DeepSeek**: Rate limiting handled automatically

## Getting Started 🚀

### Prerequisites
- iOS 17.0+ or iPadOS 17.0+
- Xcode 15.0+
- Swift 5.9+

### Installation
1. Clone or download the project files
2. Open the project in Xcode
3. Build and run on device or simulator
4. Add your first stock symbol (e.g., AAPL) to start tracking

### First Use
1. **Add Stocks**: Tap the '+' button to add stocks by symbol
2. **Set Shares**: Optionally specify number of shares owned
3. **Configure Alerts**: Adjust notification preferences in Settings
4. **Generate Predictions**: Tap the brain icon to get AI predictions
5. **Meet Your Mascot**: Check the mascot tab to see portfolio health visualization

## Usage Guide 📱

### Adding Stocks
1. Navigate to Portfolio tab
2. Tap '+' button in top-right corner
3. Enter stock symbol (e.g., AAPL, MSFT, GOOGL)
4. Optionally enter number of shares
5. Tap "Add Stock"

### Understanding Health Status
- **🟢 Healthy**: Stock is stable or gaining (< 2% change)
- **🟠 Warning**: Stock showing concerning movement (2-10% change)
- **🔴 Danger**: Stock in significant decline (> 10% predicted drop)

### AI Predictions
- **Direction**: Up, Down, or Neutral movement prediction
- **Confidence**: AI confidence level (50-100%)
- **Reasoning**: Brief analysis of prediction factors
- **Predicted Change**: Expected percentage movement

### Alerts Configuration
- **Global Toggle**: Enable/disable all notifications
- **Change Threshold**: Minimum % change to trigger alert (1-20%)
- **Confidence Threshold**: Minimum AI confidence for prediction alerts (50-100%)
- **Per-Stock Settings**: Individual alert controls for each stock

## Widget Setup 🏠

1. Long press on iOS home screen
2. Tap '+' in top-left corner
3. Search for "DeepTicker"
4. Choose widget size (Small, Medium, Large)
5. Add to home screen

### Widget Features
- **Small**: Portfolio value and daily change
- **Medium**: Value, change, and health indicators
- **Large**: Full portfolio overview with mascot

## Testing 🧪

The project includes comprehensive tests using Swift Testing framework:

```bash
# Run tests in Xcode
Product > Test (⌘+U)
```

### Test Coverage
- Model validation and calculations
- Health status logic
- Portfolio statistics
- API response parsing
- Date formatting utilities

## Troubleshooting 🔧

### Common Issues

**"No data loading"**
- Check network connection
- Verify API keys in Settings > API Configuration
- Try "Test API Connections" in Settings

**"Stock not found"**
- Ensure correct stock symbol format (e.g., AAPL not Apple)
- Try major stocks first (AAPL, MSFT, GOOGL)
- Check symbol exists on US exchanges

**"Predictions not generating"**
- Ensure stocks are added to portfolio
- Check network connectivity
- AI predictions require historical data (may take a moment)

**"Notifications not working"**
- Allow notifications in iOS Settings > DeepTicker
- Check alert configuration in app Settings
- Ensure alerts are enabled globally and per-stock

### Performance Tips
- Update frequency affects battery and API usage
- Use 30+ minute intervals for better battery life
- Cache helps with offline viewing of recent data

## Future Enhancements 🔮

### Planned Features
- [ ] Historical prediction accuracy tracking
- [ ] Additional chart types and timeframes  
- [ ] Social features for sharing predictions
- [ ] Apple Watch companion app
- [ ] Advanced portfolio analytics
- [ ] Options and crypto support
- [ ] News integration
- [ ] Advanced mascot animations

### Technical Improvements
- [ ] Core Data migration for larger datasets
- [ ] CloudKit sync across devices
- [ ] Advanced caching strategies
- [ ] Background refresh optimization
- [ ] Accessibility improvements
- [ ] Localization support

## Contributing 🤝

This is a demonstration project showcasing modern iOS development with AI integration. Feel free to:

- Report issues or bugs
- Suggest feature improvements
- Contribute code enhancements
- Share feedback on UX/UI

## Privacy & Security 🔒

- **API Keys**: Securely stored in app configuration
- **User Data**: Stored locally on device using UserDefaults
- **No Tracking**: App doesn't collect personal information
- **Network Only**: API calls for stock data and predictions only

## License 📄

This project is created for educational and demonstration purposes.

## Acknowledgments 🙏

- **Alpha Vantage** for providing reliable stock market data
- **DeepSeek** for AI-powered predictions
- **Apple** for SwiftUI and iOS development frameworks

---

**Built with ❤️ using SwiftUI, Swift Concurrency, and AI**

*DeepTicker - Where AI meets your investment portfolio* 📱📈🤖