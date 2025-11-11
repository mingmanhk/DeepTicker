//
//  OnboardingIntegrationExample.swift
//  DeepTicker
//
//  Examples of how to integrate API key onboarding into your app

import SwiftUI

// MARK: - Example 1: Show on First Launch

struct ExampleAppWithFirstLaunchOnboarding: App {
    @AppStorage("hasCompletedAPISetup") private var hasCompletedAPISetup = false
    @State private var showOnboarding = false
    
    var body: some Scene {
        WindowGroup {
            ExampleContentView()
                .sheet(isPresented: $showOnboarding) {
                    APIKeyOnboardingView()
                }
                .onAppear {
                    checkAndShowOnboarding()
                }
        }
    }
    
    private func checkAndShowOnboarding() {
        if !hasCompletedAPISetup {
            let configManager = SecureConfigurationManager.shared
            
            // Only show if keys are actually missing
            let hasDeepSeek = !configManager.deepSeekAPIKey.isEmpty
            let hasAlphaVantage = !configManager.alphaVantageAPIKey.isEmpty
            
            if !hasDeepSeek || !hasAlphaVantage {
                showOnboarding = true
            } else {
                // Keys exist, mark as completed
                hasCompletedAPISetup = true
            }
        }
    }
}

// MARK: - Example 2: Show When Adding First Stock

struct ExampleMyInvestmentTabWithOnboarding: View {
    @EnvironmentObject var portfolioManager: UnifiedPortfolioManager
    @State private var showOnboarding = false
    @State private var showAddStock = false
    
    var body: some View {
        NavigationStack {
            VStack {
                if portfolioManager.items.isEmpty {
                    EmptyPortfolioView(showOnboarding: $showOnboarding, showAddStock: $showAddStock)
                } else {
                    ExamplePortfolioListView()
                }
            }
            .navigationTitle("My Investment")
            .sheet(isPresented: $showOnboarding) {
                APIKeyOnboardingView()
            }
            .sheet(isPresented: $showAddStock) {
                AddStockView()
            }
        }
    }
}

struct EmptyPortfolioView: View {
    @Binding var showOnboarding: Bool
    @Binding var showAddStock: Bool
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 80))
                .foregroundStyle(.blue)
            
            Text("Start Building Your Portfolio")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Track your investments and get AI-powered insights")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            VStack(spacing: 12) {
                Button {
                    // Check if API keys are set up first
                    if needsAPISetup() {
                        showOnboarding = true
                    } else {
                        showAddStock = true
                    }
                } label: {
                    Label("Add Your First Stock", systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundStyle(.white)
                        .cornerRadius(12)
                }
                
                if needsAPISetup() {
                    Text("Note: You'll need to set up API keys first")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
    }
    
    private func needsAPISetup() -> Bool {
        let configManager = SecureConfigurationManager.shared
        return configManager.deepSeekAPIKey.isEmpty || configManager.alphaVantageAPIKey.isEmpty
    }
}

// MARK: - Example 3: Settings Integration

struct ExampleSettingsViewWithOnboarding: View {
    @ObservedObject private var configManager = SecureConfigurationManager.shared
    @State private var showOnboarding = false
    @State private var showingAlphaVantageHelp = false
    @State private var showingDeepSeekHelp = false
    
