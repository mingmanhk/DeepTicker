import Foundation

// MARK: - Configuration Manager
@MainActor
class ConfigurationManager {
    static let shared = ConfigurationManager()
    
    private var configData: [String: Any] = [:]
    
    private init() {
        loadConfiguration()
    }
    
    // MARK: - Configuration Loading
    private func loadConfiguration() {
        // Try to load from Config.plist first (for development)
        if let path = Bundle.main.path(forResource: "Config", ofType: "plist"),
           let data = NSDictionary(contentsOfFile: path) as? [String: Any] {
            configData = data
            print("✅ Configuration loaded from Config.plist")
            return
        }
        
        // If Config.plist doesn't exist, use empty defaults
        configData = [:]
        print("⚠️ Config.plist not found - using empty configuration")
    }
    
    // MARK: - API Key Access
    func getAPIKey(for key: ConfigurationKey) -> String {
        return configData[key.rawValue] as? String ?? ""
    }
    
    // MARK: - Development Helper
    func hasConfigurationFile() -> Bool {
        return Bundle.main.path(forResource: "Config", ofType: "plist") != nil
    }
    
    // MARK: - All Configuration Keys
    func getAllConfigurationKeys() -> [String: String] {
        var result: [String: String] = [:]
        for key in ConfigurationKey.allCases {
            result[key.displayName] = getAPIKey(for: key)
        }
        return result
    }
}

// MARK: - Configuration Keys
enum ConfigurationKey: String, CaseIterable {
    case deepSeekAPI = "DEEPSEEK_API_KEY"
    case openRouterAPI = "OPENROUTER_API_KEY"
    case openAIAPI = "OPENAI_API_KEY"
    case qwenAPI = "QWEN_API_KEY"
    case alphaVantageAPI = "ALPHA_VANTAGE_API_KEY"
    
    var displayName: String {
        switch self {
        case .deepSeekAPI: return "DeepSeek API Key"
        case .openRouterAPI: return "OpenRouter API Key"
        case .openAIAPI: return "OpenAI API Key"
        case .qwenAPI: return "Qwen API Key"
        case .alphaVantageAPI: return "Alpha Vantage API Key"
        }
    }
    
    var description: String {
        switch self {
        case .deepSeekAPI: return "Required for AI-powered stock predictions (Default)"
        case .openRouterAPI: return "Optional, for additional AI model access"
        case .openAIAPI: return "Optional, for OpenAI-powered insights"
        case .qwenAPI: return "Optional, for Qwen-powered insights"
        case .alphaVantageAPI: return "Required for stock market data access"
        }
    }
    
    var isRequired: Bool {
        switch self {
        case .deepSeekAPI, .alphaVantageAPI: return true
        case .openRouterAPI, .openAIAPI, .qwenAPI: return false
        }
    }
    
    var helpURL: String? {
        switch self {
        case .deepSeekAPI: return "https://platform.deepseek.com/api_keys"
        case .openRouterAPI: return "https://openrouter.ai/settings/keys"
        case .openAIAPI: return "https://platform.openai.com/api-keys"
        case .qwenAPI: return "https://modelstudio.console.alibabacloud.com/?tab=playground#/api-key"
        case .alphaVantageAPI: return "https://www.alphavantage.co/support/#api-key"
        }
    }
}
