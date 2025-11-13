import SwiftUI

/// A view modifier that gates content behind Pro subscription
struct ProFeatureGate: ViewModifier {
    @StateObject private var aiSettings = AISettingsViewModel.shared
    @State private var showUpgradeSheet = false
    
    let feature: String
    
    func body(content: Content) -> some View {
        if aiSettings.isPremium {
            content
        } else {
            Button {
                showUpgradeSheet = true
            } label: {
                content
                    .overlay {
                        ZStack {
                            // Blur the locked content
                            Rectangle()
                                .fill(.ultraThinMaterial)
                            
                            // Show lock icon
                            VStack(spacing: 8) {
                                Image(systemName: "lock.fill")
                                    .font(.title)
                                    .foregroundStyle(.secondary)
                                
                                Text("Pro Feature")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.secondary)
                                
                                Text("Tap to Upgrade")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
            }
            .disabled(true)
            .sheet(isPresented: $showUpgradeSheet) {
                NavigationStack {
                    UpgradeToProView()
                }
            }
        }
    }
}

extension View {
    /// Gates this view behind Pro subscription
    /// - Parameter feature: The name of the feature being gated (for analytics)
    func requiresPro(feature: String = "Unknown") -> some View {
        modifier(ProFeatureGate(feature: feature))
    }
}

/// A wrapper view that shows upgrade prompt when Pro is required
struct ProFeatureView<Content: View, Placeholder: View>: View {
    @StateObject private var aiSettings = AISettingsViewModel.shared
    @State private var showUpgradeSheet = false
    
    let content: () -> Content
    let placeholder: () -> Placeholder
    let featureName: String
    
    init(
        featureName: String,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.featureName = featureName
        self.content = content
        self.placeholder = placeholder
    }
    
    var body: some View {
        if aiSettings.isPremium {
            content()
        } else {
            Button {
                showUpgradeSheet = true
            } label: {
                VStack(spacing: 16) {
                    placeholder()
                        .blur(radius: 3)
                        .allowsHitTesting(false)
                    
                    VStack(spacing: 8) {
                        Image(systemName: "star.circle.fill")
                            .font(.largeTitle)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.yellow, .orange],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        
                        Text("\(featureName) requires Pro")
                            .font(.headline)
                        
                        Text("Tap to upgrade and unlock")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.up")
                                .font(.caption2)
                            Text("Upgrade")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(.blue)
                        .foregroundStyle(.white)
                        .cornerRadius(20)
                        .padding(.top, 4)
                    }
                }
                .padding()
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showUpgradeSheet) {
                NavigationStack {
                    UpgradeToProView()
                }
            }
        }
    }
}

// Convenience initializer when no placeholder is needed
extension ProFeatureView where Placeholder == EmptyView {
    init(
        featureName: String,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.featureName = featureName
        self.content = content
        self.placeholder = { EmptyView() }
    }
}

#Preview("Locked Feature") {
    VStack(spacing: 20) {
        // Example 1: Using view modifier
        VStack {
            Text("Custom Prompt Editor")
                .font(.headline)
            
            TextEditor(text: .constant("Analyze this stock..."))
                .frame(height: 100)
        }
        .requiresPro(feature: "Custom Prompts")
        .padding()
        
        // Example 2: Using ProFeatureView wrapper
        ProFeatureView(
            featureName: "Advanced AI Providers",
            content: {
                VStack {
                    Text("OpenAI GPT-4")
                    Text("Anthropic Claude")
                    Text("Google Gemini")
                }
            },
            placeholder: {
                VStack {
                    Text("AI Provider")
                    Text("Premium Content")
                }
            }
        )
    }
    .padding()
}
