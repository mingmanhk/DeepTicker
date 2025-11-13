import SwiftUI

struct AIPromptManagementView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    @StateObject private var aiSettings = AISettingsViewModel.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showingResetAlert = false
    @State private var selectedUpgradeFeature: SmartUpgradePrompt.ProFeature?
    @State private var showUpgradeSheet = false
    
    var body: some View {
        NavigationStack {
            List {
                // Pro upgrade banner for free users
                if !aiSettings.isPremium {
                    Section {
                        HStack(spacing: 12) {
                            Image(systemName: "lock.fill")
                                .font(.title2)
                                .foregroundStyle(.orange)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Custom Prompts Locked")
                                    .font(.headline)
                                
                                Text("Upgrade to Pro to customize AI prompts")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            ProFeaturesBadge()
                        }
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedUpgradeFeature = .customPrompts
                        }
                    }
                }
                
                Section {
                    Text("Customize the AI prompts used throughout the app for stock analysis, predictions, and portfolio management. These templates are shared across all AI-powered features.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Section("System Prompts") {
                    PromptRow(
                        title: "System Prompt",
                        description: "Base instructions for the AI analyst",
                        prompt: $settingsManager.analyzeSystemPrompt,
                        isLocked: !aiSettings.isPremium,
                        onLockedTap: {
                            selectedUpgradeFeature = .customPrompts
                        }
                    )
                }
                
                Section("Analysis Prompts") {
                    PromptRow(
                        title: "Risk Analysis",
                        description: "Portfolio risk and diversification analysis",
                        prompt: $settingsManager.analyzePredictionRiskPrompt,
                        isLocked: !aiSettings.isPremium,
                        onLockedTap: {
                            selectedUpgradeFeature = .customPrompts
                        }
                    )
                    
                    PromptRow(
                        title: "Confidence Analysis",
                        description: "Prediction confidence assessment",
                        prompt: $settingsManager.analyzePredictionConfidencePrompt,
                        isLocked: !aiSettings.isPremium,
                        onLockedTap: {
                            selectedUpgradeFeature = .customPrompts
                        }
                    )
                    
                    PromptRow(
                        title: "Price Prediction",
                        description: "Stock movement predictions with JSON format",
                        prompt: $settingsManager.analyzePredictionPrompt,
                        isLocked: !aiSettings.isPremium,
                        onLockedTap: {
                            selectedUpgradeFeature = .customPrompts
                        }
                    )
                    
                    PromptRow(
                        title: "Investment Analysis",
                        description: "Daily market briefing and portfolio health",
                        prompt: $settingsManager.analyzeMyInvestmentPrompt,
                        isLocked: !aiSettings.isPremium,
                        onLockedTap: {
                            selectedUpgradeFeature = .customPrompts
                        }
                    )
                }
                
                Section {
                    Button("Reset to Defaults", role: .destructive) {
                        showingResetAlert = true
                    }
                } footer: {
                    Text("This will restore all prompts to their original default values.")
                        .font(.caption)
                }
            }
            .navigationTitle("AI Prompt Management")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Reset All Prompts", isPresented: $showingResetAlert) {
                Button("Reset", role: .destructive) {
                    resetToDefaults()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will reset all AI prompts to their default values. This action cannot be undone.")
            }
            .sheet(item: $selectedUpgradeFeature) { feature in
                ZStack {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .onTapGesture {
                            selectedUpgradeFeature = nil
                        }
                    
                    SmartUpgradePrompt(
                        feature: feature,
                        onUpgrade: {
                            selectedUpgradeFeature = nil
                            showUpgradeSheet = true
                            IAPAnalytics.shared.trackUpgradeScreenViewed(source: "prompt_management")
                        },
                        onDismiss: {
                            selectedUpgradeFeature = nil
                        }
                    )
                }
                .presentationBackground(.clear)
            }
            .sheet(isPresented: $showUpgradeSheet) {
                NavigationStack {
                    UpgradeToProView()
                }
            }
        }
    }
    
    private func resetToDefaults() {
        settingsManager.analyzeSystemPrompt = "You are a financial analyst AI specialized in short-term stock predictions.\nAnalyze stock data and provide concise predictions with confidence levels.\nAlways respond with valid JSON format and keep explanations brief but insightful.\nFocus on technical indicators, volume trends, and recent market behavior."
        
        settingsManager.analyzePredictionRiskPrompt = "Analyze the following stock portfolio and provide a concise summary of its overall health, diversification, and risk profile. Offer actionable suggestions for improvement."
        
        settingsManager.analyzePredictionConfidencePrompt = "Recent Historical Data for Last 10 trading days. Please provide a prediction for tomorrow's movement with the following JSON format. All percentage-based values should be numbers between 0 and 100."
        
        settingsManager.analyzePredictionPrompt = "Recent Historical Data for Last 10 trading days Please provide a prediction for tomorrow's movement with the following JSON format. All percentage-based values should be numbers between 0 and 100. { \"direction\": \"up|down|neutral\", \"confidence\": 85.0, \"predicted_change\": 2.5, \"reasoning\": \"Brief explanation of analysis.\", \"profit_likelihood\": 75.0, \"gain_potential\": 4.5, \"upside_chance\": 80.0 }"
        
        settingsManager.analyzeMyInvestmentPrompt = "You are an expert financial analyst AI. Your task is to provide a detailed daily market briefing and portfolio health assessment. Analyze the provided stock symbols in the context of current market events, including political developments, earnings reports, and institutional trades. Provide a brief health assessment with recommendations for diversification or risk management. Structure your response strictly in the requested JSON format with four keys: \"overview\", \"keyDrivers\", \"highlightsAndActivity\", and \"riskFactors\"."
    }
}

struct PromptRow: View {
    let title: String
    let description: String
    @Binding var prompt: String
    var isLocked: Bool = false
    var onLockedTap: (() -> Void)?
    @State private var showingEditor = false
    
    var body: some View {
        Button {
            if isLocked {
                onLockedTap?()
            } else {
                showingEditor = true
            }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 8) {
                            Text(title)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(.primary)
                            
                            if isLocked {
                                Image(systemName: "lock.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.orange)
                            }
                        }
                        
                        Text(description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    if isLocked {
                        ProFeaturesBadge()
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                
                Text(String(prompt.prefix(100)) + (prompt.count > 100 ? "..." : ""))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingEditor) {
            PromptEditorView(title: title, description: description, prompt: $prompt)
        }
    }
}

struct PromptEditorView: View {
    let title: String
    let description: String
    @Binding var prompt: String
    @Environment(\.dismiss) private var dismiss
    @State private var editablePrompt: String
    @State private var hasChanges = false
    
    init(title: String, description: String, prompt: Binding<String>) {
        self.title = title
        self.description = description
        self._prompt = prompt
        self._editablePrompt = State(initialValue: prompt.wrappedValue)
    }
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Prompt Template")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .padding(.horizontal)
                    
                    TextEditor(text: $editablePrompt)
                        .font(.system(.body, design: .monospaced))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .padding(.horizontal)
                        .onChange(of: editablePrompt) { _, _ in
                            hasChanges = editablePrompt != prompt
                        }
                }
                
                Spacer()
            }
            .padding(.top)
            .navigationTitle("Edit Prompt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        prompt = editablePrompt
                        dismiss()
                    }
                    .disabled(!hasChanges)
                    .fontWeight(hasChanges ? .semibold : .regular)
                }
            }
        }
    }
}

#Preview {
    AIPromptManagementView()
        .environmentObject(SettingsManager.shared)
}