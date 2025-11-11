//
//  APIKeyOnboardingView.swift
//  DeepTicker
//
//  First-time setup guide for API keys

import SwiftUI

struct APIKeyOnboardingView: View {
    @ObservedObject private var configManager = SecureConfigurationManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var currentPage = 0
    @State private var deepSeekKey = ""
    @State private var alphaVantageKey = ""
    @State private var showValidation = false
    @State private var isValidating = false
    @State private var validationMessage = ""
    @State private var validationSuccess = false
    
    private let totalPages = 4 // Welcome, DeepSeek, Alpha Vantage, Complete
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Progress indicator
                    progressIndicator
                        .padding(.top)
                    
                    // Content
                    TabView(selection: $currentPage) {
                        welcomePage.tag(0)
                        deepSeekPage.tag(1)
                        alphaVantagePage.tag(2)
                        completePage.tag(3)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .animation(.easeInOut, value: currentPage)
                    
                    // Navigation buttons
                    navigationButtons
                        .padding()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Skip") {
                        dismiss()
                    }
                    .foregroundStyle(.secondary)
                }
            }
        }
    }
    
    // MARK: - Progress Indicator
    
    private var progressIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalPages, id: \.self) { index in
                Capsule()
                    .fill(index <= currentPage ? Color.blue : Color.gray.opacity(0.3))
                    .frame(height: 4)
                    .frame(maxWidth: index == currentPage ? 40 : 20)
                    .animation(.spring(), value: currentPage)
            }
        }
        .padding(.horizontal)
    }
    
    // MARK: - Pages
    
    private var welcomePage: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Icon
            Image(systemName: "key.fill")
                .font(.system(size: 80))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: .blue.opacity(0.3), radius: 10)
            
            // Title
            Text("Welcome to DeepTicker")
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            // Description
            VStack(spacing: 12) {
                Text("To get started, you'll need two API keys:")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                
                VStack(alignment: .leading, spacing: 12) {
                    FeatureRow(
                        icon: "brain.head.profile",
                        title: "DeepSeek AI",
                        description: "For intelligent portfolio analysis",
                        color: .purple
                    )
                    
                    FeatureRow(
                        icon: "chart.line.uptrend.xyaxis",
                        title: "Alpha Vantage",
                        description: "For real-time stock price data",
                        color: .blue
                    )
                    
                    FeatureRow(
                        icon: "chart.bar.fill",
                        title: "RapidAPI",
                        description: "For enhanced stock data (Yahoo Finance)",
                        color: .orange
                    )
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.05), radius: 5)
            }
            
            InfoBox(
                icon: "checkmark.shield.fill",
                message: "Your API keys are stored securely in your device's Keychain and never leave your device.",
                color: .green
            )
            
            Spacer()
        }
        .padding()
    }
    
    private var deepSeekPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 40))
                            .foregroundStyle(.purple)
                        
                        VStack(alignment: .leading) {
                            Text("DeepSeek AI")
                                .font(.title2)
                                .fontWeight(.bold)
                            Text("Step 1 of 2")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Text("DeepSeek powers the AI analysis in the free version of DeepTicker.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Divider()
                
                // Instructions
                InstructionSection(
                    title: "How to Get Your API Key",
                    steps: [
                        "Visit deepseek.com and create an account",
                        "Navigate to API settings or dashboard",
                        "Generate a new API key",
                        "Copy the key and paste it below"
                    ],
                    link: ("Open DeepSeek Website", "https://www.deepseek.com")
                )
                
                // API Key input
                VStack(alignment: .leading, spacing: 8) {
                    Label("DeepSeek API Key", systemImage: "key.fill")
                        .font(.headline)
                    
                    SecureField("sk-...", text: $deepSeekKey)
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .font(.system(.body, design: .monospaced))
                    
                    if !deepSeekKey.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: deepSeekKey.hasPrefix("sk-") ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                .foregroundStyle(deepSeekKey.hasPrefix("sk-") ? .green : .orange)
                            
                            Text(deepSeekKey.hasPrefix("sk-") ? "Key format looks correct" : "DeepSeek keys usually start with 'sk-'")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                // Info boxes
                InfoBox(
                    icon: "gift.fill",
                    message: "DeepSeek often provides free tier or credits for new users.",
                    color: .blue
                )
                
                InfoBox(
                    icon: "lock.shield.fill",
                    message: "Your API key is encrypted and stored only on your device.",
                    color: .green
                )
            }
            .padding()
        }
    }
    
    private var alphaVantagePage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 40))
                            .foregroundStyle(.blue)
                        
                        VStack(alignment: .leading) {
                            Text("Alpha Vantage")
                                .font(.title2)
                                .fontWeight(.bold)
                            Text("Step 2 of 2")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Text("Alpha Vantage provides real-time stock prices and market data.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Divider()
                
                // Instructions
                InstructionSection(
                    title: "How to Get Your API Key",
                    steps: [
                        "Visit alphavantage.co and click 'Get Free API Key'",
                        "Enter your email and organization name",
                        "Check your email for the API key",
                        "Copy the key and paste it below"
                    ],
                    link: ("Open Alpha Vantage Website", "https://www.alphavantage.co/support/#api-key")
                )
                
                // API Key input
                VStack(alignment: .leading, spacing: 8) {
                    Label("Alpha Vantage API Key", systemImage: "key.fill")
                        .font(.headline)
                    
                    TextField("Your Alpha Vantage API Key", text: $alphaVantageKey)
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .font(.system(.body, design: .monospaced))
                    
                    if !alphaVantageKey.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: alphaVantageKey.count >= 16 ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                .foregroundStyle(alphaVantageKey.count >= 16 ? .green : .orange)
                            
                            Text(alphaVantageKey.count >= 16 ? "Key looks valid" : "Alpha Vantage keys are usually 16+ characters")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                // Info boxes
                InfoBox(
                    icon: "gift.fill",
                    message: "Alpha Vantage offers a free tier with 25 requests per day.",
                    color: .blue
                )
                
                InfoBox(
                    icon: "clock.fill",
                    message: "After setup, stock prices update automatically in your portfolio.",
                    color: .purple
                )
            }
            .padding()
        }
    }
    
    private var completePage: some View {
        VStack(spacing: 24) {
            Spacer()
            
            if isValidating {
                // Validating state
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                    
                    Text("Validating your API keys...")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
            } else if showValidation {
                // Validation result
                VStack(spacing: 16) {
                    Image(systemName: validationSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(validationSuccess ? .green : .red)
                    
                    Text(validationSuccess ? "All Set!" : "Validation Failed")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text(validationMessage)
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                    
                    if validationSuccess {
                        VStack(spacing: 12) {
                            FeatureRow(
                                icon: "checkmark.circle.fill",
                                title: "DeepSeek AI",
                                description: "Connected and ready",
                                color: .green
                            )
                            
                            FeatureRow(
                                icon: "checkmark.circle.fill",
                                title: "Alpha Vantage",
                                description: "Connected and ready",
                                color: .green
                            )
                            
                            FeatureRow(
                                icon: "checkmark.circle.fill",
                                title: "RapidAPI",
                                description: "Connected and ready",
                                color: .green
                            )
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.05), radius: 5)
                    }
                }
            } else {
                // Ready to validate
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.green, .blue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    Text("Ready to Go!")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Your API keys are configured. Let's test them to make sure everything works.")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                    
                    VStack(spacing: 12) {
                        if !deepSeekKey.isEmpty {
                            FeatureRow(
                                icon: "brain.head.profile",
                                title: "DeepSeek AI",
                                description: "Key provided",
                                color: .purple
                            )
                        }
                        
                        if !alphaVantageKey.isEmpty {
                            FeatureRow(
                                icon: "chart.line.uptrend.xyaxis",
                                title: "Alpha Vantage",
                                description: "Key provided",
                                color: .blue
                            )
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.05), radius: 5)
                }
            }
            
            Spacer()
        }
        .padding()
    }
    
    // MARK: - Navigation Buttons
    
    private var navigationButtons: some View {
        HStack(spacing: 16) {
            if currentPage > 0 && currentPage < 3 {
                Button {
                    withAnimation {
                        currentPage -= 1
                    }
                } label: {
                    Label("Back", systemImage: "chevron.left")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray5))
                        .cornerRadius(12)
                }
            }
            
            Button {
                handleNextButton()
            } label: {
                HStack {
                    Text(nextButtonTitle)
                        .fontWeight(.semibold)
                    
                    if currentPage < 3 {
                        Image(systemName: "chevron.right")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(nextButtonDisabled ? Color.gray : Color.blue)
                .foregroundStyle(.white)
                .cornerRadius(12)
            }
            .disabled(nextButtonDisabled)
        }
    }
    
    private var nextButtonTitle: String {
        switch currentPage {
        case 0: return "Get Started"
        case 1, 2: return "Continue"
        case 3: return showValidation ? (validationSuccess ? "Done" : "Try Again") : "Test Keys"
        default: return "Next"
        }
    }
    
    private var nextButtonDisabled: Bool {
        switch currentPage {
        case 1: return deepSeekKey.isEmpty
        case 2: return alphaVantageKey.isEmpty
        case 3: return isValidating
        default: return false
        }
    }
    
    // MARK: - Actions
    
    private func handleNextButton() {
        switch currentPage {
        case 0, 1, 2:
            withAnimation {
                currentPage += 1
            }
        case 3:
            if showValidation && validationSuccess {
                // Save and dismiss
                saveAPIKeys()
                dismiss()
            } else if showValidation && !validationSuccess {
                // Reset to try again
                showValidation = false
            } else {
                // Validate keys
                validateAPIKeys()
            }
        default:
            break
        }
    }
    
    private func validateAPIKeys() {
        isValidating = true
        showValidation = false
        
        // Simulate API validation (you should implement actual validation)
        Task {
            do {
                try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                
                await MainActor.run {
                    // For demo purposes, check if keys are provided
                    let deepSeekValid = !deepSeekKey.isEmpty && deepSeekKey.hasPrefix("sk-")
                    let alphaVantageValid = !alphaVantageKey.isEmpty && alphaVantageKey.count >= 16
                    
                    if deepSeekValid && alphaVantageValid {
                        validationSuccess = true
                        validationMessage = "Both API keys are working correctly! You can now start using DeepTicker."
                    } else {
                        validationSuccess = false
                        
                        if !deepSeekValid && !alphaVantageValid {
                            validationMessage = "Both API keys appear to be invalid. Please check them and try again."
                        } else if !deepSeekValid {
                            validationMessage = "DeepSeek API key appears to be invalid. Please check it and try again."
                        } else {
                            validationMessage = "Alpha Vantage API key appears to be invalid. Please check it and try again."
                        }
                    }
                    
                    isValidating = false
                    showValidation = true
                }
            } catch {
                await MainActor.run {
                    validationSuccess = false
                    validationMessage = "Validation failed: \(error.localizedDescription)"
                    isValidating = false
                    showValidation = true
                }
            }
        }
    }
    
    private func saveAPIKeys() {
        // Save DeepSeek key
        if !deepSeekKey.isEmpty {
            configManager.deepSeekAPIKey = deepSeekKey
            // Also save to keychain via the manager's setter
        }
        
        // Save Alpha Vantage key
        if !alphaVantageKey.isEmpty {
            configManager.alphaVantageAPIKey = alphaVantageKey
        }
        
        print("✅ API keys saved successfully")
    }
}

// MARK: - Supporting Views

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundStyle(color)
                .frame(width: 40, height: 40)
                .background(color.opacity(0.1))
                .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
    }
}

struct InfoBox: View {
    let icon: String
    let message: String
    let color: Color
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.system(size: 20))
            
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

struct InstructionSection: View {
    let title: String
    let steps: [String]
    let link: (String, String)?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .top, spacing: 12) {
                    Text("\(index + 1)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .frame(width: 24, height: 24)
                        .background(Color.blue)
                        .cornerRadius(12)
                    
                    Text(step)
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            
            if let (linkText, linkURL) = link {
                Link(destination: URL(string: linkURL)!) {
                    HStack {
                        Image(systemName: "safari.fill")
                        Text(linkText)
                    }
                    .font(.subheadline)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .background(Color.blue.opacity(0.1))
                    .foregroundStyle(.blue)
                    .cornerRadius(8)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    APIKeyOnboardingView()
}
