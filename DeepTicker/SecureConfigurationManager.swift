import Foundation
import Security
import Combine
import SwiftUI

// MARK: - Notification Names
extension Notification.Name {
    static let apiKeyDidUpdate = Notification.Name("com.deepticker.apiKeyDidUpdate")
}

/// Secure configuration manager that handles API keys from Secrets.plist and keychain storage
/// Uses Secrets.plist as the single source of configuration with keychain for secure storage and user modifications
class SecureConfigurationManager: ObservableObject {
    static let shared = SecureConfigurationManager()
    
    // MARK: - API Key Storage
    @Published var deepSeekAPIKey: String = "" {
        didSet {
            guard !isUpdatingFromKeychain else { return }
            print("🔑 [didSet] DeepSeek API key changed, saving to keychain")
            saveAPIKeyToKeychain(deepSeekAPIKey, for: .deepSeek)
        }
    }
    @Published var openRouterAPIKey: String = "" {
        didSet {
            guard !isUpdatingFromKeychain else { return }
            print("🔑 [didSet] OpenRouter API key changed, saving to keychain")
            saveAPIKeyToKeychain(openRouterAPIKey, for: .openRouter)
        }
    }
    @Published var openAIAPIKey: String = "" {
        didSet {
            guard !isUpdatingFromKeychain else { return }
            print("🔑 [didSet] OpenAI API key changed, saving to keychain")
            saveAPIKeyToKeychain(openAIAPIKey, for: .openAI)
        }
    }
    @Published var qwenAPIKey: String = "" {
        didSet {
            guard !isUpdatingFromKeychain else { return }
            print("🔑 [didSet] Qwen API key changed, saving to keychain")
            saveAPIKeyToKeychain(qwenAPIKey, for: .qwen)
        }
    }
    @Published var alphaVantageAPIKey: String = "" {
        didSet {
            guard !isUpdatingFromKeychain else { return }
            print("🔑 [didSet] Alpha Vantage API key changed, saving to keychain")
            saveToKeychain(alphaVantageAPIKey, account: ConfigKey.alphaVantageAPI.keychainAccount)
            syncToSettingsManagerKeychain(key: alphaVantageAPIKey, for: .alphaVantageAPI)
        }
    }
    @Published var rapidAPIKey: String = "" {
        didSet {
            guard !isUpdatingFromKeychain else { return }
            print("🔑 [didSet] RapidAPI key changed, saving to keychain")
            saveToKeychain(rapidAPIKey, account: ConfigKey.rapidAPI.keychainAccount)
            UserDefaults.standard.set(rapidAPIKey, forKey: "rapidAPIKey")
        }
    }
    
    // MARK: - AI Prompt Templates (Editable)
    @Published var analyzeProfitConfidencePrompt: String = ""
    @Published var analyzeRiskPrompt: String = ""
    @Published var analyzePredictionPrompt: String = ""
    @Published var analyzePortfolioPrompt: String = ""
    
    // MARK: - Configuration Keys
    private enum ConfigKey: String, CaseIterable {
        case deepSeekAPI = "DEEPSEEK_API_KEY"
        case openRouterAPI = "OPENROUTER_API_KEY"
        case openAIAPI = "OPENAI_API_KEY"
        case qwenAPI = "QWEN_API_KEY"
        case alphaVantageAPI = "ALPHA_VANTAGE_API_KEY"
        case rapidAPI = "RAPID_API_KEY"
        
        var keychainAccount: String { "DeepTicker.\(rawValue)" }
        var displayName: String {
            switch self {
            case .deepSeekAPI: return "DeepSeek"
            case .openRouterAPI: return "OpenRouter"
            case .openAIAPI: return "OpenAI"
            case .qwenAPI: return "Qwen"
            case .alphaVantageAPI: return "Alpha Vantage"
            case .rapidAPI: return "RapidAPI"
            }
        }
    }
    
    private enum PromptKey: String, CaseIterable {
        case profitConfidence = "AnalyzeProfitConfidencePrompt"
        case risk = "AnalyzeRiskPrompt"
        case prediction = "AnalyzePredictionPrompt"
        case portfolio = "AnalyzePortfolioPrompt"
    }
    
