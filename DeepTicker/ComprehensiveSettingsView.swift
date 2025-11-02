import SwiftUI

import SwiftUI
import UIKit

struct ComprehensiveSettingsView: View {
    @StateObject private var configManager = SecureConfigurationManager.shared
    @StateObject private var dataManager = DataManager.shared
    @State private var expandedSections: Set<SettingsSection> = [.apiKeys]
    @State private var selectedPrompt: PromptType?

    @State private var showingClearCacheAlert = false
    
    enum SettingsSection: String, CaseIterable, Identifiable {
        case apiKeys = "Data & API Settings"
        case aiPrompts = "AI Prompt Templates"  
        case appPreferences = "App Preferences"
        case supportFeedback = "Support & Feedback"
        case developerTools = "Developer Tools"
        
        var id: String { rawValue }
        
        var icon: String {
            switch self {
            case .apiKeys: return "key"
            case .aiPrompts: return "brain.head.profile"
            case .appPreferences: return "gearshape"
            case .supportFeedback: return "envelope"
            case .developerTools: return "hammer"
            }
        }
        
        var color: Color {
            switch self {
            case .apiKeys: return .blue
            case .aiPrompts: return .purple
            case .appPreferences: return .green
            case .supportFeedback: return .orange
            case .developerTools: return .red
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(SettingsSection.allCases) { section in
                    settingsSectionView(for: section)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Settings")
            .sheet(item: $selectedPrompt) { promptType in
                PromptEditorSheet(promptType: promptType)
                    .environmentObject(configManager)
            }

            .alert("Clear Cache", isPresented: $showingClearCacheAlert) {
                Button("Clear", role: .destructive) {
                    dataManager.clearCache()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will clear all cached data and force fresh downloads on next refresh.")
            }
        }
    }
    
    // MARK: - Settings Sections
    
    @ViewBuilder
    private func settingsSectionView(for section: SettingsSection) -> some View {
        let isExpanded = expandedSections.contains(section)
        
        Section {
            // Section Header with Expand/Collapse
            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    if isExpanded {
                        expandedSections.remove(section)
                    } else {
                        expandedSections.insert(section)
                    }
                }
            } label: {
                HStack {
                    Image(systemName: section.icon)
                        .foregroundStyle(section.color)
                        .frame(width: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(section.rawValue)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        
                        Text(sectionSubtitle(for: section))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .animation(.easeInOut(duration: 0.2), value: isExpanded)
                }
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
            
            // Section Content
            if isExpanded {
                sectionContent(for: section)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
    
    private func sectionSubtitle(for section: SettingsSection) -> String {
        switch section {
        case .apiKeys:
            let validAICount = AIProvider.allCases.filter { configManager.isAPIKeyValid(for: $0) }.count
            let totalProviders = AIProvider.allCases.count + 2 // +1 for Alpha Vantage, +1 for RapidAPI
            let validAV = configManager.isAlphaVantageKeyValid ? 1 : 0
            let validRapid = configManager.isRapidAPIKeyValid ? 1 : 0
            return "\(validAICount + validAV + validRapid)/\(totalProviders) providers configured"
        case .aiPrompts:
            return "Customize AI analysis prompts"
        case .appPreferences:
            return "Theme, notifications, refresh intervals"
        case .supportFeedback:
            return "Get help and share your feedback"
        case .developerTools:
            return "Cache management and app maintenance"
        }
    }
    
    @ViewBuilder
    private func sectionContent(for section: SettingsSection) -> some View {
        switch section {
        case .apiKeys:
            apiKeysSection
        case .aiPrompts:
            aiPromptsSection
        case .appPreferences:
            appPreferencesSection
        case .supportFeedback:
            supportFeedbackSection
        case .developerTools:
            developerToolsSection
        }
    }
    
    // MARK: - API Keys Section
    
    @ViewBuilder
    private var apiKeysSection: some View {
        ForEach(AIProvider.allCases) { provider in
            apiKeyInputRow(
                title: provider.displayName,
                icon: provider.iconName,
                iconColor: provider.primaryColor,
                apiKey: binding(for: provider),
                isValid: configManager.isAPIKeyValid(for: provider),
                getKeyURL: provider.apiKeyURL
            )
        }
        
        // Alpha Vantage API Key
        apiKeyInputRow(
            title: "Alpha Vantage",
            icon: "chart.line.uptrend.xyaxis",
            iconColor: .cyan,
            apiKey: $configManager.alphaVantageAPIKey,
            isValid: configManager.isAlphaVantageKeyValid,
            getKeyURL: URL(string: "https://www.alphavantage.co/support/#api-key")!
        )
        
        // RapidAPI Key
        apiKeyInputRow(
            title: "RapidAPI",
            icon: "bolt.horizontal",
            iconColor: .indigo,
            apiKey: $configManager.rapidAPIKey,
            isValid: configManager.isRapidAPIKeyValid,
            getKeyURL: URL(string: "https://rapidapi.com/hub")!
        )
    }
    
    @ViewBuilder
    private func apiKeyInputRow(
        title: String,
        icon: String,
        iconColor: Color,
        apiKey: Binding<String>,
        isValid: Bool,
        getKeyURL: URL?
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(iconColor)
                    .frame(width: 20)
                
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                if isValid {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
            }
            
            HStack {
                SecureField("Enter \(title) API key...", text: apiKey)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                
                if let url = getKeyURL {
                    Link(destination: url) {
                        Text("Get Key")
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.accentColor.opacity(0.1))
                            .foregroundStyle(Color.accentColor)
                            .cornerRadius(6)
                    }
                }
            }
        }
    }
    
    private func binding(for provider: AIProvider) -> Binding<String> {
        switch provider {
        case .deepSeek:
            return $configManager.deepSeekAPIKey
        case .openRouter:
            return $configManager.openRouterAPIKey
        case .openAI:
            return $configManager.openAIAPIKey
        case .qwen:
            return $configManager.qwenAPIKey
        }
    }
    
    // MARK: - AI Prompts Section
    
    @ViewBuilder
    private var aiPromptsSection: some View {
        ForEach([PromptType.profitConfidence, .risk, .prediction, .portfolio], id: \.key) { promptType in
            Button {
                selectedPrompt = promptType
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(promptType.displayName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.primary)
                        
                        Text(configManager.getPromptTemplate(for: promptType))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
        }
        
        Button("Reset All to Defaults") {
            resetAllPrompts()
        }
        .foregroundStyle(.red)
    }
    
    // MARK: - App Preferences Section
    
    @ViewBuilder
    private var appPreferencesSection: some View {
        // Refresh Frequency
        HStack {
            Text("Auto-refresh Frequency")
            Spacer()
            Picker("Frequency", selection: .constant("30min")) {
                Text("15 minutes").tag("15min")
                Text("30 minutes").tag("30min")
                Text("1 hour").tag("1h")
                Text("Manual only").tag("manual")
            }
            .pickerStyle(.menu)
        }
        
        // Theme
        HStack {
            Text("Appearance")
            Spacer()
            Picker("Theme", selection: .constant("auto")) {
                Text("Light").tag("light")
                Text("Dark").tag("dark")
                Text("Auto").tag("auto")
            }
            .pickerStyle(.menu)
        }
        
        // Notifications
        Toggle("Enable Notifications", isOn: .constant(true))
        
        // Data Source Priority
        HStack {
            Text("Primary Data Source")
            Spacer()
            Picker("Source", selection: .constant("yahoo")) {
                Text("Yahoo Finance").tag("yahoo")
                Text("Alpha Vantage").tag("alpha")
            }
            .pickerStyle(.menu)
        }
    }
    
    // MARK: - Support & Feedback Section
    
    @ViewBuilder
    private var supportFeedbackSection: some View {
        // Send Feedback via Email
        Button(action: {
            sendFeedbackEmail()
        }) {
            HStack {
                Image(systemName: "envelope.fill")
                    .foregroundStyle(.blue)
                    .frame(width: 20)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Send Feedback")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                    
                    Text("Share your ideas and suggestions")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "arrow.up.right")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        
        // App Version Info
        HStack {
            Image(systemName: "info.circle")
                .foregroundStyle(.gray)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("App Version")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
        
        // Contact Information
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "person.circle")
                    .foregroundStyle(.green)
                    .frame(width: 20)
                
                Text("Developer Contact")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
            }
            
            Text("victor.lam@pinkkamii.com")
                .font(.caption)
                .foregroundStyle(.blue)
                .padding(.leading, 28) // Align with text above
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Developer Tools Section
    
    @ViewBuilder
    private var developerToolsSection: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("Cache Status")
                    .font(.subheadline)
                if let lastUpdate = dataManager.lastUpdateTime {
                    Text("Last updated: \(lastUpdate, style: .relative)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("No cached data")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            Button("Clear Cache") {
                showingClearCacheAlert = true
            }
            .foregroundStyle(.red)
        }
        
        // API Testing
        Button("Test API Connections") {
            Task {
                await testAPIConnections()
            }
        }
        .foregroundStyle(.blue)
        
        // Export Settings
        Button("Export Settings") {
            exportSettings()
        }
        .foregroundStyle(.blue)
        
        // App Info
        HStack {
            Text("App Version")
            Spacer()
            Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown")
                .foregroundStyle(.secondary)
        }
    }
    
    // MARK: - Actions
    
    private func sendFeedbackEmail() {
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let systemVersion = UIDevice.current.systemVersion
        let deviceModel = UIDevice.current.model
        
        let subject = "Feedback for Investment Portfolio App"
        let body = """
        Hi Victor,
        
        I'd like to share some feedback about your Investment Portfolio app:
        
        [Please share your thoughts, suggestions, or report any issues here]
        
        
        ---
        App Version: \(appVersion)
        iOS Version: \(systemVersion)
        Device: \(deviceModel)
        """
        
        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        let mailtoString = "mailto:victor.lam@pinkkamii.com?subject=\(encodedSubject)&body=\(encodedBody)"
        
        if let mailtoURL = URL(string: mailtoString) {
            if UIApplication.shared.canOpenURL(mailtoURL) {
                UIApplication.shared.open(mailtoURL, options: [:], completionHandler: nil)
            } else {
                // Fallback: copy email to clipboard and show alert
                UIPasteboard.general.string = "victor.lam@pinkkamii.com"
                // You could show an alert here saying "Email address copied to clipboard"
                print("Email app not available. Email address copied to clipboard.")
            }
        }
    }
    
    private func resetAllPrompts() {
        configManager.updatePromptTemplate(PromptTemplate.defaultProfitConfidence, for: .profitConfidence)
        configManager.updatePromptTemplate(PromptTemplate.defaultRisk, for: .risk)
        configManager.updatePromptTemplate(PromptTemplate.defaultPrediction, for: .prediction)
        configManager.updatePromptTemplate(PromptTemplate.defaultPortfolio, for: .portfolio)
    }
    
    private func testAPIConnections() async {
        // Implementation would test each configured API
        print("Testing API connections...")
    }
    
    private func exportSettings() {
        // Implementation would export settings to file
        print("Exporting settings...")
    }
}

// MARK: - Prompt Editor Sheet

struct PromptEditorSheet: View {
    let promptType: PromptType
    @EnvironmentObject var configManager: SecureConfigurationManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var editedPrompt: String = ""
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(promptType.displayName)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("Customize the prompt template used for \(promptType.displayName.lowercased()). This affects how the AI analyzes your portfolio.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                TextEditor(text: $editedPrompt)
                    .font(.system(.body, design: .monospaced))
                    .padding(8)
                    .background(.regularMaterial)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(.separator, lineWidth: 1)
                    )
                
                HStack {
                    Button("Reset to Default") {
                        editedPrompt = defaultPrompt(for: promptType)
                    }
                    .foregroundStyle(.red)
                    
                    Spacer()
                    
                    Button("Preview") {
                        // Could show a preview of how this prompt would look
                    }
                    .foregroundStyle(.blue)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Edit Prompt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        configManager.updatePromptTemplate(editedPrompt, for: promptType)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(editedPrompt.isEmpty)
                }
            }
            .onAppear {
                editedPrompt = configManager.getPromptTemplate(for: promptType)
            }
        }
    }
    
    private func defaultPrompt(for type: PromptType) -> String {
        switch type {
        case .profitConfidence: return PromptTemplate.defaultProfitConfidence
        case .risk: return PromptTemplate.defaultRisk
        case .prediction: return PromptTemplate.defaultPrediction
        case .portfolio: return PromptTemplate.defaultPortfolio
        }
    }
}

#Preview {
    ComprehensiveSettingsView()
        .environmentObject(SecureConfigurationManager.shared)
}
