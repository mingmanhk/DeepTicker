import SwiftUI

// MARK: - Main Settings View (Redesigned)
struct SettingsView: View {
    
    enum SettingsTab {
        case general, accounts, advanced
    }
    
    @State private var selectedTab: SettingsTab = .general

    var body: some View {
        TabView(selection: $selectedTab) {
            // MARK: General Tab
            NavigationStack {
                GeneralSettingsView()
            }
            .tabItem {
                Label("General", systemImage: "gear")
            }
            .tag(SettingsTab.general)
            
            // MARK: Accounts & APIs Tab
            NavigationStack {
                AccountsSettingsView()
            }
            .tabItem {
                Label("Accounts & APIs", systemImage: "key.fill")
            }
            .tag(SettingsTab.accounts)
            
            // MARK: Advanced Tab
            NavigationStack {
                AdvancedSettingsView()
            }
            .tabItem {
                Label("Advanced", systemImage: "slider.horizontal.3")
            }
            .tag(SettingsTab.advanced)
        }
    }
}

// MARK: - General Settings Screen
private struct GeneralSettingsView: View {
    @StateObject private var settingsManager = SettingsManager.shared
    @StateObject private var notificationSettings = NotificationSettings.shared
    @StateObject private var dataRefreshManager = DataRefreshManager.shared
    
    var body: some View {
        Form {
            Section(header: Text("Appearance")) {
                Toggle("Show Mascot", isOn: $settingsManager.enableMascot)
            }
            
            Section(header: Text("Notifications")) {
                Picker("Frequency", selection: $notificationSettings.frequency) {
                    ForEach(NotificationSettings.Frequency.allCases) { frequency in
                        Text(frequency.title).tag(frequency)
                    }
                }
                .pickerStyle(.menu)
                
                Toggle("Enable Confidence Alerts", isOn: $notificationSettings.enableConfidenceAlerts)
                Toggle("Enable Risk Alerts", isOn: $notificationSettings.enableRiskAlerts)
                Toggle("Enable Profit Alerts", isOn: $notificationSettings.enableProfitAlerts)
            }
            
            Section(header: Text("Data Refresh"), footer: Text("Set how often the app fetches new data in the background.")) {
                ForEach(DataType.allCases, id: \.self) { dataType in
                    Picker(dataType.displayName, selection: Binding(
                        get: { dataRefreshManager.refreshSettings[dataType, default: .manual] },
                        set: { dataRefreshManager.setRefreshFrequency($0, for: dataType) }
                    )) {
                        ForEach(RefreshFrequency.allCases, id: \.self) { frequency in
                            Text(frequency.displayName).tag(frequency)
                        }
                    }
                }
            }
        }
        .navigationTitle("General Settings")
    }
}

// MARK: - Accounts & APIs Settings Screen
private struct AccountsSettingsView: View {
    @StateObject private var settingsManager = SettingsManager.shared
    
    var body: some View {
        Form {
            Section(header: Text("API Keys"), footer: Text("API keys are stored securely in the Keychain.")) {
                ForEach(ConfigurationKey.allCases, id: \.self) { configKey in
                    EditableAPIKeyRow(configKey: configKey, settingsManager: settingsManager)
                }
            }
        }
        .navigationTitle("Accounts & APIs")
    }
}

// MARK: - Advanced Settings Screen
private struct AdvancedSettingsView: View {
    var body: some View {
        Form {
            Section("AI Customization") {
                NavigationLink("Prompt Templates") {
                    AIPromptTemplatesView()
                }
            }
            
            #if DEBUG
            Section("Developer") {
                NavigationLink("Debugging Tools") {
                    DeveloperToolsView()
                }
            }
            #endif
        }
        .navigationTitle("Advanced")
    }
}


// MARK: - Detail Views for Navigation

private struct AIPromptTemplatesView: View {
    @StateObject private var promptManager = AIPromptManager.shared
    