    var body: some View {
        NavigationStack {
            List {
                // Quick Setup Section (if keys missing)
                if configManager.deepSeekAPIKey.isEmpty || configManager.alphaVantageAPIKey.isEmpty {
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.orange)
                                Text("API Keys Required")
                                    .fontWeight(.semibold)
                            }
                            
                            Text("DeepTicker needs API keys to fetch stock prices and provide AI analysis.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            Button {
                                showOnboarding = true
                            } label: {
                                Label("Setup API Keys", systemImage: "key.fill")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue)
                                    .foregroundStyle(.white)
                                    .cornerRadius(10)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 8)
                    } header: {
                        Text("Setup Required")
                    }
                }
                
                // API Keys Section
                Section("Data & API Settings") {
                    // DeepSeek
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Label("DeepSeek AI", systemImage: "brain.head.profile")
                                .font(.headline)
                            
                            Spacer()
                            
                            if !configManager.deepSeekAPIKey.isEmpty {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            }
                            
                            Button {
                                showingDeepSeekHelp = true
                            } label: {
                                Image(systemName: "info.circle")
                                    .foregroundStyle(.blue)
                            }
                        }
                        
                        SecureField("Enter DeepSeek API Key", text: $configManager.deepSeekAPIKey)
                            .textFieldStyle(.roundedBorder)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .font(.system(.caption, design: .monospaced))
                        
                        if !configManager.deepSeekAPIKey.isEmpty {
                            Text("Key saved securely in Keychain")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                    
                    // Alpha Vantage
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Label("Alpha Vantage", systemImage: "chart.line.uptrend.xyaxis")
                                .font(.headline)
                            
                            Spacer()
                            
                            if !configManager.alphaVantageAPIKey.isEmpty {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            }
                            
                            Button {
                                showingAlphaVantageHelp = true
                            } label: {
                                Image(systemName: "info.circle")
                                    .foregroundStyle(.blue)
                            }
                        }
                        
                        TextField("Enter Alpha Vantage API Key", text: $configManager.alphaVantageAPIKey)
                            .textFieldStyle(.roundedBorder)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .font(.system(.caption, design: .monospaced))
                        
                        if !configManager.alphaVantageAPIKey.isEmpty {
                            Text("Key saved securely in Keychain")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                    
                    // Guided Setup Button
                    Button {
                        showOnboarding = true
                    } label: {
                        Label("Open Setup Guide", systemImage: "arrow.right.circle.fill")
                    }
                }
                
                // Status Section
                Section("API Status") {
                    HStack {
                        Text("DeepSeek AI")
                        Spacer()
                        statusIndicator(isValid: configManager.isAPIKeyValid(for: .deepSeek))
                    }
                    
                    HStack {
                        Text("Alpha Vantage")
                        Spacer()
                        statusIndicator(isValid: configManager.isAlphaVantageKeyValid)
                    }
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showOnboarding) {
                APIKeyOnboardingView()
            }
            .alert("DeepSeek AI", isPresented: $showingDeepSeekHelp) {
                Button("Get API Key") {
                    if let url = URL(string: "https://www.deepseek.com") {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Close", role: .cancel) {}
            } message: {
                Text("DeepSeek powers the AI analysis in DeepTicker. Visit deepseek.com to create an account and generate your API key.")
            }
            .alert("Alpha Vantage", isPresented: $showingAlphaVantageHelp) {
                Button("Get API Key") {
                    if let url = URL(string: "https://www.alphavantage.co/support/#api-key") {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Close", role: .cancel) {}
            } message: {
                Text("Alpha Vantage provides real-time stock prices. Visit alphavantage.co to get your free API key instantly via email.")
            }
        }
    }
    
    @ViewBuilder
    private func statusIndicator(isValid: Bool) -> some View {
        if isValid {
            Label("Connected", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.caption)
        } else {
            Label("Not Set", systemImage: "xmark.circle.fill")
                .foregroundStyle(.red)
                .font(.caption)
        }
    }
}

// MARK: - Example 4: Alert When Keys Missing

struct ExampleViewWithKeyCheck: View {
    @State private var showOnboarding = false
    @State private var showMissingKeysAlert = false
    
    var body: some View {
        VStack {
            Button("Fetch AI Analysis") {
                if checkAPIKeys() {
                    fetchAnalysis()
                } else {
                    showMissingKeysAlert = true
                }
            }
        }
        .alert("API Keys Required", isPresented: $showMissingKeysAlert) {
            Button("Setup Now") {
                showOnboarding = true
            }
            Button("Later", role: .cancel) {}
        } message: {
            Text("DeepTicker needs API keys to provide AI analysis. Would you like to set them up now?")
        }
        .sheet(isPresented: $showOnboarding) {
            APIKeyOnboardingView()
        }
    }
    
    private func checkAPIKeys() -> Bool {
        let configManager = SecureConfigurationManager.shared
        return configManager.isAPIKeyValid(for: .deepSeek) && configManager.isAlphaVantageKeyValid
    }
    
    private func fetchAnalysis() {
        // Proceed with analysis
        print("Fetching AI analysis...")
    }
}

// MARK: - Example 5: Inline Banner in Portfolio

struct ExamplePortfolioWithBanner: View {
    @ObservedObject private var portfolioManager = UnifiedPortfolioManager.shared
    @ObservedObject private var configManager = SecureConfigurationManager.shared
    @State private var showOnboarding = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Banner if keys missing
                if configManager.deepSeekAPIKey.isEmpty || configManager.alphaVantageAPIKey.isEmpty {
                    APIKeyBanner(showOnboarding: $showOnboarding)
                }
                
                // Portfolio content
                List {
                    ForEach(portfolioManager.items) { item in
                        ExamplePortfolioRowView(item: item)
                    }
                }
            }
            .navigationTitle("My Portfolio")
            .sheet(isPresented: $showOnboarding) {
                APIKeyOnboardingView()
            }
        }
    }
}

