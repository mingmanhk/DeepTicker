import SwiftUI

struct AlertsAndNotificationsView: View {
    @StateObject private var settings = NotificationSettings.shared
    
    var body: some View {
        Form {
            Section(header: Text("Frequency")) {
                Picker("Frequency", selection: $settings.frequency) {
                    ForEach(NotificationSettings.Frequency.allCases, id: \.self) { frequency in
                        switch frequency {
                        case .fifteenMinutes:
                            Text("Every 15 minutes").tag(frequency)
                        case .hourly:
                            Text("Hourly").tag(frequency)
                        case .daily:
                            Text("Daily").tag(frequency)
                        }
                    }
                }
#if os(iOS)
                .pickerStyle(.segmented)
#endif
            }
            
            Section(header: Text("Thresholds")) {
                HStack {
                    Slider(value: $settings.confidenceChangeThreshold, in: 0...100, step: 1)
                    Text("\(Int(settings.confidenceChangeThreshold))%")
                        .frame(width: 50, alignment: .trailing)
                }
                HStack {
                    Slider(value: $settings.riskLevelChangeThreshold, in: 0...5, step: 1)
                    Text("\(Int(settings.riskLevelChangeThreshold))")
                        .frame(width: 30, alignment: .trailing)
                }
                HStack {
                    Slider(value: $settings.profitLikelihoodChangeThreshold, in: 0...100, step: 1)
                    Text("\(Int(settings.profitLikelihoodChangeThreshold))%")
                        .frame(width: 50, alignment: .trailing)
                }
            }
            
            Section(header: Text("Alert Types")) {
                Toggle("Enable Confidence Alerts", isOn: $settings.enableConfidenceAlerts)
                Toggle("Enable Risk Alerts", isOn: $settings.enableRiskAlerts)
                Toggle("Enable Profit Alerts", isOn: $settings.enableProfitAlerts)
            }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Alerts & Notifications").font(.headline)
            }
        }
    }
}

#Preview {
    AlertsAndNotificationsView()
}
