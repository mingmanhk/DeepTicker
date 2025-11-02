import SwiftUI
import UIKit

/// A reusable view that displays the app's icon
struct AppIconView: View {
    let size: CGFloat
    let cornerRadius: CGFloat
    
    init(size: CGFloat = 28, cornerRadius: CGFloat = 6) {
        self.size = size
        self.cornerRadius = cornerRadius
    }
    
    var body: some View {
        Group {
            if let appIcon = getAppIcon() {
                Image(uiImage: appIcon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                // Fallback to a custom investment-themed icon
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
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
    
    /// Attempts to get the app icon from the bundle
    private func getAppIcon() -> UIImage? {
        // Method 1: Try to get from CFBundleIconFiles
        if let iconFiles = Bundle.main.object(forInfoDictionaryKey: "CFBundleIcons") as? [String: Any],
           let primaryIcon = iconFiles["CFBundlePrimaryIcon"] as? [String: Any],
           let iconFileNames = primaryIcon["CFBundleIconFiles"] as? [String] {
            
            for iconName in iconFileNames.reversed() { // Start with largest sizes
                if let image = UIImage(named: iconName) {
                    return image
                }
            }
        }
        
        // Method 2: Try common icon names
        let commonIconNames = [
            "AppIcon",
            "AppIcon60x60",
            "AppIcon60x60@2x",
            "AppIcon60x60@3x",
            "Icon-60",
            "Icon-60@2x",
            "Icon-60@3x"
        ]
        
        for iconName in commonIconNames {
            if let image = UIImage(named: iconName) {
                return image
            }
        }
        
        // Method 3: Try to load from alternate app icons (if your app supports them)
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
#Preview {
    VStack(spacing: 20) {
        AppIconView(size: 32, cornerRadius: 8)
        AppIconView(size: 48, cornerRadius: 12)
        AppIconView(size: 64, cornerRadius: 16)
    }
    .padding()
}