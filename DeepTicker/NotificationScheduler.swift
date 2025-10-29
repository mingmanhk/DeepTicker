import Foundation
import UserNotifications

class NotificationScheduler {
    static let shared = NotificationScheduler()
    
    private init() {}
    
    func requestAuthorization() async throws {
        let center = UNUserNotificationCenter.current()
        try await center.requestAuthorization(options: [.alert, .sound, .badge])
    }
    
    func scheduleBackgroundChecks() {
        BackgroundTaskManager.shared.scheduleNext()
    }
    
    func evaluateAndNotify(confidenceDelta: Double, riskDelta: Double, profitDelta: Double) async {
        let settings = NotificationSettings.shared
        
        if settings.enableConfidenceAlerts, confidenceDelta >= settings.confidenceChangeThreshold {
            await makeNotification(title: "Confidence Change",
                                   body: "Confidence increased by \(confidenceDelta)")
        }
        
        if settings.enableRiskAlerts, riskDelta >= settings.riskLevelChangeThreshold {
            await makeNotification(title: "Risk Change",
                                   body: "Risk increased by \(riskDelta)")
        }
        
        if settings.enableProfitAlerts, profitDelta >= settings.profitLikelihoodChangeThreshold {
            await makeNotification(title: "Profit Change",
                                   body: "Profit increased by \(profitDelta)")
        }
    }
    
    private func makeNotification(title: String, body: String) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString,
                                            content: content,
                                            trigger: trigger)
        
        let center = UNUserNotificationCenter.current()
        try? await center.add(request)
    }
}
