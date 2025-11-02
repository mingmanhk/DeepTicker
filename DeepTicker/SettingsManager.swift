import Foundation
import Combine
import SwiftUI

@MainActor
class SettingsManager: ObservableObject {

    static let shared = SettingsManager()

    private enum KeychainKey {
        static let alphaVantage = "com.example.DeepTicker.alphaVantageAPIKey"
        static let deepSeek = "com.example.DeepTicker.deepSeekAPIKey"
        static let openAI = "com.example.DeepTicker.openAIAPIKey"
        static let qwen = "com.example.DeepTicker.qwenAPIKey"
        static let openRouter = "com.example.DeepTicker.openRouterAPIKey"
    }

    private enum UserDefaultsKey {
        static let predictionFrequency = "predictionFrequency"
        static let globalAlertThreshold = "globalAlertThreshold"
        static let notificationStyle = "notificationStyle"
        static let enableMascot = "enableMascot"
        static let rapidAPIKey = "rapidAPIKey"
    }
    
    private static let keychainService = "com.example.DeepTicker.apiKeys"

    // API Keys
    @Published var alphaVantageAPIKey: String {
        didSet { Self.saveAPIKey(alphaVantageAPIKey, forKey: KeychainKey.alphaVantage) }
    }
    
    @Published var deepSeekAPIKey: String {
        didSet { Self.saveAPIKey(deepSeekAPIKey, forKey: KeychainKey.deepSeek) }
    }
    
    @Published var openAIAPIKey: String {
        didSet {
            Self.saveAPIKey(openAIAPIKey, forKey: KeychainKey.openAI)
        }
    }
    
    @Published var qwenAPIKey: String {
        didSet {
            Self.saveAPIKey(qwenAPIKey, forKey: KeychainKey.qwen)
        }
    }
    
    @Published var openRouterAPIKey: String {
        didSet {
            Self.saveAPIKey(openRouterAPIKey, forKey: KeychainKey.openRouter)
        }
    }
    
    /// RapidAPI key used for providers that require `x-rapidapi-key`
    @Published var rapidAPIKey: String {
        didSet { UserDefaults.standard.set(rapidAPIKey, forKey: UserDefaultsKey.rapidAPIKey) }
    }

    // AI & Prediction Settings - AI Predictions are always enabled
    var enablePredictions: Bool = true

    @Published var predictionFrequency: PredictionFrequency {
        didSet { UserDefaults.standard.set(predictionFrequency.rawValue, forKey: UserDefaultsKey.predictionFrequency) }
    }
    
    // Alert Settings
    @Published var globalAlertThreshold: Double {
        didSet { UserDefaults.standard.set(globalAlertThreshold, forKey: UserDefaultsKey.globalAlertThreshold) }
    }
    
    @Published var notificationStyle: NotificationStyle {
        didSet { UserDefaults.standard.set(notificationStyle.rawValue, forKey: UserDefaultsKey.notificationStyle) }
    }
    
    // UI Settings
    @Published var enableMascot: Bool {
        didSet { UserDefaults.standard.set(enableMascot, forKey: UserDefaultsKey.enableMascot) }
    }
    
    // MARK: - New Settings for Enhanced Features
    
    // Alerts Configuration
    @Published var alertsEnabled: Bool {
        didSet { UserDefaults.standard.set(alertsEnabled, forKey: "alertsEnabled") }
    }
    
    @Published var alertFrequency: AlertFrequency {
        didSet { UserDefaults.standard.set(alertFrequency.rawValue, forKey: "alertFrequency") }
    }
    
    @Published var confidenceThreshold: Double {
        didSet { UserDefaults.standard.set(confidenceThreshold, forKey: "confidenceThreshold") }
    }
    
    @Published var riskLevelAlertsEnabled: Bool {
        didSet { UserDefaults.standard.set(riskLevelAlertsEnabled, forKey: "riskLevelAlertsEnabled") }
    }
    
    @Published var profitLikelihoodThreshold: Double {
        didSet { UserDefaults.standard.set(profitLikelihoodThreshold, forKey: "profitLikelihoodThreshold") }
    }
    
