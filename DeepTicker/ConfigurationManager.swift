import Foundation

// MARK: - DEPRECATED Configuration Manager
// This file has been deprecated in favor of SecureConfigurationManager
// which uses Secrets.plist as the single configuration source.
//
// SecureConfigurationManager provides:
// - Secrets.plist as the single configuration file
// - Secure keychain storage for user modifications
// - Better API key management and validation
// 
// Please use SecureConfigurationManager.shared instead.

@available(*, deprecated, message: "Use SecureConfigurationManager.shared instead")
@MainActor 
class ConfigurationManager {
    static let shared = ConfigurationManager()
    
    private init() {
        print("⚠️  ConfigurationManager is deprecated. Use SecureConfigurationManager.shared instead.")
    }
    
    @available(*, deprecated, message: "Use SecureConfigurationManager.shared.getAPIKey(for:) instead")
    func getAPIKey(for key: ConfigurationKey) -> String {
        print("⚠️  ConfigurationManager.getAPIKey is deprecated. Use SecureConfigurationManager instead.")
        return ""
    }
    
    @available(*, deprecated, message: "Use SecureConfigurationManager.shared instead")
    func hasConfigurationFile() -> Bool {
        return false
    }
    
    @available(*, deprecated, message: "Use SecureConfigurationManager.shared instead")
    func getAllConfigurationKeys() -> [String: String] {
        return [:]
    }
}

// MARK: - DEPRECATED Configuration Keys
// These keys are now handled by SecureConfigurationManager
@available(*, deprecated, message: "Use SecureConfigurationManager ConfigKey enum instead")
enum ConfigurationKey: String, CaseIterable {
    case deepSeekAPI = "DEEPSEEK_API_KEY"
    case openRouterAPI = "OPENROUTER_API_KEY"
    case openAIAPI = "OPENAI_API_KEY"
    case qwenAPI = "QWEN_API_KEY"
    case alphaVantageAPI = "ALPHA_VANTAGE_API_KEY"
    case rapidAPI = "RAPID_API_KEY"
    
    var displayName: String { "" }
    var description: String { "" }
    var isRequired: Bool { false }
    var helpURL: String? { nil }
}
