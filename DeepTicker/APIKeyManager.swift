import Foundation
import Combine

// MARK: - DEPRECATED
// This class is deprecated in favor of SettingsManager + ConfigurationManager
// which provides better security through Keychain storage and Config.plist defaults

@available(*, deprecated, message: "Use SettingsManager.shared for API key management")
@MainActor
class APIKeyManager: ObservableObject {
    @Published var deepSeekAPIKey: String {
        didSet { save(key: deepSeekAPIKey, for: .deepSeek) }
    }
    @Published var alphaVantageAPIKey: String {
        didSet { save(key: alphaVantageAPIKey, for: .alphaVantage) }
    }
    @Published var openAIAPIKey: String {
        didSet { save(key: openAIAPIKey, for: .openAI) }
    }
    @Published var qwenAPIKey: String {
        didSet { save(key: qwenAPIKey, for: .qwen) }
    }

    private enum Key: String {
        case deepSeek = "DEEPSEEK_API_KEY"
        case alphaVantage = "ALPHA_VANTAGE_API_KEY"
        case openAI = "OPENAI_API_KEY"
        case qwen = "QWEN_API_KEY"
    }
    
    // DEPRECATED: Default keys should be in Config.plist
    // These are kept for backward compatibility
    private let defaultDeepSeekKey = ""
    private let defaultOpenAIKey = ""
    private let defaultQwenKey = ""
    private let defaultAlphaVantageKey = ""

    init() {
        // Migrate to new system - load from SettingsManager instead
        let settingsManager = SettingsManager.shared
        self.deepSeekAPIKey = settingsManager.deepSeekAPIKey
        self.alphaVantageAPIKey = settingsManager.alphaVantageAPIKey
        self.openAIAPIKey = settingsManager.openAIAPIKey
        self.qwenAPIKey = settingsManager.qwenAPIKey
    }

    private func save(key: String, for keyType: Key) {
        // DEPRECATED: Use SettingsManager instead
        // This now delegates to SettingsManager for consistency
        let settingsManager = SettingsManager.shared
        switch keyType {
        case .deepSeek:
            settingsManager.deepSeekAPIKey = key
        case .alphaVantage:
            settingsManager.alphaVantageAPIKey = key
        case .openAI:
            settingsManager.openAIAPIKey = key
        case .qwen:
            settingsManager.qwenAPIKey = key
        }
    }

    private static func load(for keyType: Key) -> String? {
        // DEPRECATED: Use SettingsManager instead
        return nil
    }
    
    static let shared = APIKeyManager()
}