    // Display Settings
    @Published var showRiskBadges: Bool {
        didSet { UserDefaults.standard.set(showRiskBadges, forKey: "showRiskBadges") }
    }
    
    // Data Settings
    @Published var offlineCacheEnabled: Bool {
        didSet { UserDefaults.standard.set(offlineCacheEnabled, forKey: "offlineCacheEnabled") }
    }
    
    // MARK: - AI Prompt Management
    
    @Published var analyzeSystemPrompt: String {
        didSet { UserDefaults.standard.set(analyzeSystemPrompt, forKey: "analyzeSystemPrompt") }
    }
    
    @Published var analyzePredictionRiskPrompt: String {
        didSet { UserDefaults.standard.set(analyzePredictionRiskPrompt, forKey: "analyzePredictionRiskPrompt") }
    }
    
    @Published var analyzePredictionConfidencePrompt: String {
        didSet { UserDefaults.standard.set(analyzePredictionConfidencePrompt, forKey: "analyzePredictionConfidencePrompt") }
    }
    
    @Published var analyzePredictionPrompt: String {
        didSet { UserDefaults.standard.set(analyzePredictionPrompt, forKey: "analyzePredictionPrompt") }
    }
    
    @Published var analyzeMyInvestmentPrompt: String {
        didSet { UserDefaults.standard.set(analyzeMyInvestmentPrompt, forKey: "analyzeMyInvestmentPrompt") }
    }
    
    // MARK: - Computed Properties
    
    var isAlphaVantageKeyValid: Bool {
        !alphaVantageAPIKey.isEmpty && !alphaVantageAPIKey.hasPrefix("REPLACE_") && !alphaVantageAPIKey.hasPrefix("your_")
    }
    
    var isDeepSeekKeyValid: Bool {
        !deepSeekAPIKey.isEmpty && !deepSeekAPIKey.hasPrefix("REPLACE_") && !deepSeekAPIKey.hasPrefix("your_")
    }
    
