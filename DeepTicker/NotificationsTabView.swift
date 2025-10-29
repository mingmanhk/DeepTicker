// NotificationsTabView.swift

import SwiftUI

struct NotificationsTabView: View {
    @AppStorage("notifications_frequency_minutes") private var frequencyMinutes: Int = 60
    @AppStorage("notifications_ai_confidence_threshold") private var aiConfidenceThreshold: Double = 5
    @AppStorage("notifications_risk_level_threshold") private var riskLevelThreshold: Double = 5
    @AppStorage("notifications_profit_likelihood_threshold") private var profitLikelihoodThreshold: Double = 5

    @AppStorage("notifications_enable_ai_confidence") private var enableAIConfidence: Bool = true
    @AppStorage("notifications_enable_risk_level") private var enableRiskLevel: Bool = false
    @AppStorage("notifications_enable_profit_likelihood") private var enableProfitLikelihood: Bool = true

    var body: some View {
        NavigationStack {
            Form {
                Section("Frequency") {
                    Picker("How often", selection: $frequencyMinutes) {
                        Text("Every 15 min").tag(15)
                        Text("Hourly").tag(60)
                        Text("Daily").tag(60 * 24)
                    }
                    .pickerStyle(.segmented)
                }

                Section("Thresholds") {
                    VStack(alignment: .leading) {
                        HStack { Text("AI Confidence Δ %"); Spacer(); Text("\(Int(aiConfidenceThreshold))%") }
                        Slider(value: $aiConfidenceThreshold, in: 1...50, step: 1)
                    }
                    VStack(alignment: .leading) {
                        HStack { Text("Risk level Δ"); Spacer(); Text("\(Int(riskLevelThreshold))") }
                        Slider(value: $riskLevelThreshold, in: 1...20, step: 1)
                    }
                    VStack(alignment: .leading) {
                        HStack { Text("Profit likelihood Δ %"); Spacer(); Text("\(Int(profitLikelihoodThreshold))%") }
                        Slider(value: $profitLikelihoodThreshold, in: 1...50, step: 1)
                    }
                }

                Section("Alerts") {
                    Toggle("AI Confidence", isOn: $enableAIConfidence)
                    Toggle("Risk level", isOn: $enableRiskLevel)
                    Toggle("Profit likelihood", isOn: $enableProfitLikelihood)
                }

                Section("Data Transparency") {
                    VStack(alignment: .leading, spacing: AppDesignSystem.Spacing.sm) {
                        Text("Data Sources")
                            .font(AppDesignSystem.Typography.subheadline)
                            .fontWeight(.medium)
                        
                        DataSourceStatusView()
                        
                        Text("Primary: Yahoo Finance, Fallback: Alpha Vantage, Cache: Last resort")
                            .font(AppDesignSystem.Typography.caption2)
                            .foregroundColor(AppDesignSystem.Colors.secondary)
                    }
                    .padding(.vertical, AppDesignSystem.Spacing.xs)
                }

                Section {
                    Button(role: .none) { scheduleNotifications() } label: { Text("Save & Schedule") }
                }
            }
            .navigationTitle("Notifications")
        }
    }

    private func scheduleNotifications() {
        // Stub: integrate with BGTaskScheduler or UNUserNotificationCenter
        // Use stored thresholds and frequency to schedule background checks.
    }
}

// MARK: - Data Source Status Component

private struct DataSourceStatusView: View {
    @StateObject private var stockService = DefaultStockPriceService()
    @ObservedObject private var dataRefreshManager = DataRefreshManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppDesignSystem.Spacing.xs) {
            ForEach(StockQuote.DataSource.allCases.sorted(by: { $0.priority < $1.priority }), id: \.self) { source in
                HStack {
                    Image(systemName: iconFor(source))
                        .font(.caption)
                        .foregroundColor(colorFor(source))
                        .frame(width: 16)
                    
                    Text(source.displayName)
                        .font(AppDesignSystem.Typography.caption1)
                    
                    Spacer()
                    
                    Text(statusFor(source))
                        .font(AppDesignSystem.Typography.caption2)
                        .foregroundColor(colorFor(source))
                        .fontWeight(.medium)
                }
                .padding(.vertical, 2)
            }
        }
    }
    
    private func iconFor(_ source: StockQuote.DataSource) -> String {
        switch source {
        case .yahooFinance: return "network"
        case .alphaVantage: return "server.rack"
        case .cache: return "externaldrive.fill"
        }
    }
    
    private func colorFor(_ source: StockQuote.DataSource) -> Color {
        switch source {
        case .yahooFinance: return .green
        case .alphaVantage: return stockService.isAlphaVantageAvailable ? .blue : .orange
        case .cache: return .secondary
        }
    }
    
    private func statusFor(_ source: StockQuote.DataSource) -> String {
        switch source {
        case .yahooFinance: return "Active"
        case .alphaVantage: return stockService.isAlphaVantageAvailable ? "Available" : "Limited"
        case .cache: return "Backup"
        }
    }
}

#Preview {
    NotificationsTabView()
}