    private let keychainService = "com.deepticker.apikeys"
    private let promptDefaults = UserDefaults.standard
    
    // Flag to prevent infinite recursion in didSet
    private var isUpdatingFromKeychain = false
    
    private init() {
        loadConfiguration()
        loadPromptTemplates()
    }
    
    // MARK: - Public Interface
    
    /// Get API key for a specific service
    func getAPIKey(for service: AIProvider) -> String? {
        switch service {
        case .deepSeek: return deepSeekAPIKey.isEmpty ? nil : deepSeekAPIKey
        case .openRouter: return openRouterAPIKey.isEmpty ? nil : openRouterAPIKey
        case .openAI: return openAIAPIKey.isEmpty ? nil : openAIAPIKey
        case .qwen: return qwenAPIKey.isEmpty ? nil : qwenAPIKey
        }
    }
    
    /// Check if API key is valid (non-empty and doesn't contain placeholder text)
    func isAPIKeyValid(for service: AIProvider) -> Bool {
        guard let key = getAPIKey(for: service) else { return false }
        return !key.isEmpty && 
               !key.hasPrefix("sk-REPLACE") && 
               !key.hasPrefix("your_") &&
               !key.contains("PLACEHOLDER")
    }
    
    /// Check if Alpha Vantage API key is valid
    var isAlphaVantageKeyValid: Bool {
        let key = alphaVantageAPIKey
        return !key.isEmpty &&
               !key.hasPrefix("REPLACE_") &&
               !key.hasPrefix("your_") &&
               !key.contains("PLACEHOLDER")
    }
    
    /// Check if RapidAPI key is valid
    var isRapidAPIKeyValid: Bool {
        let key = rapidAPIKey
        return !key.isEmpty &&
               !key.hasPrefix("REPLACE_") &&
               !key.hasPrefix("your_") &&
               !key.contains("PLACEHOLDER")
    }
    
    /// Get available (valid) AI providers
    var availableAIProviders: [AIProvider] {
        AIProvider.allCases.filter { isAPIKeyValid(for: $0) }
    }
    
    /// Update API key and save securely
    func updateAPIKey(_ key: String, for service: AIProvider) {
        let configKey: ConfigKey
        
        // Set flag to prevent didSet from firing
        isUpdatingFromKeychain = true
        
        switch service {
        case .deepSeek: 
            deepSeekAPIKey = key
            configKey = .deepSeekAPI
        case .openRouter: 
            openRouterAPIKey = key
            configKey = .openRouterAPI
        case .openAI: 
            openAIAPIKey = key
            configKey = .openAIAPI
        case .qwen: 
            qwenAPIKey = key
            configKey = .qwenAPI
        }
        
        isUpdatingFromKeychain = false
        
        saveToKeychain(key, account: configKey.keychainAccount)
        
        // CRITICAL: Also sync with SettingsManager's keychain for compatibility
        syncToSettingsManager(key: key, for: service)
        
        // Post notification so other parts of the app can react
        NotificationCenter.default.post(name: .apiKeyDidUpdate, object: nil, userInfo: ["provider": service])
    }
    
    /// Save API key to keychain (called from didSet observers)
    private func saveAPIKeyToKeychain(_ key: String, for service: AIProvider) {
        let configKey: ConfigKey
        switch service {
        case .deepSeek: configKey = .deepSeekAPI
        case .openRouter: configKey = .openRouterAPI
        case .openAI: configKey = .openAIAPI
        case .qwen: configKey = .qwenAPI
        }
        
        saveToKeychain(key, account: configKey.keychainAccount)
        syncToSettingsManager(key: key, for: service)
        
        // Post notification
        NotificationCenter.default.post(name: .apiKeyDidUpdate, object: nil, userInfo: ["provider": service])
    }
    