    var body: some View {
        Form {
            Section("Performance & Risk Analysis") {
                PromptEditor(title: "Profit Confidence Prompt", text: $promptManager.analyzeProfitConfidencePrompt)
                PromptEditor(title: "Risk Analysis Prompt", text: $promptManager.analyzeRiskPrompt)
            }
            
            Section("Prediction Modeling") {
                PromptEditor(title: "Prediction Prompt", text: $promptManager.analyzePredictionPrompt)
            }
            
            Section("Market Briefing") {
                PromptEditor(title: "Portfolio Summary Prompt", text: $promptManager.analyzePortfolioPrompt)
            }
            
            Section {
                Button("Reset All Prompts to Default", role: .destructive) {
                    promptManager.resetToDefaults()
                }
            }
        }
        .navigationTitle("AI Prompt Templates")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#if DEBUG
private struct DeveloperToolsView: View {
    @StateObject private var debugSettings = DebugSettings.load()
    @StateObject private var cacheManager = SmartCacheManager.shared
    
    var body: some View {
        Form {
            Section("Debug Console") {
                Toggle("Enable Debug Console", isOn: $debugSettings.debugConsoleEnabled)
                    .onChange(of: debugSettings.debugConsoleEnabled) { _, _ in debugSettings.save() }

                if debugSettings.debugConsoleEnabled {
                    NavigationLink("Open Debug Console") {
                        DebugConsoleView()
                    }
                }
            }
            
            Section("Cache Management") {
                CacheManagementSection(cacheManager: cacheManager)
            }
        }
        .navigationTitle("Developer Tools")
        .navigationBarTitleDisplayMode(.inline)
    }
}
#endif


// MARK: - Reusable Components (some are modified for the new design)

private struct EditableAPIKeyRow: View {
    let configKey: ConfigurationKey
    @ObservedObject var settingsManager: SettingsManager
    @Environment(\.openURL) var openURL
    
    private var apiKeyBinding: Binding<String> {
        Binding(
            get: {
                switch configKey {
                case .alphaVantageAPI: return settingsManager.alphaVantageAPIKey
                case .deepSeekAPI: return settingsManager.deepSeekAPIKey
                case .openAIAPI: return settingsManager.openAIAPIKey
                case .qwenAPI: return settingsManager.qwenAPIKey
                case .openRouterAPI: return settingsManager.openRouterAPIKey
                }
            },
            set: { newValue in
                switch configKey {
                case .alphaVantageAPI: settingsManager.alphaVantageAPIKey = newValue
                case .deepSeekAPI: settingsManager.deepSeekAPIKey = newValue
                case .openAIAPI: settingsManager.openAIAPIKey = newValue
                case .qwenAPI: settingsManager.qwenAPIKey = newValue
                case .openRouterAPI: settingsManager.openRouterAPIKey = newValue
                }
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppDesignSystem.Spacing.sm) {
            Text(configKey.displayName)
            
            HStack {
                SecureField("Enter API Key", text: apiKeyBinding)
                
                if !apiKeyBinding.wrappedValue.isEmpty {
                    Button(action: { apiKeyBinding.wrappedValue = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            
            if let urlString = configKey.helpURL, let url = URL(string: urlString) {
                Button("Get \(configKey.displayName)") {
                    openURL(url)
                }
                .font(.caption)
                .padding(.top, 2)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct PromptEditor: View {
    let title: String
    @Binding var text: String
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(title).font(.caption).foregroundColor(.secondary)
            TextEditor(text: $text)
                .frame(height: 120)
                .font(.body)
        }
    }
}

#if DEBUG
private struct CacheManagementSection: View {
    @ObservedObject var cacheManager: SmartCacheManager
    @State private var cacheInfo: CacheInfo?
    
    var body: some View {
        VStack(spacing: AppDesignSystem.Spacing.md) {
            if let info = cacheInfo {
                VStack {
                    HStack {
                        Text("Size:")
                        Spacer()
                        Text(formatBytes(info.totalSize))
                    }
                    HStack {
                        Text("Entries:")
                        Spacer()
                        Text("\(info.entryCount)")
                    }
                    HStack {
                        Text("Hit Rate:")
                        Spacer()
                        Text("\((info.hitRate * 100).formatted(.number.precision(.fractionLength(1))))%")
                    }
                }
                .font(.caption)
                
            } else {
                Text("Loading cache info...")
            }
            
            HStack {
                Spacer()
                Button("Refresh", action: { Task { await refreshCacheInfo() } })
                Spacer()
                Button("Clear All", role: .destructive, action: { Task { await cacheManager.clear(); await refreshCacheInfo() } })
                Spacer()
            }
            .buttonStyle(.bordered)
            .padding(.top, 4)
        }
        .task { await refreshCacheInfo() }
    }
    
    private func refreshCacheInfo() async {
        cacheInfo = await cacheManager.getCacheInfo()
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
#endif
