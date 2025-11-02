import SwiftUI
import UserNotifications

struct NotificationsTabView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    @StateObject private var notificationManager = NotificationManager.shared
    @State private var deliveredNotifications: [UNNotification] = []
    @State private var pendingNotifications: [UNNotificationRequest] = []
    @State private var showingPermissionAlert = false
    
    var body: some View {
        NavigationView {
            List {
                // Notification Settings Section
                Section("Notification Settings") {
                    HStack {
                        Image(systemName: notificationManager.hasPermission ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(notificationManager.hasPermission ? .green : .red)
                        Text("Notifications Permission")
                        Spacer()
                        if !notificationManager.hasPermission {
                            Button("Enable") {
                                notificationManager.requestPermissions()
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        }
                    }
                    
                    Toggle("Alerts Enabled", isOn: $settingsManager.alertsEnabled)
                        .disabled(!notificationManager.hasPermission)
                    
                    if settingsManager.alertsEnabled && notificationManager.hasPermission {
                        HStack {
                            Text("Alert Frequency")
                            Spacer()
                            Picker("Alert Frequency", selection: $settingsManager.alertFrequency) {
                                ForEach(AlertFrequency.allCases, id: \.self) { frequency in
                                    Text(frequency.displayName).tag(frequency)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Confidence Threshold")
                                Spacer()
                                Text("\(Int(settingsManager.confidenceThreshold * 100))%")
                                    .foregroundStyle(.secondary)
                            }
                            Slider(value: $settingsManager.confidenceThreshold, in: 0...1, step: 0.05)
                        }
                        
                        Toggle("Risk Level Alerts", isOn: $settingsManager.riskLevelAlertsEnabled)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Profit Likelihood Threshold")
                                Spacer()
                                Text("\(Int(settingsManager.profitLikelihoodThreshold * 100))%")
                                    .foregroundStyle(.secondary)
                            }
                            Slider(value: $settingsManager.profitLikelihoodThreshold, in: 0...1, step: 0.05)
                        }
                    }
                }
                
                // Active Notifications Section
                if notificationManager.hasPermission {
                    Section("Pending Notifications") {
                        if pendingNotifications.isEmpty {
                            Text("No pending notifications")
                                .foregroundStyle(.secondary)
                                .italic()
                        } else {
                            ForEach(pendingNotifications.indices, id: \.self) { index in
                                NotificationRow(notification: pendingNotifications[index])
                            }
                        }
                    }
                    
                    Section("Recent Notifications") {
                        if deliveredNotifications.isEmpty {
                            Text("No recent notifications")
                                .foregroundStyle(.secondary)
                                .italic()
                        } else {
                            ForEach(deliveredNotifications.indices, id: \.self) { index in
                                DeliveredNotificationRow(notification: deliveredNotifications[index])
                            }
                        }
                    }
                    
                    // Actions Section
                    Section("Actions") {
                        Button("Clear All Notifications") {
                            notificationManager.clearAllNotifications()
                            loadNotifications()
                        }
                        .foregroundStyle(.red)
                        
                        Button("Refresh") {
                            loadNotifications()
                        }
                    }
                }
            }
            .navigationTitle("Alerts & Notifications")
            .refreshable {
                loadNotifications()
            }
            .onAppear {
                loadNotifications()
            }
            .onChange(of: notificationManager.hasPermission) {
                if notificationManager.hasPermission {
                    loadNotifications()
                }
            }
        }
    }
    
    private func loadNotifications() {
        guard notificationManager.hasPermission else { return }
        
        // Load pending notifications
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            DispatchQueue.main.async {
                self.pendingNotifications = requests
            }
        }
        
        // Load delivered notifications
        UNUserNotificationCenter.current().getDeliveredNotifications { notifications in
            DispatchQueue.main.async {
                self.deliveredNotifications = notifications
            }
        }
    }
}

struct NotificationRow: View {
    let notification: UNNotificationRequest
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(notification.content.title)
                    .font(.headline)
                Spacer()
                if let stockSymbol = notification.content.userInfo["stockSymbol"] as? String {
                    Text(stockSymbol)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(.blue.opacity(0.2))
                        .cornerRadius(4)
                }
            }
            
            Text(notification.content.body)
                .font(.body)
                .foregroundStyle(.secondary)
            
            if let trigger = notification.trigger as? UNTimeIntervalNotificationTrigger {
                Text("Scheduled for: \(trigger.nextTriggerDate()?.formatted(date: .abbreviated, time: .shortened) ?? "Unknown")")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
    }
}

struct DeliveredNotificationRow: View {
    let notification: UNNotification
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(notification.request.content.title)
                    .font(.headline)
                Spacer()
                if let stockSymbol = notification.request.content.userInfo["stockSymbol"] as? String {
                    Text(stockSymbol)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(.green.opacity(0.2))
                        .cornerRadius(4)
                }
            }
            
            Text(notification.request.content.body)
                .font(.body)
                .foregroundStyle(.secondary)
            
            Text("Delivered: \(notification.date.formatted(date: .abbreviated, time: .shortened))")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    NotificationsTabView()
        .environmentObject(SettingsManager.shared)
}
