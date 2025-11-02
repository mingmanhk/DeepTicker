import Foundation
import Combine

@MainActor
final class NotificationSettings: ObservableObject {
    enum Frequency: String, CaseIterable, Identifiable, Codable {
        case fifteenMinutes = "fifteenMinutes"
        case hourly = "hourly"
        case daily = "daily"
        
        var id: String { rawValue }
        
        var title: String {
            switch self {
            case .fifteenMinutes: return "15 Mins"
            case .hourly: return "Hourly"
            case .daily: return "Daily"
            }
        }
        
        var interval: TimeInterval {
            switch self {
            case .fifteenMinutes: return 15 * 60
            case .hourly: return 60 * 60
            case .daily: return 24 * 60 * 60
            }
        }
    }
    
    static let shared = NotificationSettings()
    
    @Published var frequency: Frequency {
        didSet {
            UserDefaults.standard.set(frequency.rawValue, forKey: Keys.NOTIF_FREQ.rawValue)
        }
    }
    
    @Published var enableConfidenceAlerts: Bool {
        didSet {
            UserDefaults.standard.set(enableConfidenceAlerts, forKey: Keys.NOTIF_ENABLE_CONF.rawValue)
        }
    }
    
    @Published var enableRiskAlerts: Bool {
        didSet {
            UserDefaults.standard.set(enableRiskAlerts, forKey: Keys.NOTIF_ENABLE_RISK.rawValue)
        }
    }
    
    @Published var enableProfitAlerts: Bool {
        didSet {
            UserDefaults.standard.set(enableProfitAlerts, forKey: Keys.NOTIF_ENABLE_PROFIT.rawValue)
        }
    }
    
    @Published var confidenceChangeThreshold: Double {
        didSet {
            UserDefaults.standard.set(confidenceChangeThreshold, forKey: Keys.NOTIF_CONF_THRESH.rawValue)
        }
    }
    
    @Published var riskLevelChangeThreshold: Double {
        didSet {
            UserDefaults.standard.set(riskLevelChangeThreshold, forKey: Keys.NOTIF_RISK_THRESH.rawValue)
        }
    }
    
    @Published var profitLikelihoodChangeThreshold: Double {
        didSet {
            UserDefaults.standard.set(profitLikelihoodChangeThreshold, forKey: Keys.NOTIF_PROFIT_THRESH.rawValue)
        }
    }
    
    var frequencyMinutes: Int {
        switch frequency {
        case .fifteenMinutes:
            return 15
        case .hourly:
            return 60
        case .daily:
            return 1440
        }
    }
    
    private init() {
        let freqRaw = UserDefaults.standard.string(forKey: Keys.NOTIF_FREQ.rawValue) ?? Frequency.hourly.rawValue
        frequency = Frequency(rawValue: freqRaw) ?? .hourly
        
        enableConfidenceAlerts = UserDefaults.standard.object(forKey: Keys.NOTIF_ENABLE_CONF.rawValue) as? Bool ?? false
        enableRiskAlerts = UserDefaults.standard.object(forKey: Keys.NOTIF_ENABLE_RISK.rawValue) as? Bool ?? false
        enableProfitAlerts = UserDefaults.standard.object(forKey: Keys.NOTIF_ENABLE_PROFIT.rawValue) as? Bool ?? false
        
        confidenceChangeThreshold = UserDefaults.standard.object(forKey: Keys.NOTIF_CONF_THRESH.rawValue) as? Double ?? 5
        riskLevelChangeThreshold = UserDefaults.standard.object(forKey: Keys.NOTIF_RISK_THRESH.rawValue) as? Double ?? 1
        profitLikelihoodChangeThreshold = UserDefaults.standard.object(forKey: Keys.NOTIF_PROFIT_THRESH.rawValue) as? Double ?? 5
    }
    
    private enum Keys: String {
        case NOTIF_FREQ
        case NOTIF_ENABLE_CONF
        case NOTIF_ENABLE_RISK
        case NOTIF_ENABLE_PROFIT
        case NOTIF_CONF_THRESH
        case NOTIF_RISK_THRESH
        case NOTIF_PROFIT_THRESH
    }
}