    /// Synchronize API key to SettingsManager's keychain location
    private func syncToSettingsManager(key: String, for service: AIProvider) {
        let settingsManagerService = "com.example.DeepTicker.apiKeys"
        let settingsManagerAccount: String
        
        switch service {
        case .deepSeek:
            settingsManagerAccount = "com.example.DeepTicker.deepSeekAPIKey"
        case .openRouter:
            settingsManagerAccount = "com.example.DeepTicker.openRouterAPIKey"
        case .openAI:
            settingsManagerAccount = "com.example.DeepTicker.openAIAPIKey"
        case .qwen:
            settingsManagerAccount = "com.example.DeepTicker.qwenAPIKey"
        }
        
        if key.isEmpty {
            KeychainHelper.standard.delete(service: settingsManagerService, account: settingsManagerAccount)
        } else {
            KeychainHelper.standard.save(key, service: settingsManagerService, account: settingsManagerAccount)
        }
    }
    
    /// Update Alpha Vantage API key
    func updateAlphaVantageAPIKey(_ key: String) {
        alphaVantageAPIKey = key
        saveToKeychain(key, account: ConfigKey.alphaVantageAPI.keychainAccount)
        
        // Also sync with SettingsManager's keychain
        let settingsManagerService = "com.example.DeepTicker.apiKeys"
        let settingsManagerAccount = "com.example.DeepTicker.alphaVantageAPIKey"
        if key.isEmpty {
            KeychainHelper.standard.delete(service: settingsManagerService, account: settingsManagerAccount)
        } else {
            KeychainHelper.standard.save(key, service: settingsManagerService, account: settingsManagerAccount)
        }
    }
    
    /// Update RapidAPI key
    func updateRapidAPIKey(_ key: String) {
        rapidAPIKey = key
        saveToKeychain(key, account: ConfigKey.rapidAPI.keychainAccount)
        
        // RapidAPI uses UserDefaults in SettingsManager, not keychain
        UserDefaults.standard.set(key, forKey: "rapidAPIKey")
    }
    
    /// Update prompt template
    func updatePromptTemplate(_ prompt: String, for type: PromptType) {
        switch type {
        case .profitConfidence: 
            analyzeProfitConfidencePrompt = prompt
        case .risk: 
            analyzeRiskPrompt = prompt
        case .prediction: 
            analyzePredictionPrompt = prompt
        case .portfolio: 
            analyzePortfolioPrompt = prompt
        }
        
        promptDefaults.set(prompt, forKey: type.key)
    }
    
    /// Get prompt template for AI analysis
    func getPromptTemplate(for type: PromptType) -> String {
        switch type {
        case .profitConfidence: return analyzeProfitConfidencePrompt
        case .risk: return analyzeRiskPrompt
        case .prediction: return analyzePredictionPrompt
        case .portfolio: return analyzePortfolioPrompt
        }
    }
    
    // MARK: - Private Implementation
    
    private func loadConfiguration() {
        isUpdatingFromKeychain = true
        
        for configKey in ConfigKey.allCases {
            let key = loadAPIKey(for: configKey)
            
            switch configKey {
            case .deepSeekAPI: deepSeekAPIKey = key
            case .openRouterAPI: openRouterAPIKey = key
            case .openAIAPI: openAIAPIKey = key
            case .qwenAPI: qwenAPIKey = key
            case .alphaVantageAPI: alphaVantageAPIKey = key
            case .rapidAPI: rapidAPIKey = key
            }
        }
        
        isUpdatingFromKeychain = false
    }
    
    private func loadAPIKey(for configKey: ConfigKey) -> String {
        // Priority: 1. Keychain (for user-modified keys), 2. SettingsManager keychain (for backwards compatibility), 3. Secrets.plist (default configuration)
        
        // 1. Try our keychain first (for user-modified keys)
        if let keychainKey = loadFromKeychain(account: configKey.keychainAccount), !keychainKey.isEmpty {
            return keychainKey
        }
        
        // 2. Check SettingsManager's keychain location for backwards compatibility
        if let settingsKey = loadFromSettingsManagerKeychain(for: configKey), !settingsKey.isEmpty {
            // Migrate to our keychain
            saveToKeychain(settingsKey, account: configKey.keychainAccount)
            return settingsKey
        }
        
        // 3. Use Secrets.plist as the single configuration file
        if let plistKey = loadFromSecretsPlist(key: configKey.rawValue), !plistKey.isEmpty {
            // Save to keychain for future use and potential user modification
            saveToKeychain(plistKey, account: configKey.keychainAccount)
            // Also sync to SettingsManager location
            syncToSettingsManagerKeychain(key: plistKey, for: configKey)
            return plistKey
        }
        
        return ""
    }
    
