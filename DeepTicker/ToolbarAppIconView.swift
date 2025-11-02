import SwiftUI

/// A reusable toolbar app icon component that can be used across different tabs
struct ToolbarAppIconView: View {
    let showAppName: Bool
    let onTap: (() -> Void)?
    
    init(showAppName: Bool = true, onTap: (() -> Void)? = nil) {
        self.showAppName = showAppName
        self.onTap = onTap
    }
    
    var body: some View {
        Button {
            onTap?()
        } label: {
            if showAppName {
                HStack(spacing: 8) {
                    AppIconView(size: 28, cornerRadius: 6)
                    
                    if let appName = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ??
                                   Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String {
                        Text(appName)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 8))
            } else {
                AppIconView(size: 28, cornerRadius: 6)
                    .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 6))
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("App Icon - \(Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "Investment App")")
        .accessibilityHint("Identifies this as your investment tracking app")
    }
}

// MARK: - Convenience Extensions

extension View {
    /// Adds an app icon to the leading toolbar item
    /// - Parameters:
    ///   - showAppName: Whether to show the app name alongside the icon
    ///   - onTap: Optional action to perform when the icon is tapped
    /// - Returns: A view with the app icon in the toolbar
    func appIconToolbar(showAppName: Bool = true, onTap: (() -> Void)? = nil) -> some View {
        self.toolbar {
            ToolbarItem(placement: .topBarLeading) {
                ToolbarAppIconView(showAppName: showAppName, onTap: onTap)
            }
        }
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        VStack {
            Text("Your App Content")
                .font(.largeTitle)
                .padding()
            
            Spacer()
        }
        .navigationTitle("Investment Tab")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                ToolbarAppIconView(showAppName: true) {
                    print("App icon tapped!")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Action") {
                    // Action
                }
            }
        }
    }
}