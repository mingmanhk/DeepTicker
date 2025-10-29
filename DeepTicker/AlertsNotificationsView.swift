import SwiftUI

struct AlertsNotificationsView: View {
    @StateObject private var settings = NotificationSettings.shared
    private let scheduler = NotificationSchedulerWrapper()

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Frequency")) {
                    Picker("Check Frequency", selection: $settings.frequency) {
                        ForEach(NotificationSettings.Frequency.allCases) { freq in
                            Text(freq.title).tag(freq)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: settings.frequency) { _, newValue in
                        scheduler.updateSchedule(every: newValue.interval)
                    }
                }

                Section(header: Text("Thresholds")) {
                    VStack(alignment: .leading) {
                        HStack {
                            Text("AI Confidence % change")
                            Spacer()
                            Text("\(Int(settings.confidenceChangeThreshold))%")
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $settings.confidenceChangeThreshold, in: 0...100, step: 1)
                    }
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Risk level change")
                            Spacer()
                            Text("\(Int(settings.riskLevelChangeThreshold))")
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $settings.riskLevelChangeThreshold, in: 0...5, step: 1)
                    }
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Profit likelihood % change")
                            Spacer()
                            Text("\(Int(settings.profitLikelihoodChangeThreshold))%")
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $settings.profitLikelihoodChangeThreshold, in: 0...100, step: 1)
                    }
                }

                Section(header: Text("Alerts")) {
                    Toggle("AI Confidence Alerts", isOn: $settings.enableConfidenceAlerts)
                    Toggle("Risk Alerts", isOn: $settings.enableRiskAlerts)
                    Toggle("Profit Likelihood Alerts", isOn: $settings.enableProfitAlerts)
                }

                Section(footer: Text("Background checks run on the selected frequency. Notifications are sent when thresholds are breached.")) {
                    Button {
                        Task { await scheduler.requestAuthorization() }
                    } label: {
                        Label("Enable Notifications", systemImage: "bell.badge")
                    }
                }
            }
            .navigationTitle("Alerts & Notifications")
            .task {
                await scheduler.requestAuthorization()
                scheduler.updateSchedule(every: settings.frequency.interval)
            }
        }
    }
}

// A wrapper to make NotificationScheduler an ObservableObject for the view
@MainActor
class NotificationSchedulerWrapper {
    private let scheduler = NotificationScheduler.shared

    func requestAuthorization() async {
        try? await scheduler.requestAuthorization()
    }

    func updateSchedule(every interval: TimeInterval) {
        scheduler.scheduleBackgroundChecks()
    }
}

#Preview {
    AlertsNotificationsView()
}
