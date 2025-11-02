import Foundation
import Combine
import UserNotifications
import UIKit

@MainActor
class NotificationManager: NSObject, ObservableObject {
    static let shared = NotificationManager()
    
    @Published var hasPermission = false
    
    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
        checkPermissionStatus()
    }
    
    func requestPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { [weak self] granted, error in
            if let error = error {
                print("Notification authorization error: \(error)")
            }
            DispatchQueue.main.async {
                self?.hasPermission = granted
            }
            
            if granted {
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        }
    }
    
    func checkPermissionStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                self?.hasPermission = settings.authorizationStatus == .authorized
            }
        }
    }
    
    func scheduleStockAlert(for stock: PortfolioStock, reason: AlertReason) {
        guard hasPermission else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "DeepTicker Alert"
        content.body = createAlertMessage(for: stock, reason: reason)
        content.sound = .default
        content.badge = 1
        
        // Add custom user info
        content.userInfo = [
            "stockSymbol": stock.symbol,
            "alertType": reason.rawValue,
            "price": stock.currentPrice,
            "change": stock.dailyChangePercentage
        ]
        
        // Trigger immediately for testing, or set a delay
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        
        let identifier = "stock-alert-\(stock.symbol)-\(Date().timeIntervalSince1970)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error)")
            }
        }
    }
    
    func schedulePredictionAlert(for stock: PortfolioStock, prediction: DeepSeekManager.StockPrediction) {
        guard hasPermission else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "DeepTicker Prediction"
        content.body = createPredictionAlertMessage(for: stock, prediction: prediction)
        content.sound = .default
        content.badge = 1
        
        content.userInfo = [
            "stockSymbol": stock.symbol,
            "alertType": "prediction",
            "prediction": prediction.prediction.rawValue,
            "confidence": prediction.confidence
        ]
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let identifier = "prediction-alert-\(stock.symbol)-\(Date().timeIntervalSince1970)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling prediction notification: \(error)")
            }
        }
    }
    
    func postAlert(title: String, body: String) async {
        guard hasPermission else { return }
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString,
                                            content: content,
                                            trigger: trigger)
        
        try? await UNUserNotificationCenter.current().add(request)
    }
    
    private func createAlertMessage(for stock: PortfolioStock, reason: AlertReason) -> String {
        let changeText = stock.dailyChange >= 0 ? "up" : "down"
        let changePercent = String(format: "%.2f%%", abs(stock.dailyChangePercentage))
        
        switch reason {
        case .priceChange:
            return "\(stock.symbol) is \(changeText) \(changePercent) today at $\(String(format: "%.2f", stock.currentPrice))"
        case .predictionConfidence:
            return "\(stock.symbol) has a high-confidence prediction. Check the app for details."
        case .healthStatus:
            return "\(stock.symbol) health status has changed. Current price: $\(String(format: "%.2f", stock.currentPrice))"
        }
    }
    
    private func createPredictionAlertMessage(for stock: PortfolioStock, prediction: DeepSeekManager.StockPrediction) -> String {
        let confidencePercent = Int(prediction.confidence * 100)
        let direction = prediction.prediction == .up ? "rise" : prediction.prediction == .down ? "fall" : "remain stable"
        
        return "\(stock.symbol) is predicted to \(direction) with \(confidencePercent)% confidence."
    }
    
    func clearAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
#if swift(>=5.9)
        if #available(iOS 17.0, *) {
            UNUserNotificationCenter.current().setBadgeCount(0, withCompletionHandler: nil)
        } else {
            UIApplication.shared.applicationIconBadgeNumber = 0
        }
#else
        UIApplication.shared.applicationIconBadgeNumber = 0
#endif
    }
    
    func clearNotifications(for stockSymbol: String) {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let identifiersToRemove = requests.compactMap { request in
                if let symbol = request.content.userInfo["stockSymbol"] as? String,
                   symbol == stockSymbol {
                    return request.identifier
                }
                return nil
            }
            
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiersToRemove)
        }
    }
}

enum AlertReason: String {
    case priceChange = "price_change"
    case predictionConfidence = "prediction_confidence"
    case healthStatus = "health_status"
}

// MARK: - UNUserNotificationCenterDelegate
extension NotificationManager: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show notifications even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        // Handle notification tap
        let userInfo = response.notification.request.content.userInfo
        
        if let stockSymbol = userInfo["stockSymbol"] as? String {
            // Navigate to stock details or portfolio view
            NotificationCenter.default.post(name: .stockNotificationTapped, object: stockSymbol)
        }
        
        completionHandler()
    }
}

extension Notification.Name {
    static let stockNotificationTapped = Notification.Name("stockNotificationTapped")
}