struct APIKeyBanner: View {
    @Binding var showOnboarding: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "key.fill")
                .font(.title2)
                .foregroundStyle(.white)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Setup Required")
                    .font(.headline)
                    .foregroundStyle(.white)
                
                Text("Tap to configure API keys")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.9))
            }
            
            Spacer()
            
            Button {
                showOnboarding = true
            } label: {
                Text("Setup")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.white)
                    .foregroundStyle(.blue)
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(
            LinearGradient(
                colors: [Color.blue, Color.purple],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
    }
}

// MARK: - Example 6: Helper Extension

extension View {
    /// Ensures API keys are set up before performing an action
    func requireAPIKeys(
        deepSeek: Bool = true,
        alphaVantage: Bool = true,
        onSuccess: @escaping () -> Void
    ) -> some View {
        modifier(APIKeyRequirementModifier(
            requireDeepSeek: deepSeek,
            requireAlphaVantage: alphaVantage,
            onSuccess: onSuccess
        ))
    }
}

struct APIKeyRequirementModifier: ViewModifier {
    let requireDeepSeek: Bool
    let requireAlphaVantage: Bool
    let onSuccess: () -> Void
    
    @State private var showOnboarding = false
    @State private var showAlert = false
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                checkKeys()
            }
            .alert("API Keys Required", isPresented: $showAlert) {
                Button("Setup Now") {
                    showOnboarding = true
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(alertMessage)
            }
            .sheet(isPresented: $showOnboarding) {
                APIKeyOnboardingView()
            }
    }
    
    private func checkKeys() {
        let configManager = SecureConfigurationManager.shared
        
        let hasDeepSeek = !requireDeepSeek || configManager.isAPIKeyValid(for: .deepSeek)
        let hasAlphaVantage = !requireAlphaVantage || configManager.isAlphaVantageKeyValid
        
        if hasDeepSeek && hasAlphaVantage {
            onSuccess()
        } else {
            showAlert = true
        }
    }
    
    private var alertMessage: String {
        var missing: [String] = []
        if requireDeepSeek { missing.append("DeepSeek AI") }
        if requireAlphaVantage { missing.append("Alpha Vantage") }
        return "This feature requires \(missing.joined(separator: " and ")). Set up your API keys to continue."
    }
}

// MARK: - Usage Example

struct ExampleUsageView: View {
    var body: some View {
        Button("Analyze Portfolio") {
            // This will automatically check for keys
        }
        .requireAPIKeys(deepSeek: true, alphaVantage: true) {
            performAnalysis()
        }
    }
    
    private func performAnalysis() {
        print("Performing analysis...")
    }
}

// MARK: - Placeholder Views (for example purposes only)

// Note: These are placeholder implementations for the examples above.
// In your actual app, replace these with your real views or remove the examples
// that reference views that don't exist in your project.

private struct ExampleContentView: View {
    var body: some View {
        Text("Main Content")
    }
}

private struct ExamplePortfolioListView: View {
    var body: some View {
        Text("Portfolio List")
    }
}

private struct ExamplePortfolioRowView: View {
    let item: StockItem
    var body: some View {
        Text(item.symbol)
    }
}
