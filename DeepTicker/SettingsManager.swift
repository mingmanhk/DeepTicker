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
    
    private init() {
        // API Keys from Keychain with fallback to Config.plist defaults
        self.alphaVantageAPIKey = Self.loadAPIKeyWithDefaults(forKey: KeychainKey.alphaVantage, configKey: .alphaVantageAPI)
        self.deepSeekAPIKey = Self.loadAPIKeyWithDefaults(forKey: KeychainKey.deepSeek, configKey: .deepSeekAPI)
        self.openAIAPIKey = Self.loadAPIKeyWithDefaults(forKey: KeychainKey.openAI, configKey: .openAIAPI)
        self.qwenAPIKey = Self.loadAPIKeyWithDefaults(forKey: KeychainKey.qwen, configKey: .qwenAPI)
        self.openRouterAPIKey = Self.loadAPIKeyWithDefaults(forKey: KeychainKey.openRouter, configKey: .openRouterAPI)
        
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
    
    /// Load API key from Keychain, falling back to Config.plist default if not found
    private static func loadAPIKeyWithDefaults(forKey keychainKey: String, configKey: ConfigurationKey) -> String {
        // First try to load from keychain
        let keychainValue = loadAPIKey(forKey: keychainKey)
        if !keychainValue.isEmpty {
            return keychainValue
        }
        
        // Fall back to default from Config.plist
        let defaultValue = ConfigurationManager.shared.getAPIKey(for: configKey)
        
        // If we have a default value, save it to keychain for future use
        if !defaultValue.isEmpty {
            saveAPIKey(defaultValue, forKey: keychainKey)
        }
        
        return defaultValue
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
