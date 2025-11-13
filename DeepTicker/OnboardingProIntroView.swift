import SwiftUI

/// A soft paywall shown during onboarding to introduce Pro features
/// This doesn't block users but makes them aware of premium options early
struct OnboardingProIntroView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showUpgrade = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 16) {
                Image(systemName: "sparkles")
                    .font(.system(size: 50))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.yellow, .orange, .pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .padding(.top, 40)
                
                Text("Supercharge Your Portfolio")
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text("Get the most out of DeepTicker with Pro features")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding(.bottom, 32)
            
            // Comparison: Free vs Pro
            HStack(spacing: 12) {
                // Free Column
                VStack(spacing: 16) {
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.circle")
                            .font(.title2)
                            .foregroundStyle(.blue)
                        
                        Text("Free")
                            .font(.headline)
                    }
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 12) {
                        ComparisonRow(
                            icon: "briefcase",
                            text: "Portfolio Tracking",
                            available: true
                        )
                        
                        ComparisonRow(
                            icon: "chart.line.uptrend.xyaxis",
                            text: "Real-time Prices",
                            available: true
                        )
                        
                        ComparisonRow(
                            icon: "cpu",
                            text: "DeepSeek AI",
                            available: true
                        )
                        
                        ComparisonRow(
                            icon: "brain.head.profile",
                            text: "5+ AI Providers",
                            available: false
                        )
                        
                        ComparisonRow(
                            icon: "doc.text",
                            text: "Custom Prompts",
                            available: false
                        )
                        
                        ComparisonRow(
                            icon: "sparkles",
                            text: "Future Features",
                            available: false
                        )
                    }
                    
                    Spacer()
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(.regularMaterial)
                .cornerRadius(16)
                
                // Pro Column
                VStack(spacing: 16) {
                    VStack(spacing: 8) {
                        Image(systemName: "star.circle.fill")
                            .font(.title2)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.yellow, .orange],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        
                        Text("Pro")
                            .font(.headline)
                    }
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 12) {
                        ComparisonRow(
                            icon: "briefcase",
                            text: "Portfolio Tracking",
                            available: true
                        )
                        
                        ComparisonRow(
                            icon: "chart.line.uptrend.xyaxis",
                            text: "Real-time Prices",
                            available: true
                        )
                        
                        ComparisonRow(
                            icon: "cpu",
                            text: "DeepSeek AI",
                            available: true
                        )
                        
                        ComparisonRow(
                            icon: "brain.head.profile",
                            text: "5+ AI Providers",
                            available: true,
                            highlight: true
                        )
                        
                        ComparisonRow(
                            icon: "doc.text",
                            text: "Custom Prompts",
                            available: true,
                            highlight: true
                        )
                        
                        ComparisonRow(
                            icon: "sparkles",
                            text: "Future Features",
                            available: true,
                            highlight: true
                        )
                    }
                    
                    Spacer()
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(
                    LinearGradient(
                        colors: [.yellow.opacity(0.1), .orange.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [.yellow, .orange],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                )
                .cornerRadius(16)
            }
            .padding(.horizontal)
            
            Spacer()
            
            // Action Buttons
            VStack(spacing: 12) {
                Button {
                    showUpgrade = true
                } label: {
                    Text("Upgrade to Pro")
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
                    Text("Continue with Free")
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
        }
        .sheet(isPresented: $showUpgrade) {
            NavigationStack {
                UpgradeToProView()
            }
        }
    }
}

struct ComparisonRow: View {
    let icon: String
    let text: String
    let available: Bool
    var highlight: Bool = false
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: available ? "checkmark.circle.fill" : "xmark.circle")
                .font(.caption)
                .foregroundStyle(available ? (highlight ? .yellow : .green) : .secondary)
                .frame(width: 16)
            
            Text(text)
                .font(.caption2)
                .foregroundStyle(available ? .primary : .secondary)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
    }
}

#Preview {
    OnboardingProIntroView()
}
