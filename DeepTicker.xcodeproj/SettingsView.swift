import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    @EnvironmentObject var portfolioManager: PortfolioManager
    @State private var showingApiKeyAlert = false
    @State private var newApiKey = ""
    
    var body: some View {
        NavigationView {
            Form {
                // App Information Section
                Section {
                    HStack {
                        Image(systemName: "chart.line.uptrend.xyaxis.circle.fill")
                            .font(.title2)
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading) {
                            Text("DeepTicker")
                                .font(.headline)
                                .fontWeight(.bold)
                            
                            Text("AI-Powered Stock Portfolio Tracker")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Text("v1.0")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                }
                
                // Update Frequency Section
                Section("Data Updates") {
                    Picker("Update Frequency", selection: $settingsManager.updateFrequency) {
                        Text("Every 15 minutes").tag(TimeInterval(900))
                        Text("Every 30 minutes").tag(TimeInterval(1800))
                        Text("Every hour").tag(TimeInterval(3600))
                        Text("Every 2 hours").tag(TimeInterval(7200))
                    }
                    .onChange(of: settingsManager.updateFrequency) { newValue in
                        portfolioManager.updateFrequency(newValue)
                        settingsManager.saveSettings()
                    }
                    
                    HStack {
                        Text("Last Updated")
                        Spacer()
                        Text(formatLastUpdateTime())
                            .foregroundColor(.secondary)
                    }
                }
                
                // Alerts Section
                Section("Alerts & Notifications") {
                    Toggle("Enable Alerts", isOn: $settingsManager.alertConfig.enabledGlobal)
                        .onChange(of: settingsManager.alertConfig.enabledGlobal) { _ in
                            settingsManager.saveSettings()
                        }
                    
                    if settingsManager.alertConfig.enabledGlobal {
                        Picker("Alert Style", selection: $settingsManager.alertConfig.alertStyle) {
                            ForEach(AlertStyle.allCases, id: \.self) { style in
                                Text(style.displayName).tag(style)
                            }
                        }
                        .onChange(of: settingsManager.alertConfig.alertStyle) { _ in
                            settingsManager.saveSettings()
                        }
                        
                        HStack {
                            Text("Price Change Threshold")
                            Spacer()
                            Text("\(settingsManager.alertConfig.changeThreshold, specifier: "%.1f")%")
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(
                            value: $settingsManager.alertConfig.changeThreshold,
                            in: 1.0...20.0,
                            step: 0.5
                        ) {
                            Text("Change Threshold")
                        }
                        .onChange(of: settingsManager.alertConfig.changeThreshold) { _ in
                            settingsManager.saveSettings()
                        }
                        
                        HStack {
                            Text("AI Confidence Threshold")
                            Spacer()
                            Text("\(Int(settingsManager.alertConfig.confidenceThreshold * 100))%")
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(
                            value: $settingsManager.alertConfig.confidenceThreshold,
                            in: 0.5...1.0,
                            step: 0.05
                        ) {
                            Text("Confidence Threshold")
                        }
                        .onChange(of: settingsManager.alertConfig.confidenceThreshold) { _ in
                            settingsManager.saveSettings()
                        }
                    }
                }
                
                // Per-Stock Alert Settings
                if settingsManager.alertConfig.enabledGlobal && !portfolioManager.stocks.isEmpty {
                    Section("Per-Stock Alerts") {
                        ForEach(portfolioManager.stocks) { stock in
                            HStack {
                                Text(stock.symbol)
                                    .fontWeight(.medium)
                                
                                Spacer()
                                
                                Toggle("", isOn: Binding(
                                    get: {
                                        settingsManager.alertConfig.enabledPerStock[stock.symbol] ?? true
                                    },
                                    set: { newValue in
                                        settingsManager.alertConfig.enabledPerStock[stock.symbol] = newValue
                                        settingsManager.saveSettings()
                                    }
                                ))
                            }
                        }
                    }
                }
                
                // API Configuration Section
                Section("API Configuration") {
                    HStack {
                        Text("Alpha Vantage API")
                        Spacer()
                        Text("Connected")
                            .font(.caption)
                            .foregroundColor(.green)
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                    }
                    
                    HStack {
                        Text("DeepSeek AI API")
                        Spacer()
                        Text("Connected")
                            .font(.caption)
                            .foregroundColor(.green)
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                    }
                    
                    Button("Test API Connections") {
                        testAPIConnections()
                    }
                    .foregroundColor(.blue)
                }
                
                // Appearance Section
                Section("Appearance") {
                    Toggle("Dark Mode", isOn: $settingsManager.isDarkMode)
                        .onChange(of: settingsManager.isDarkMode) { _ in
                            settingsManager.saveSettings()
                        }
                }
                
                // Data Management Section
                Section("Data Management") {
                    Button("Refresh All Data") {
                        Task {
                            await portfolioManager.refreshAllStocks()
                            await portfolioManager.generateAllPredictions()
                        }
                    }
                    .foregroundColor(.blue)
                    .disabled(portfolioManager.isLoading)
                    
                    Button("Clear Predictions Cache") {
                        clearPredictionsCache()
                    }
                    .foregroundColor(.orange)
                    
                    Button("Reset All Settings") {
                        showingResetAlert = true
                    }
                    .foregroundColor(.red)
                }
                
                // About Section
                Section("About") {
                    Link(destination: URL(string: "https://www.alphavantage.co")!) {
                        HStack {
                            Text("Alpha Vantage API")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .foregroundColor(.blue)
                        }
                    }
                    
                    Link(destination: URL(string: "https://platform.deepseek.com")!) {
                        HStack {
                            Text("DeepSeek AI Platform")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .foregroundColor(.blue)
                        }
                    }
                    
                    Button("Privacy Policy") {
                        // Implement privacy policy view
                    }
                    .foregroundColor(.blue)
                    
                    Button("Terms of Service") {
                        // Implement terms of service view
                    }
                    .foregroundColor(.blue)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .alert("Reset Settings", isPresented: $showingResetAlert) {
                Button("Reset", role: .destructive) {
                    resetAllSettings()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will reset all settings to their default values. This action cannot be undone.")
            }
        }
        .preferredColorScheme(settingsManager.isDarkMode ? .dark : .light)
    }
    
    // MARK: - State Variables
    @State private var showingResetAlert = false
    @State private var isTestingAPIs = false
    @State private var apiTestResults = ""
    @State private var showingAPITestResults = false
    
    // MARK: - Private Methods
    private func formatLastUpdateTime() -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: portfolioManager.lastUpdateTime, relativeTo: Date())
    }
    
    private func testAPIConnections() {
        isTestingAPIs = true
        
        Task {
            var results = "API Connection Test Results:\n\n"
            
            // Test Alpha Vantage
            do {
                let _ = try await AlphaVantageManager.shared.fetchQuote(for: "AAPL")
                results += "✅ Alpha Vantage API: Connected successfully\n\n"
            } catch {
                results += "❌ Alpha Vantage API: \(error.localizedDescription)\n\n"
            }
            
            // Test DeepSeek (with a simple portfolio if available)
            if !portfolioManager.stocks.isEmpty {
                do {
                    let _ = try await DeepSeekManager.shared.generatePortfolioAnalysis(for: Array(portfolioManager.stocks.prefix(1)))
                    results += "✅ DeepSeek AI API: Connected successfully\n\n"
                } catch {
                    results += "❌ DeepSeek AI API: \(error.localizedDescription)\n\n"
                }
            } else {
                results += "⚠️ DeepSeek AI API: Add stocks to test AI features\n\n"
            }
            
            await MainActor.run {
                apiTestResults = results
                showingAPITestResults = true
                isTestingAPIs = false
            }
        }
    }
    
    private func clearPredictionsCache() {
        portfolioManager.predictions.removeAll()
        // Clear from UserDefaults as well
        UserDefaults.standard.removeObject(forKey: "SavedPredictions")
    }
    
    private func resetAllSettings() {
        settingsManager.alertConfig = AlertConfig()
        settingsManager.updateFrequency = 1800
        settingsManager.isDarkMode = true
        settingsManager.saveSettings()
    }
}

// MARK: - API Test Results View
struct APITestResultsView: View {
    let results: String
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            ScrollView {
                Text(results)
                    .font(.monospaced(.body)())
                    .padding()
            }
            .navigationTitle("API Test Results")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(SettingsManager())
        .environmentObject(PortfolioManager())
}