    /// Load from SettingsManager's keychain location (for backwards compatibility)
    private func loadFromSettingsManagerKeychain(for configKey: ConfigKey) -> String? {
        let settingsManagerService = "com.example.DeepTicker.apiKeys"
        let settingsManagerAccount: String
        
        switch configKey {
        case .deepSeekAPI:
            settingsManagerAccount = "com.example.DeepTicker.deepSeekAPIKey"
        case .openRouterAPI:
            settingsManagerAccount = "com.example.DeepTicker.openRouterAPIKey"
        case .openAIAPI:
            settingsManagerAccount = "com.example.DeepTicker.openAIAPIKey"
        case .qwenAPI:
            settingsManagerAccount = "com.example.DeepTicker.qwenAPIKey"
        case .alphaVantageAPI:
            settingsManagerAccount = "com.example.DeepTicker.alphaVantageAPIKey"
        case .rapidAPI:
            // RapidAPI is stored in UserDefaults, not keychain
            return UserDefaults.standard.string(forKey: "rapidAPIKey")
        }
        
        return KeychainHelper.standard.read(service: settingsManagerService, account: settingsManagerAccount)
    }
    
    /// Sync to SettingsManager's keychain location
    private func syncToSettingsManagerKeychain(key: String, for configKey: ConfigKey) {
        let settingsManagerService = "com.example.DeepTicker.apiKeys"
        let settingsManagerAccount: String
        
        switch configKey {
        case .deepSeekAPI:
            settingsManagerAccount = "com.example.DeepTicker.deepSeekAPIKey"
        case .openRouterAPI:
            settingsManagerAccount = "com.example.DeepTicker.openRouterAPIKey"
        case .openAIAPI:
            settingsManagerAccount = "com.example.DeepTicker.openAIAPIKey"
        case .qwenAPI:
            settingsManagerAccount = "com.example.DeepTicker.qwenAPIKey"
        case .alphaVantageAPI:
            settingsManagerAccount = "com.example.DeepTicker.alphaVantageAPIKey"
        case .rapidAPI:
            // RapidAPI uses UserDefaults
            UserDefaults.standard.set(key, forKey: "rapidAPIKey")
            return
        }
        
        if key.isEmpty {
            KeychainHelper.standard.delete(service: settingsManagerService, account: settingsManagerAccount)
        } else {
            KeychainHelper.standard.save(key, service: settingsManagerService, account: settingsManagerAccount)
        }
    }
    
    private func loadPromptTemplates() {
        analyzeProfitConfidencePrompt = promptDefaults.string(forKey: PromptKey.profitConfidence.rawValue) ?? DefaultPromptTemplates.profitConfidence
        analyzeRiskPrompt = promptDefaults.string(forKey: PromptKey.risk.rawValue) ?? DefaultPromptTemplates.summaryRisk
        analyzePredictionPrompt = promptDefaults.string(forKey: PromptKey.prediction.rawValue) ?? DefaultPromptTemplates.stockInsight
        analyzePortfolioPrompt = promptDefaults.string(forKey: PromptKey.portfolio.rawValue) ?? DefaultPromptTemplates.marketBriefing
    }
    
    private func loadFromSecretsPlist(key: String) -> String? {
        guard let path = Bundle.main.path(forResource: "Secrets", ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: path) else {
            return nil
        }
        return plist[key] as? String
    }
    
    // MARK: - Keychain Operations
    
    private func saveToKeychain(_ value: String, account: String) {
        let data = value.data(using: .utf8) ?? Data()
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account,
            kSecValueData as String: data
        ]
        
        // Delete existing item first
        SecItemDelete(query as CFDictionary)
        
        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            print("Failed to save to keychain: \(status)")
        }
    }
    
    private func loadFromKeychain(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data else {
            return nil
        }
        
        return String(data: data, encoding: .utf8)
    }
    
    /// Clear all stored API keys (for testing/debugging)
    func clearAllKeys() {
        for configKey in ConfigKey.allCases {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: keychainService,
                kSecAttrAccount as String: configKey.keychainAccount
            ]
            SecItemDelete(query as CFDictionary)
        }
        loadConfiguration()
    }
}

