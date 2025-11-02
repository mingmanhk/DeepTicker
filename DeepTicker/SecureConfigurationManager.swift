import Foundation
import Security
import Combine
import SwiftUI

/// Secure configuration manager that handles API keys from Secrets.plist and keychain storage
/// Uses Secrets.plist as the single source of configuration with keychain for secure storage and user modifications
class SecureConfigurationManager: ObservableObject {
    static let shared = SecureConfigurationManager()
    
    // MARK: - API Key Storage
    @Published var deepSeekAPIKey: String = ""
    @Published var openRouterAPIKey: String = ""
    @Published var openAIAPIKey: String = ""
    @Published var qwenAPIKey: String = ""
    @Published var alphaVantageAPIKey: String = ""
    @Published var rapidAPIKey: String = ""
    
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
        
        saveToKeychain(key, account: configKey.keychainAccount)
    }
    
    /// Update Alpha Vantage API key
    func updateAlphaVantageAPIKey(_ key: String) {
        alphaVantageAPIKey = key
        saveToKeychain(key, account: ConfigKey.alphaVantageAPI.keychainAccount)
    }
    
    /// Update RapidAPI key
    func updateRapidAPIKey(_ key: String) {
        rapidAPIKey = key
        saveToKeychain(key, account: ConfigKey.rapidAPI.keychainAccount)
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
    }
    
    private func loadAPIKey(for configKey: ConfigKey) -> String {
        // Priority: 1. Keychain (for user-modified keys), 2. Secrets.plist (default configuration)
        
        // 1. Try keychain first (for user-modified keys)
        if let keychainKey = loadFromKeychain(account: configKey.keychainAccount), !keychainKey.isEmpty {
            return keychainKey
        }
        
        // 2. Use Secrets.plist as the single configuration file
        if let plistKey = loadFromSecretsPlist(key: configKey.rawValue), !plistKey.isEmpty {
            // Save to keychain for future use and potential user modification
            saveToKeychain(plistKey, account: configKey.keychainAccount)
            return plistKey
        }
        
        return ""
    }
    
    private func loadPromptTemplates() {
        analyzeProfitConfidencePrompt = promptDefaults.string(forKey: PromptKey.profitConfidence.rawValue) ?? PromptTemplate.defaultProfitConfidence
        analyzeRiskPrompt = promptDefaults.string(forKey: PromptKey.risk.rawValue) ?? PromptTemplate.defaultRisk
        analyzePredictionPrompt = promptDefaults.string(forKey: PromptKey.prediction.rawValue) ?? PromptTemplate.defaultPrediction
        analyzePortfolioPrompt = promptDefaults.string(forKey: PromptKey.portfolio.rawValue) ?? PromptTemplate.defaultPortfolio
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

struct PromptTemplate {
    static let defaultProfitConfidence = """
Analyze the following stock portfolio and provide a concise summary of its overall health, diversification, and risk profile. Offer actionable suggestions for improvement.
"""
    
    static let defaultRisk = """
Analyze the following stock portfolio and provide a concise summary of its overall health, diversification, and risk profile. Offer actionable suggestions for improvement.
"""
    
    static let defaultPrediction = """
Recent Historical Data for Last 10 trading days. Please provide a prediction for tomorrow's movement with the following JSON format. All percentage-based values should be numbers between 0 and 100.

{  
  "direction": "up|down|neutral",  
  "confidence": 85.0,  
  "predicted_change": 2.5,  
  "reasoning": "Brief explanation of analysis.",  
  "profit_likelihood": 75.0,  
  "gain_potential": 4.5,  
  "upside_chance": 80.0  
}
"""
    
    static let defaultPortfolio = """
You are an expert financial analyst AI. Your task is to provide a detailed daily market briefing and portfolio health assessment. Analyze the provided stock symbols in the context of current market events, including political developments, earnings reports, and institutional trades. Provide a brief health assessment with recommendations for diversification or risk management. Structure your response strictly in the requested JSON format with four keys: `overview`, `keyDrivers`, `highlightsAndActivity`, and `riskFactors`.
"""
}