    private init() {
        // API Keys from Keychain with fallback to Secrets.plist defaults
        self.alphaVantageAPIKey = Self.loadAPIKeyWithDefaults(forKey: KeychainKey.alphaVantage, configKey: "ALPHA_VANTAGE_API_KEY")
        self.deepSeekAPIKey = Self.loadAPIKeyWithDefaults(forKey: KeychainKey.deepSeek, configKey: "DEEPSEEK_API_KEY")
        self.openAIAPIKey = Self.loadAPIKeyWithDefaults(forKey: KeychainKey.openAI, configKey: "OPENAI_API_KEY")
        self.qwenAPIKey = Self.loadAPIKeyWithDefaults(forKey: KeychainKey.qwen, configKey: "QWEN_API_KEY")
        self.openRouterAPIKey = Self.loadAPIKeyWithDefaults(forKey: KeychainKey.openRouter, configKey: "OPENROUTER_API_KEY")
        
        let rapidFromDefaults = UserDefaults.standard.string(forKey: UserDefaultsKey.rapidAPIKey) ?? ""
        if !rapidFromDefaults.isEmpty {
            self.rapidAPIKey = rapidFromDefaults
        } else {
            // Fallback to Secrets.plist in bundle (not checked into source)
            if let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
               let data = try? Data(contentsOf: url),
               let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
               let rapidFromPlist = plist[UserDefaultsKey.rapidAPIKey] as? String, !rapidFromPlist.isEmpty {
                self.rapidAPIKey = rapidFromPlist
                UserDefaults.standard.set(rapidFromPlist, forKey: UserDefaultsKey.rapidAPIKey)
            } else {
                self.rapidAPIKey = ""
            }
        }
        
        // AI & Prediction Settings - AI Predictions are always enabled by default
        self.predictionFrequency = PredictionFrequency(rawValue: UserDefaults.standard.string(forKey: UserDefaultsKey.predictionFrequency) ?? "") ?? .thirtyMinutes

        // Alert Settings
        if UserDefaults.standard.object(forKey: UserDefaultsKey.globalAlertThreshold) != nil {
            self.globalAlertThreshold = UserDefaults.standard.double(forKey: UserDefaultsKey.globalAlertThreshold)
        } else {
            self.globalAlertThreshold = 5.0
        }
        self.notificationStyle = NotificationStyle(rawValue: UserDefaults.standard.string(forKey: UserDefaultsKey.notificationStyle) ?? "") ?? .push

        // UI Settings
        if UserDefaults.standard.object(forKey: UserDefaultsKey.enableMascot) != nil {
            self.enableMascot = UserDefaults.standard.bool(forKey: UserDefaultsKey.enableMascot)
        } else {
            self.enableMascot = true
        }
        
        // Enhanced Settings Initialization
        self.alertsEnabled = UserDefaults.standard.object(forKey: "alertsEnabled") != nil ? 
                            UserDefaults.standard.bool(forKey: "alertsEnabled") : false
        self.alertFrequency = AlertFrequency(rawValue: UserDefaults.standard.string(forKey: "alertFrequency") ?? "") ?? .thirtyMinutes
        self.confidenceThreshold = UserDefaults.standard.object(forKey: "confidenceThreshold") != nil ?
                                   UserDefaults.standard.double(forKey: "confidenceThreshold") : 0.1
        self.riskLevelAlertsEnabled = UserDefaults.standard.object(forKey: "riskLevelAlertsEnabled") != nil ?
                                     UserDefaults.standard.bool(forKey: "riskLevelAlertsEnabled") : true
        self.profitLikelihoodThreshold = UserDefaults.standard.object(forKey: "profitLikelihoodThreshold") != nil ?
                                        UserDefaults.standard.double(forKey: "profitLikelihoodThreshold") : 0.15
        self.showRiskBadges = UserDefaults.standard.object(forKey: "showRiskBadges") != nil ?
                             UserDefaults.standard.bool(forKey: "showRiskBadges") : true
        self.offlineCacheEnabled = UserDefaults.standard.object(forKey: "offlineCacheEnabled") != nil ?
                                  UserDefaults.standard.bool(forKey: "offlineCacheEnabled") : true
        
        // AI Prompt Management - Initialize with default prompts
        self.analyzeSystemPrompt = UserDefaults.standard.string(forKey: "analyzeSystemPrompt") ?? 
            "You are a financial analyst AI specialized in short-term stock predictions.\nAnalyze stock data and provide concise predictions with confidence levels.\nAlways respond with valid JSON format and keep explanations brief but insightful.\nFocus on technical indicators, volume trends, and recent market behavior."
        
        self.analyzePredictionRiskPrompt = UserDefaults.standard.string(forKey: "analyzePredictionRiskPrompt") ?? 
            "Analyze the following stock portfolio and provide a concise summary of its overall health, diversification, and risk profile. Offer actionable suggestions for improvement."
        
        self.analyzePredictionConfidencePrompt = UserDefaults.standard.string(forKey: "analyzePredictionConfidencePrompt") ?? 
            "Recent Historical Data for Last 10 trading days. Please provide a prediction for tomorrow's movement with the following JSON format. All percentage-based values should be numbers between 0 and 100."
        
        self.analyzePredictionPrompt = UserDefaults.standard.string(forKey: "analyzePredictionPrompt") ?? 
            "Recent Historical Data for Last 10 trading days Please provide a prediction for tomorrow's movement with the following JSON format. All percentage-based values should be numbers between 0 and 100. { \"direction\": \"up|down|neutral\", \"confidence\": 85.0, \"predicted_change\": 2.5, \"reasoning\": \"Brief explanation of analysis.\", \"profit_likelihood\": 75.0, \"gain_potential\": 4.5, \"upside_chance\": 80.0 }"
        
        self.analyzeMyInvestmentPrompt = UserDefaults.standard.string(forKey: "analyzeMyInvestmentPrompt") ?? 
            "You are an expert financial analyst AI. Your task is to provide a detailed daily market briefing and portfolio health assessment. Analyze the provided stock symbols in the context of current market events, including political developments, earnings reports, and institutional trades. Provide a brief health assessment with recommendations for diversification or risk management. Structure your response strictly in the requested JSON format with four keys: \"overview\", \"keyDrivers\", \"highlightsAndActivity\", and \"riskFactors\"."
    }

