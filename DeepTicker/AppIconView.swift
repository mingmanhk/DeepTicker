import SwiftUI
import UIKit

/// A reusable view that displays the app's icon with optimized caching
struct AppIconView: View {
    let size: CGFloat
    let cornerRadius: CGFloat
    
    // ⚡ Performance: Cache the icon statically to avoid repeated bundle queries
    private static let cachedAppIcon: UIImage? = {
        getAppIconFromBundle()
    }()
    
    init(size: CGFloat = 28, cornerRadius: CGFloat = 6) {
        self.size = size
        self.cornerRadius = cornerRadius
    }
    
    var body: some View {
        Group {
            if let appIcon = Self.cachedAppIcon {
                Image(uiImage: appIcon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                // Fallback to a custom investment-themed icon
                fallbackIcon
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
    
    // ⚡ Performance: Extract fallback icon as a computed property to avoid rebuilding
    private var fallbackIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius * 0.7)
                .fill(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: size * 0.5, weight: .semibold))
                .foregroundStyle(.white)
        }
    }
    
    /// Attempts to get the app icon from the bundle (called once and cached)
    private static func getAppIconFromBundle() -> UIImage? {
        // Method 1: Try to get from CFBundleIconFiles
        if let iconFiles = Bundle.main.object(forInfoDictionaryKey: "CFBundleIcons") as? [String: Any],
           let primaryIcon = iconFiles["CFBundlePrimaryIcon"] as? [String: Any],
           let iconFileNames = primaryIcon["CFBundleIconFiles"] as? [String] {
            
            // Start with largest sizes first
            for iconName in iconFileNames.reversed() {
                if let image = UIImage(named: iconName) {
                    return image
                }
            }
        }
        
        // Method 2: Try common icon names (prioritize high-res versions)
        let commonIconNames = [
            "AppIcon60x60@3x",
            "AppIcon60x60@2x",
            "AppIcon60x60",
            "AppIcon",
            "Icon-60@3x",
            "Icon-60@2x",
            "Icon-60"
        ]
        
        for iconName in commonIconNames {
            if let image = UIImage(named: iconName) {
                return image
            }
        }
        
        // Method 3: Try alternate app icons (if your app supports them)
        if let alternateIcons = Bundle.main.object(forInfoDictionaryKey: "CFBundleIcons") as? [String: Any],
           let alternateIconDict = alternateIcons["CFBundleAlternateIcons"] as? [String: Any] {
            
            for (_, iconData) in alternateIconDict {
                if let iconInfo = iconData as? [String: Any],
                   let iconFiles = iconInfo["CFBundleIconFiles"] as? [String],
                   let iconName = iconFiles.first,
                   let image = UIImage(named: iconName) {
                    return image
                }
            }
        }
        
        return nil
    }
}

// MARK: - Preview
#Preview("App Icon Sizes") {
    VStack(spacing: 20) {
        HStack(spacing: 12) {
            AppIconView(size: 32, cornerRadius: 8)
            AppIconView(size: 48, cornerRadius: 12)
            AppIconView(size: 64, cornerRadius: 16)
        }
        
        Text("⚡ Icons are cached statically")
            .font(.caption)
            .foregroundStyle(.secondary)
        
        Text("Loaded once per app lifecycle")
            .font(.caption2)
            .foregroundStyle(.tertiary)
    }
    .padding()
}