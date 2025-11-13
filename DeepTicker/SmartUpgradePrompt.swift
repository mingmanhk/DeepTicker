import SwiftUI

/// Smart prompts that appear when users try to use Pro features
struct SmartUpgradePrompt: View {
    let feature: ProFeature
    let onUpgrade: () -> Void
    let onDismiss: () -> Void
    
    enum ProFeature: Identifiable {
        case advancedAI
        case customPrompts
        case multipleProviders
        case portfolioOptimization
        
        var id: String { title }
        
        var icon: String {
            switch self {
            case .advancedAI: return "brain.head.profile"
            case .customPrompts: return "doc.text.fill"
            case .multipleProviders: return "square.stack.3d.up.fill"
            case .portfolioOptimization: return "chart.line.uptrend.xyaxis"
            }
        }
        
        var title: String {
            switch self {
            case .advancedAI: return "Advanced AI Providers"
            case .customPrompts: return "Custom Prompts"
            case .multipleProviders: return "Multiple AI Models"
            case .portfolioOptimization: return "Portfolio Optimization"
            }
        }
        
        var description: String {
            switch self {
            case .advancedAI:
                return "Access powerful AI models from OpenAI, Anthropic, Google, and Azure for deeper insights"
            case .customPrompts:
                return "Customize analysis prompts to match your investment strategy and risk tolerance"
            case .multipleProviders:
                return "Compare insights from multiple AI providers to make better-informed decisions"
            case .portfolioOptimization:
                return "Get advanced recommendations for diversification and risk management"
            }
        }
        
        var benefits: [String] {
            switch self {
            case .advancedAI:
                return [
                    "OpenAI GPT-4 analysis",
                    "Anthropic Claude insights",
                    "Google Gemini predictions",
                    "Azure OpenAI models"
                ]
            case .customPrompts:
                return [
                    "Tailor AI to your strategy",
                    "Focus on what matters",
                    "Save custom templates",
                    "Share with other devices"
                ]
            case .multipleProviders:
                return [
                    "Compare different AI opinions",
                    "Reduce single-model bias",
                    "Get consensus insights",
                    "Switch providers anytime"
                ]
            case .portfolioOptimization:
                return [
                    "Diversification analysis",
                    "Risk-adjusted returns",
                    "Sector allocation tips",
                    "Rebalancing suggestions"
                ]
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 12) {
                Image(systemName: feature.icon)
                    .font(.system(size: 50))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                HStack(spacing: 6) {
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundStyle(.yellow)
                    
                    Text("PRO FEATURE")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.secondary)
                }
                
                Text(feature.title)
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text(feature.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            // Benefits List
            VStack(alignment: .leading, spacing: 12) {
                ForEach(feature.benefits, id: \.self) { benefit in
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        
                        Text(benefit)
                            .font(.subheadline)
                        
                        Spacer()
                    }
                }
            }
            .padding()
            .background(.regularMaterial)
            .cornerRadius(12)
            
            // Actions
            VStack(spacing: 12) {
                Button {
                    onUpgrade()
                } label: {
                    HStack {
                        Image(systemName: "star.fill")
                        Text("Upgrade to Pro")
                    }
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundStyle(.white)
                    .cornerRadius(12)
                }
                
                Button {
                    onDismiss()
                } label: {
                    Text("Maybe Later")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(24)
        .background(.regularMaterial)
        .cornerRadius(20)
        .padding(.horizontal, 32)
        .shadow(color: .black.opacity(0.2), radius: 20)
    }
}

/// View modifier to show smart upgrade prompts
struct SmartUpgradePromptModifier: ViewModifier {
    @StateObject private var aiSettings = AISettingsViewModel.shared
    @State private var showPrompt = false
    @State private var showUpgrade = false
    
    let feature: SmartUpgradePrompt.ProFeature
    let action: () -> Void
    
    @MainActor
    func body(content: Content) -> some View {
        content
            .onTapGesture {
                if aiSettings.isPremium {
                    action()
                } else {
                    IAPAnalytics.shared.trackProFeatureBlocked(feature: feature.title)
                    showPrompt = true
                }
            }
            .overlay {
                if showPrompt {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .onTapGesture {
                            showPrompt = false
                        }
                        .overlay {
                            SmartUpgradePrompt(
                                feature: feature,
                                onUpgrade: {
                                    showPrompt = false
                                    showUpgrade = true
                                    IAPAnalytics.shared.trackUpgradeScreenViewed(source: feature.title)
                                },
                                onDismiss: {
                                    showPrompt = false
                                }
                            )
                        }
                }
            }
            .sheet(isPresented: $showUpgrade) {
                NavigationStack {
                    UpgradeToProView()
                }
            }
    }
}

extension View {
    /// Shows a smart upgrade prompt when user tries to access a Pro feature
    func smartUpgradePrompt(
        for feature: SmartUpgradePrompt.ProFeature,
        action: @escaping () -> Void
    ) -> some View {
        modifier(SmartUpgradePromptModifier(feature: feature, action: action))
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.2)
        
        SmartUpgradePrompt(
            feature: .advancedAI,
            onUpgrade: { print("Upgrade") },
            onDismiss: { print("Dismiss") }
        )
    }
}