    // MARK: - Keychain Helpers
    private static func saveAPIKey(_ key: String, forKey account: String) {
        if key.isEmpty {
            // An empty key means we should remove it from the keychain.
            KeychainHelper.standard.delete(service: keychainService, account: account)
        } else {
            KeychainHelper.standard.save(key, service: keychainService, account: account)
        }
    }
    
    private static func loadAPIKey(forKey account: String) -> String {
        return KeychainHelper.standard.read(service: keychainService, account: account) ?? ""
    }
    
    /// Load API key from Keychain, falling back to Secrets.plist default if not found
    private static func loadAPIKeyWithDefaults(forKey keychainKey: String, configKey: String) -> String {
        // First try to load from keychain
        let keychainValue = loadAPIKey(forKey: keychainKey)
        print("🔑 Loading API key for \(configKey): Keychain value = \(keychainValue.isEmpty ? "EMPTY" : "***\(keychainValue.suffix(4))")")
        
        if !keychainValue.isEmpty {
            return keychainValue
        }
        
        // Fall back to default from Secrets.plist
        let defaultValue = loadFromSecretsPlist(key: configKey)
        print("🔑 Secrets.plist default for \(configKey) = \(defaultValue.isEmpty ? "EMPTY" : "***\(defaultValue.suffix(4))")")
        
        // If we have a default value, save it to keychain for future use
        if !defaultValue.isEmpty {
            saveAPIKey(defaultValue, forKey: keychainKey)
            print("🔑 Saved default value to keychain for \(configKey)")
        }
        
        return defaultValue
    }
    
    /// Load API key from Secrets.plist
    private static func loadFromSecretsPlist(key: String) -> String {
        guard let path = Bundle.main.path(forResource: "Secrets", ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: path),
              let value = plist[key] as? String else {
            return ""
        }
        return value
    }
    }


enum PredictionFrequency: String, CaseIterable {
    case fifteenMinutes = "15min"
    case thirtyMinutes = "30min"
    case oneHour = "1hour"
    case twoHours = "2hours"
    case fourHours = "4hours"
    case daily = "daily"
    
    var displayName: String {
        switch self {
        case .fifteenMinutes: return "Every 15 minutes"
        case .thirtyMinutes: return "Every 30 minutes"
        case .oneHour: return "Every hour"
        case .twoHours: return "Every 2 hours"
        case .fourHours: return "Every 4 hours"
        case .daily: return "Daily"
        }
    }
    
    var timeInterval: TimeInterval {
        switch self {
        case .fifteenMinutes: return 15 * 60
        case .thirtyMinutes: return 30 * 60
        case .oneHour: return 60 * 60
        case .twoHours: return 2 * 60 * 60
        case .fourHours: return 4 * 60 * 60
        case .daily: return 24 * 60 * 60
        }
    }
}

enum NotificationStyle: String, CaseIterable {
    case push = "push"
    case banner = "banner"
    case silent = "silent"
    
    var displayName: String {
        switch self {
        case .push: return "Push Notification"
        case .banner: return "In-App Banner"
        case .silent: return "Silent (Badge Only)"
        }
    }
}

enum AlertFrequency: String, CaseIterable {
    case fifteenMinutes = "15min"
    case thirtyMinutes = "30min"
    case oneHour = "1hour"
    case twoHours = "2hours"
    case fourHours = "4hours"
    case daily = "daily"
    
    var displayName: String {
        switch self {
        case .fifteenMinutes: return "Every 15 minutes"
        case .thirtyMinutes: return "Every 30 minutes"
        case .oneHour: return "Every hour"
        case .twoHours: return "Every 2 hours"
        case .fourHours: return "Every 4 hours"
        case .daily: return "Daily"
        }
    }
    
    var timeInterval: TimeInterval {
        switch self {
        case .fifteenMinutes: return 15 * 60
        case .thirtyMinutes: return 30 * 60
        case .oneHour: return 60 * 60
        case .twoHours: return 2 * 60 * 60
        case .fourHours: return 4 * 60 * 60
        case .daily: return 24 * 60 * 60
        }
    }
}


