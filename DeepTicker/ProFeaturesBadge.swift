import SwiftUI

/// A compact badge that indicates Pro features and links to the upgrade screen
struct ProFeaturesBadge: View {
    @StateObject private var aiSettings = AISettingsViewModel.shared
    @State private var showUpgradeSheet = false
    
    var body: some View {
        if !aiSettings.isPremium {
            Button {
                showUpgradeSheet = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "star.fill")
                        .font(.caption2)
                    
                    Text("PRO")
                        .font(.caption2)
                        .fontWeight(.bold)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    LinearGradient(
                        colors: [.yellow, .orange],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundStyle(.white)
                .cornerRadius(8)
            }
            .sheet(isPresented: $showUpgradeSheet) {
                NavigationStack {
                    UpgradeToProView()
                }
            }
        }
    }
}

/// A compact inline card showing Pro features - can be embedded in lists or forms
struct ProFeaturesInlineCard: View {
    @StateObject private var aiSettings = AISettingsViewModel.shared
    @State private var showUpgradeSheet = false
    
    var body: some View {
        if !aiSettings.isPremium {
            Button {
                showUpgradeSheet = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "star.circle.fill")
                        .font(.title2)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.yellow, .orange],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Unlock Pro Features")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        
                        Text("Advanced AI providers, custom prompts & more")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(12)
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

#Preview("Badge") {
    ProFeaturesBadge()
}

#Preview("Inline Card") {
    List {
        ProFeaturesInlineCard()
    }
}
