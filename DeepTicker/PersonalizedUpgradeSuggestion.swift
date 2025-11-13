import SwiftUI
import Combine

/// Personalized upgrade suggestions based on user behavior
struct PersonalizedUpgradeSuggestion: View {
    let trigger: UpgradeTrigger
    @Environment(\.dismiss) private var dismiss
    @State private var showFullUpgrade = false
    
    enum UpgradeTrigger {
        case frequentAnalysis(count: Int)
        case multipleTickers(count: Int)
        case apiKeyInterest
        case promptCustomization
        case weeklyActive(weeks: Int)
        
        var title: String {
            switch self {
            case .frequentAnalysis: return "You're a Power User! 🚀"
            case .multipleTickers: return "Managing Many Stocks?"
            case .apiKeyInterest: return "Want Your Own API Keys?"
            case .promptCustomization: return "Need Custom Analysis?"
            case .weeklyActive: return "You Love DeepTicker!"
            }
        }
        
        var message: String {
            switch self {
            case .frequentAnalysis(let count):
                return "You've analyzed stocks \(count) times this week. Pro unlocks 5+ AI providers for deeper insights."
            case .multipleTickers(let count):
                return "With \(count) stocks in your portfolio, Pro's advanced analysis tools can help you optimize performance."
            case .apiKeyInterest:
                return "Pro lets you use your own API keys for OpenAI, Claude, and more - often cheaper than commercial plans."
            case .promptCustomization:
                return "Pro users can customize AI prompts to match their exact investment strategy."
            case .weeklyActive(let weeks):
                return "You've used DeepTicker consistently for \(weeks) weeks. Upgrade to unlock the full experience!"
            }
        }
        
        var benefit: String {
            switch self {
            case .frequentAnalysis:
                return "Get more perspectives with multiple AI models"
            case .multipleTickers:
                return "Advanced portfolio optimization & risk analysis"
            case .apiKeyInterest:
                return "Use your own keys = Pay only for what you use"
            case .promptCustomization:
                return "Tailor AI to your exact investment style"
            case .weeklyActive:
                return "Unlock all features you've been missing"
            }
        }
        
        var icon: String {
            switch self {
            case .frequentAnalysis: return "bolt.fill"
            case .multipleTickers: return "chart.bar.fill"
            case .apiKeyInterest: return "key.fill"
            case .promptCustomization: return "doc.text.fill"
            case .weeklyActive: return "heart.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .frequentAnalysis: return .orange
            case .multipleTickers: return .blue
            case .apiKeyInterest: return .purple
            case .promptCustomization: return .green
            case .weeklyActive: return .pink
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Close button
            HStack {
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            
            VStack(spacing: 24) {
                // Icon
                ZStack {
                    Circle()
                        .fill(trigger.color.opacity(0.2))
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: trigger.icon)
                        .font(.system(size: 36))
                        .foregroundStyle(trigger.color)
                }
                
                // Title
                Text(trigger.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                // Message
                Text(trigger.message)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                // Benefit highlight
                HStack(spacing: 12) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(.yellow)
                    
                    Text(trigger.benefit)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                }
                .padding()
                .background(trigger.color.opacity(0.1))
                .cornerRadius(12)
                .padding(.horizontal)
                
                // Pro features preview
                VStack(alignment: .leading, spacing: 12) {
                    QuickFeatureRow(
                        icon: "brain.head.profile",
                        text: "5+ AI Providers",
                        color: .purple
                    )
                    QuickFeatureRow(
                        icon: "doc.text.fill",
                        text: "Custom Prompts",
                        color: .blue
                    )
                    QuickFeatureRow(
                        icon: "infinity",
                        text: "Lifetime Updates",
                        color: .green
                    )
                }
                .padding()
                .background(.regularMaterial)
                .cornerRadius(12)
                .padding(.horizontal)
                
                // CTA Buttons
                VStack(spacing: 12) {
                    Button {
                        showFullUpgrade = true
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
                        dismiss()
                    } label: {
                        Text("Maybe Later")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .background(.regularMaterial)
        .sheet(isPresented: $showFullUpgrade) {
            NavigationStack {
                UpgradeToProView()
            }
        }
    }
}

struct QuickFeatureRow: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 20)
            
            Text(text)
                .font(.subheadline)
            
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        }
    }
}

// MARK: - Usage Tracking Helper

/// Helper to track user behavior and determine when to show upgrade prompts
@MainActor
class UpgradeSuggestionManager: ObservableObject {
    static let shared = UpgradeSuggestionManager()
    
    @Published var shouldShowSuggestion = false
    @Published var suggestedTrigger: PersonalizedUpgradeSuggestion.UpgradeTrigger?
    
    private init() {}
    
    // Track analysis count
    func trackAnalysis() {
        let count = incrementAnalysisCount()
        
        // Show upgrade suggestion after 10 analyses in a week
        if count == 10 {
            suggestedTrigger = .frequentAnalysis(count: count)
            shouldShowSuggestion = true
        }
    }
    
    // Track portfolio size
    func checkPortfolioSize(_ count: Int) {
        // Show suggestion when portfolio hits 10 stocks
        if count == 10 {
            suggestedTrigger = .multipleTickers(count: count)
            shouldShowSuggestion = true
        }
    }
    
    // Track weekly usage
    func trackWeeklyActive() {
        let weeks = getWeeksActive()
        
        // Show after 2 weeks of consistent use
        if weeks == 2 {
            suggestedTrigger = .weeklyActive(weeks: weeks)
            shouldShowSuggestion = true
        }
    }
    
    // Track interest in API keys
    func trackAPIKeyInterest() {
        suggestedTrigger = .apiKeyInterest
        shouldShowSuggestion = true
    }
    
    // Track prompt customization attempts
    func trackPromptCustomizationAttempt() {
        suggestedTrigger = .promptCustomization
        shouldShowSuggestion = true
    }
    
    // MARK: - Private Helpers
    
    private func incrementAnalysisCount() -> Int {
        let key = "weeklyAnalysisCount"
        let count = UserDefaults.standard.integer(forKey: key)
        let newCount = count + 1
        UserDefaults.standard.set(newCount, forKey: key)
        return newCount
    }
    
    private func getWeeksActive() -> Int {
        // Implementation: Track weeks where user was active
        return UserDefaults.standard.integer(forKey: "weeksActive")
    }
    
    // Reset counters weekly
    func resetWeeklyCounters() {
        UserDefaults.standard.set(0, forKey: "weeklyAnalysisCount")
    }
}

// MARK: - View Extension

extension View {
    func personalizedUpgradeSuggestion() -> some View {
        modifier(PersonalizedUpgradeSuggestionModifier())
    }
}

struct PersonalizedUpgradeSuggestionModifier: ViewModifier {
    @StateObject private var manager = UpgradeSuggestionManager.shared
    
    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $manager.shouldShowSuggestion) {
                if let trigger = manager.suggestedTrigger {
                    PersonalizedUpgradeSuggestion(trigger: trigger)
                        .presentationDetents([.medium, .large])
                        .presentationDragIndicator(.visible)
                }
            }
    }
}

#Preview("Frequent Analysis") {
    PersonalizedUpgradeSuggestion(
        trigger: .frequentAnalysis(count: 15)
    )
}

#Preview("Multiple Tickers") {
    PersonalizedUpgradeSuggestion(
        trigger: .multipleTickers(count: 12)
    )
}

#Preview("API Key Interest") {
    PersonalizedUpgradeSuggestion(
        trigger: .apiKeyInterest
    )
}
