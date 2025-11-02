import SwiftUI

// MARK: - Design System

struct AppDesignSystem {
    
    // MARK: - Typography
    struct Typography {
        static let largeTitle = Font.system(.largeTitle, design: .rounded, weight: .bold)
        static let title1 = Font.system(.title, design: .rounded, weight: .bold)
        static let title2 = Font.system(.title2, design: .rounded, weight: .semibold)
        static let title3 = Font.system(.title3, design: .rounded, weight: .semibold)
        static let headline = Font.system(.headline, design: .rounded, weight: .semibold)
        static let body = Font.system(.body, design: .rounded)
        static let callout = Font.system(.callout, design: .rounded)
        static let subheadline = Font.system(.subheadline, design: .rounded)
        static let footnote = Font.system(.footnote, design: .rounded)
        static let caption1 = Font.system(.caption, design: .rounded)
        static let caption2 = Font.system(.caption2, design: .rounded)
        
        // Brand specific
        static let brandTitle = Font.system(size: 32, weight: .bold, design: .rounded)
        static let sectionHeader = Font.system(.headline, design: .rounded, weight: .medium)
    }
    
    // MARK: - Colors
    struct Colors {
        static let primary = Color.accentColor
        static let secondary = Color.secondary
        static let tertiary = Color(.tertiaryLabel)
        
        // Financial colors
        static let profit = Color.green
        static let loss = Color.red
        static let neutral = Color.secondary
        
        // Background materials
        static let cardBackground = Color(.systemBackground)
        static let sectionBackground = Color(.secondarySystemBackground)
        static let surfaceBackground = Material.thin
        static let elevatedBackground = Material.regular
        
        // Status colors
        static let success = Color.green
        static let warning = Color.orange
        static let error = Color.red
        static let info = Color.blue
    }
    
    // MARK: - Spacing
    struct Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
        static let xxxl: CGFloat = 32
    }
    
    // MARK: - Corner Radius
    struct CornerRadius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
    }
    
    // MARK: - Shadows
    struct Shadow {
        static let light = Shadow(color: .black.opacity(0.1), radius: 4, y: 2)
        static let medium = Shadow(color: .black.opacity(0.15), radius: 8, y: 4)
        static let heavy = Shadow(color: .black.opacity(0.2), radius: 16, y: 8)
        
        let color: Color
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat
        
        init(color: Color, radius: CGFloat, x: CGFloat = 0, y: CGFloat = 0) {
            self.color = color
            self.radius = radius
            self.x = x
            self.y = y
        }
    }
}

// MARK: - Reusable Components

struct AppCard<Content: View>: View {
    let content: Content
    let padding: CGFloat
    let cornerRadius: CGFloat
    
    init(
        padding: CGFloat = AppDesignSystem.Spacing.lg,
        cornerRadius: CGFloat = AppDesignSystem.CornerRadius.md,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.padding = padding
        self.cornerRadius = cornerRadius
    }
    
    var body: some View {
        content
            .padding(padding)
            .background(AppDesignSystem.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .shadow(
                color: AppDesignSystem.Shadow.light.color,
                radius: AppDesignSystem.Shadow.light.radius,
                x: AppDesignSystem.Shadow.light.x,
                y: AppDesignSystem.Shadow.light.y
            )
    }
}

struct AppSection<Header: View, Content: View>: View {
    let header: Header
    let content: Content
    
    init(
        @ViewBuilder header: () -> Header,
        @ViewBuilder content: () -> Content
    ) {
        self.header = header()
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppDesignSystem.Spacing.md) {
            header
                .font(AppDesignSystem.Typography.sectionHeader)
                .foregroundColor(AppDesignSystem.Colors.primary)
            
            content
        }
    }
}

struct AppButton: View {
    enum Style {
        case primary
        case secondary
        case tertiary
        case destructive
    }
    
    let title: String
    let style: Style
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(AppDesignSystem.Typography.headline)
                .foregroundColor(foregroundColor)
                .padding(.horizontal, AppDesignSystem.Spacing.xl)
                .padding(.vertical, AppDesignSystem.Spacing.md)
                .background(backgroundColor)
                .clipShape(RoundedRectangle(cornerRadius: AppDesignSystem.CornerRadius.sm))
        }
        .buttonStyle(.plain)
    }
    
    private var backgroundColor: Color {
        switch style {
        case .primary:
            return AppDesignSystem.Colors.primary
        case .secondary:
            return AppDesignSystem.Colors.sectionBackground
        case .tertiary:
            return Color.clear
        case .destructive:
            return AppDesignSystem.Colors.error
        }
    }
    
    private var foregroundColor: Color {
        switch style {
        case .primary, .destructive:
            return .white
        case .secondary, .tertiary:
            return AppDesignSystem.Colors.primary
        }
    }
}

struct AppHeaderView: View {
    let title: String
    let subtitle: String?
    let showLogo: Bool
    
    init(_ title: String, subtitle: String? = nil, showLogo: Bool = true) {
        self.title = title
        self.subtitle = subtitle
        self.showLogo = showLogo
    }
    
    var body: some View {
        HStack(alignment: .center, spacing: AppDesignSystem.Spacing.md) {
            if showLogo {
                Image("logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 40, height: 40)
            }
            
            VStack(alignment: .leading, spacing: AppDesignSystem.Spacing.xs) {
                Text(title)
                    .font(AppDesignSystem.Typography.brandTitle)
                    .foregroundColor(.primary)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(AppDesignSystem.Typography.subheadline)
                        .foregroundColor(AppDesignSystem.Colors.secondary)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, AppDesignSystem.Spacing.lg)
        .padding(.vertical, AppDesignSystem.Spacing.md)
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let change: String?
    let changeColor: Color?
    let icon: String?
    
    init(title: String, value: String, change: String? = nil, changeColor: Color? = nil, icon: String? = nil) {
        self.title = title
        self.value = value
        self.change = change
        self.changeColor = changeColor
        self.icon = icon
    }
    
    var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppDesignSystem.Spacing.sm) {
                HStack {
                    Text(title)
                        .font(AppDesignSystem.Typography.caption1)
                        .foregroundColor(AppDesignSystem.Colors.secondary)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    if let icon = icon {
                        Image(systemName: icon)
                            .font(AppDesignSystem.Typography.caption1)
                            .foregroundColor(AppDesignSystem.Colors.tertiary)
                    }
                }
                
                Text(value)
                    .font(AppDesignSystem.Typography.title2)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                
                if let change = change {
                    Text(change)
                        .font(AppDesignSystem.Typography.footnote)
                        .foregroundColor(changeColor ?? AppDesignSystem.Colors.secondary)
                        .fontWeight(.medium)
                }
            }
        }
        .frame(minHeight: 100)
    }
}

// MARK: - View Extensions

extension View {
    func appNavigationStyle() -> some View {
        self
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(AppDesignSystem.Colors.surfaceBackground, for: .navigationBar)
    }
    
    func appListStyle() -> some View {
        self
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(AppDesignSystem.Colors.surfaceBackground)
    }
    
    func appCardStyle() -> some View {
        self
            .background(AppDesignSystem.Colors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppDesignSystem.CornerRadius.md))
            .shadow(
                color: AppDesignSystem.Shadow.light.color,
                radius: AppDesignSystem.Shadow.light.radius,
                x: AppDesignSystem.Shadow.light.x,
                y: AppDesignSystem.Shadow.light.y
            )
    }
}