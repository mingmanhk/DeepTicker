import SwiftUI

/// Detailed comparison between Free and Pro versions
struct FeatureComparisonSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showUpgrade = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    // Header
                    VStack(spacing: 12) {
                        HStack(spacing: 20) {
                            VStack {
                                Image(systemName: "checkmark.circle")
                                    .font(.largeTitle)
                                    .foregroundStyle(.blue)
                                
                                Text("Free")
                                    .font(.title3)
                                    .fontWeight(.bold)
                            }
                            
                            VStack {
                                Image(systemName: "star.circle.fill")
                                    .font(.largeTitle)
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [.yellow, .orange],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                
                                Text("Pro")
                                    .font(.title3)
                                    .fontWeight(.bold)
                            }
                        }
                        .padding(.top)
                    }
                    
                    // Categories
                    VStack(spacing: 24) {
                        FeatureCategory(
                            title: "Core Features",
                            icon: "briefcase.fill",
                            features: [
                                ("Portfolio Tracking", true, true),
                                ("Real-time Prices", true, true),
                                ("Market Data", true, true),
                                ("Performance Analytics", true, true)
                            ]
                        )
                        
                        FeatureCategory(
                            title: "AI Analysis",
                            icon: "brain.head.profile",
                            features: [
                                ("DeepSeek AI", true, true),
                                ("OpenAI GPT-4", false, true),
                                ("Anthropic Claude", false, true),
                                ("Google Gemini", false, true),
                                ("Azure OpenAI", false, true)
                            ]
                        )
                        
                        FeatureCategory(
                            title: "Customization",
                            icon: "slider.horizontal.3",
                            features: [
                                ("Basic Prompts", true, true),
                                ("Custom Prompts", false, true),
                                ("Prompt Templates", false, true),
                                ("Save Preferences", false, true)
                            ]
                        )
                        
                        FeatureCategory(
                            title: "Advanced Tools",
                            icon: "wrench.and.screwdriver.fill",
                            features: [
                                ("Risk Analysis", true, true),
                                ("Portfolio Optimization", false, true),
                                ("Sector Analysis", false, true),
                                ("Custom Indicators", false, true)
                            ]
                        )
                        
                        FeatureCategory(
                            title: "Support & Updates",
                            icon: "lifepreserver.fill",
                            features: [
                                ("Email Support", true, true),
                                ("Priority Support", false, true),
                                ("Feature Updates", true, true),
                                ("Beta Access", false, true)
                            ]
                        )
                    }
                    
                    // Pricing
                    VStack(spacing: 16) {
                        HStack(alignment: .top, spacing: 20) {
                            // Free Pricing
                            VStack(spacing: 8) {
                                Text("FREE")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                
                                Text("Forever")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.regularMaterial)
                            .cornerRadius(12)
                            
                            // Pro Pricing
                            VStack(spacing: 8) {
                                Text("One-Time")
                                    .font(.headline)
                                    .foregroundStyle(.secondary)
                                
                                Text("$X.XX")
                                    .font(.title)
                                    .fontWeight(.bold)
                                
                                Text("No subscription")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                LinearGradient(
                                    colors: [.yellow.opacity(0.2), .orange.opacity(0.15)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(
                                        LinearGradient(
                                            colors: [.yellow, .orange],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 2
                                    )
                            )
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal)
                    
                    // CTA Button
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
                    .padding(.horizontal)
                    .padding(.bottom)
                }
            }
            .navigationTitle("Compare Plans")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
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
}

struct FeatureCategory: View {
    let title: String
    let icon: String
    let features: [(name: String, free: Bool, pro: Bool)]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Category Header
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(.blue)
                
                Text(title)
                    .font(.headline)
            }
            .padding(.horizontal)
            
            // Feature Rows
            VStack(spacing: 0) {
                ForEach(features.indices, id: \.self) { index in
                    let feature = features[index]
                    
                    HStack {
                        Text(feature.name)
                            .font(.subheadline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        // Free column
                        Image(systemName: feature.free ? "checkmark" : "xmark")
                            .foregroundStyle(feature.free ? .green : .secondary)
                            .frame(width: 60)
                        
                        // Pro column
                        Image(systemName: feature.pro ? "checkmark" : "xmark")
                            .foregroundStyle(feature.pro ? .green : .secondary)
                            .frame(width: 60)
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal)
                    .background(index % 2 == 0 ? Color.clear : Color.primary.opacity(0.03))
                    
                    if index < features.count - 1 {
                        Divider()
                            .padding(.leading)
                    }
                }
            }
            .background(.regularMaterial)
            .cornerRadius(12)
            .padding(.horizontal)
        }
    }
}

#Preview {
    FeatureComparisonSheet()
}