// MARK: - Supporting Types

enum AIProvider: String, CaseIterable, Identifiable, Codable {
    case deepSeek = "deepseek"
    case openRouter = "openrouter"  
    case openAI = "openai"
    case qwen = "qwen"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .deepSeek: return "DeepSeek"
        case .openRouter: return "OpenRouter"
        case .openAI: return "OpenAI"
        case .qwen: return "Qwen"
        }
    }
    
    var iconName: String {
        switch self {
        case .deepSeek: return "brain.head.profile"
        case .openRouter: return "arrow.triangle.swap"
        case .openAI: return "sparkles"
        case .qwen: return "cpu"
        }
    }
    
    var primaryColor: SwiftUI.Color {
        switch self {
        case .deepSeek: return .blue
        case .openRouter: return .purple
        case .openAI: return .green
        case .qwen: return .orange
        }
    }
    
    var apiKeyURL: URL? {
        switch self {
        case .deepSeek:
            return URL(string: "https://platform.deepseek.com/api_keys")
        case .openRouter:
            return URL(string: "https://openrouter.ai/settings/keys")
        case .openAI:
            return URL(string: "https://platform.openai.com/api-keys")
        case .qwen:
            return URL(string: "https://modelstudio.console.alibabacloud.com/?tab=playground#/api-key")
        }
    }
}

enum PromptType: Identifiable {
    case profitConfidence
    case risk
    case prediction
    case portfolio
    
    var id: String {
        switch self {
        case .profitConfidence: return "profitConfidence"
        case .risk: return "risk"
        case .prediction: return "prediction"
        case .portfolio: return "portfolio"
        }
    }
    
    var key: String {
        switch self {
        case .profitConfidence: return "AnalyzeProfitConfidencePrompt"
        case .risk: return "AnalyzeRiskPrompt"
        case .prediction: return "AnalyzePredictionPrompt"
        case .portfolio: return "AnalyzePortfolioPrompt"
        }
    }
    
    var displayName: String {
        switch self {
        case .profitConfidence: return "Profit Confidence Analysis"
        case .risk: return "Risk Assessment"
        case .prediction: return "Movement Prediction"
        case .portfolio: return "Portfolio Overview"
        }
    }
}

// MARK: - Default Prompt Templates

struct DefaultPromptTemplates {
    static let profitConfidence = """
Provide an overall portfolio analysis focusing on:
        1. General market sentiment affecting the entire portfolio
        2. Overall risk assessment across all holdings
        3. Confidence score for the portfolio's performance potential
        4. Brief summary of key factors impacting the portfolio as a whole

Respond in the following JSON format:

{
  "insights": {
    "confidence_score": 0.75,
    "risk_level": "Medium"
  }
}
"""

    static let summaryRisk = """
Analyze the following stock portfolio and provide a concise summary of its overall health, diversification, and risk profile. Offer actionable suggestions for improvement.
"""
    
    static let stockInsight = """
Please provide a prediction for tomorrow's movement with the following JSON format. All percentage-based values should be numbers between 0 and 100.
{
  "direction": "up|down|neutral",
  "confidence": 0.85,
  "predicted_change": 2.5,
  "reasoning": "Brief explanation of analysis.",
  "profit_likelihood": 75.0,
  "gain_potential": 4.5,
  "upside_chance": 80.0
}
"""
    
    static let marketBriefing = """
You are an expert financial analyst AI. Your task is to provide a detailed daily market briefing and portfolio health assessment.
Analyze the provided stock symbols in the context of current market events, including political developments, earnings reports, and institutional trades.
Provide a brief health assessment with recommendations for diversification or risk management.

Always maintain a balanced perspective - avoid overly pessimistic language while being realistic about risks.
Structure your response strictly in the requested JSON format with four keys: "overview", "keyDrivers", "highlightsAndActivity", and "riskFactors".

Keep your analysis professional, informative, and actionable while avoiding extreme negative sentiment.
"""
}
