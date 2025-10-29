import Foundation

// MARK: - API Key Usage Examples
/// This file demonstrates how to securely access API keys in your app

// MARK: - Example Service Using Secure API Keys
class ExampleAPIService {
    private let settingsManager = SettingsManager.shared
    private let aiSettings = AISettings.shared
    
    // MARK: - Secure API Key Access
    
    /// Example: Making a request with Alpha Vantage API
    func fetchStockData(symbol: String) async throws {
        let apiKey = settingsManager.alphaVantageAPIKey
        
        guard !apiKey.isEmpty else {
            throw ExampleAPIError.missingAPIKey("Alpha Vantage API key is required")
        }
        
        let urlString = "https://www.alphavantage.co/query?function=GLOBAL_QUOTE&symbol=\(symbol)&apikey=\(apiKey)"
        
        // Use the API key in your request...
        print("Making request with secured API key to: \(urlString)")
    }
    
    /// Example: Making a request with selected AI provider
    func getAIAnalysis(for symbol: String) async throws {
        let selectedSource = aiSettings.selectedSource
        let apiKey: String
        
        switch selectedSource {
        case .deepseek:
            apiKey = settingsManager.deepSeekAPIKey
        case .openAI:
            apiKey = settingsManager.openAIAPIKey
        case .qwen:
            apiKey = settingsManager.qwenAPIKey
        }
        
        guard !apiKey.isEmpty else {
            throw ExampleAPIError.missingAPIKey("\(selectedSource.rawValue) API key is required")
        }
        
        // Use the selected provider's API key...
        print("Using \(selectedSource.rawValue) for AI analysis with secured key")
    }
}

// MARK: - Error Types
enum ExampleAPIError: Error, LocalizedError {
    case missingAPIKey(String)
    case invalidResponse
    case networkError(String)
    
    var errorDescription: String? {
        switch self {
        case .missingAPIKey(let message):
            return message
        case .invalidResponse:
            return "Invalid API response"
        case .networkError(let message):
            return "Network error: \(message)"
        }
    }
}

// MARK: - Configuration Validation
extension ConfigurationManager {
    /// Validate that required API keys are available
    /// - Returns: Array of missing required keys
    func validateRequiredKeys() -> [ConfigurationKey] {
        var missingKeys: [ConfigurationKey] = []
        
        for key in ConfigurationKey.allCases where key.isRequired {
            let value = getAPIKey(for: key)
            if value.isEmpty {
                missingKeys.append(key)
            }
        }
        
        return missingKeys
    }
    
    /// Check if the configuration is valid for basic app functionality
    /// - Returns: True if required keys are present
    func isConfigurationValid() -> Bool {
        return validateRequiredKeys().isEmpty
    }
}

// MARK: - Settings Manager Extensions
extension SettingsManager {
    /// Get the current API key for the selected AI data source
    var currentAIAPIKey: String {
        let aiSettings = AISettings.shared
        switch aiSettings.selectedSource {
        case .deepseek:
            return deepSeekAPIKey
        case .openAI:
            return openAIAPIKey
        case .qwen:
            return qwenAPIKey
        }
    }
    
    /// Check if the current AI provider has a valid API key
    var hasValidAIProvider: Bool {
        return !currentAIAPIKey.isEmpty
    }
    
    /// Get available AI providers (those with API keys configured)
    var availableAIProviders: [AISource] {
        var providers: [AISource] = []
        
        if !deepSeekAPIKey.isEmpty { providers.append(.deepseek) }
        if !openAIAPIKey.isEmpty { providers.append(.openAI) }
        if !qwenAPIKey.isEmpty { providers.append(.qwen) }
        // Note: OpenRouter is not available in the AISource enum
        
        return providers
    }
}

// MARK: - Development Helpers
#if DEBUG
extension SettingsManager {
    /// Reset all API keys (for development/testing)
    func resetAllAPIKeys() {
        alphaVantageAPIKey = ""
        deepSeekAPIKey = ""
        openAIAPIKey = ""
        qwenAPIKey = ""
        openRouterAPIKey = ""
    }
    
    /// Load default keys from Config.plist (for development)
    func loadDefaultKeys() {
        let config = ConfigurationManager.shared
        
        alphaVantageAPIKey = config.getAPIKey(for: .alphaVantageAPI)
        deepSeekAPIKey = config.getAPIKey(for: .deepSeekAPI)
        openAIAPIKey = config.getAPIKey(for: .openAIAPI)
        qwenAPIKey = config.getAPIKey(for: .qwenAPI)
        openRouterAPIKey = config.getAPIKey(for: .openRouterAPI)
    }
    
    /// Get configuration summary for debugging
    func getConfigurationSummary() -> [String: String] {
        let aiSettings = AISettings.shared
        return [
            "Alpha Vantage": alphaVantageAPIKey.isEmpty ? "❌ Missing" : "✅ Configured",
            "DeepSeek": deepSeekAPIKey.isEmpty ? "❌ Missing" : "✅ Configured",
            "OpenAI": openAIAPIKey.isEmpty ? "❌ Missing" : "✅ Configured",
            "Qwen": qwenAPIKey.isEmpty ? "❌ Missing" : "✅ Configured",
            "OpenRouter": openRouterAPIKey.isEmpty ? "❌ Missing" : "✅ Configured",
            "Selected AI": aiSettings.selectedSource.rawValue,
            "Config File": ConfigurationManager.shared.hasConfigurationFile() ? "✅ Found" : "❌ Missing"
        ]
    }
}
#endif
