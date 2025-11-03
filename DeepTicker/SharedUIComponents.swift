import SwiftUI

// MARK: - Reusable UI Components

struct ModernPanel<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppDesignSystem.Spacing.lg) {
            content
        }
        .padding(AppDesignSystem.Spacing.lg)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AppDesignSystem.CornerRadius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: AppDesignSystem.CornerRadius.lg)
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        )
    }
}

struct PanelHeader: View {
    let title: String
    let subtitle: String?
    let icon: String
    let iconColor: Color
    var lastUpdate: Date? = nil
    var isLoading: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: AppDesignSystem.Spacing.sm) {
            HStack(spacing: AppDesignSystem.Spacing.md) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(iconColor)
                    .frame(width: 32, height: 32)
                    .background(iconColor.opacity(0.15))
                    .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: AppDesignSystem.Spacing.xs) {
                    Text(title)
                        .font(AppDesignSystem.Typography.headline)
                        .fontWeight(.bold)
                    
                    if let subtitle = subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(AppDesignSystem.Typography.caption1)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            
            if let lastUpdate = lastUpdate, !isLoading {
                StatusIndicator(
                    icon: "clock.fill",
                    text: "Updated \(formattedRelativeDate(from: lastUpdate))"
                )
            }
        }
    }

    private func formattedRelativeDate(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.dateTimeStyle = .named
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct CollapsiblePanelHeader: View {
    let title: String
    let subtitle: String?
    let icon: String
    let iconColor: Color
    var lastUpdate: Date? = nil
    var isLoading: Bool = false
    @Binding var isCollapsed: Bool
    
    var body: some View {
        Button(action: {
            withAnimation(.easeInOut) {
                isCollapsed.toggle()
            }
        }) {
            HStack(spacing: AppDesignSystem.Spacing.md) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(iconColor)
                    .frame(width: 32, height: 32)
                    .background(iconColor.opacity(0.15))
                    .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: AppDesignSystem.Spacing.xs) {
                    Text(title)
                        .font(AppDesignSystem.Typography.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)
                    
                    if let subtitle = subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(AppDesignSystem.Typography.caption1)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                if isLoading {
                    ProgressView().scaleEffect(0.8)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isCollapsed ? 0 : 90))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}


struct EnhancedAIProviderCard: View {
    let provider: AIProvider
    let isSelected: Bool
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppDesignSystem.Spacing.sm) {
                Image(systemName: provider.iconName)
                    .font(.callout)
                    .foregroundStyle(isSelected ? .white : provider.primaryColor)
                    .frame(width: 24, height: 24)

                Text(provider.displayName)
                    .font(AppDesignSystem.Typography.caption1)
                    .fontWeight(.semibold)
                    .foregroundStyle(isSelected ? .white : .primary)
                
                Spacer()

                if isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                        .tint(isSelected ? .white : provider.primaryColor)
                }
            }
            .padding(.horizontal, AppDesignSystem.Spacing.md)
            .padding(.vertical, AppDesignSystem.Spacing.sm)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: AppDesignSystem.CornerRadius.md)
                        .fill(provider.primaryColor.gradient)
                        .shadow(color: provider.primaryColor.opacity(0.4), radius: 5, y: 2)
                } else {
                    RoundedRectangle(cornerRadius: AppDesignSystem.CornerRadius.md)
                        .fill(.regularMaterial)
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: AppDesignSystem.CornerRadius.md)
                    .stroke(isSelected ? .clear : Color.primary.opacity(0.1), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.03 : 1.0)
    }
}

struct LoadingView: View {
    let message: String
    
    var body: some View {
        VStack(spacing: AppDesignSystem.Spacing.md) {
            ProgressView()
            Text(message)
                .font(AppDesignSystem.Typography.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppDesignSystem.Spacing.xxl)
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    
    var body: some View {
        VStack(spacing: AppDesignSystem.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(AppDesignSystem.Colors.secondary)
            
            VStack(spacing: AppDesignSystem.Spacing.xs) {
                Text(title)
                    .font(AppDesignSystem.Typography.headline)
                    .fontWeight(.semibold)
                
                Text(message)
                    .font(AppDesignSystem.Typography.callout)
                    .foregroundStyle(AppDesignSystem.Colors.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppDesignSystem.Spacing.xxl)
    }
}

struct ErrorStateView: View {
    let error: Error
    var onRetry: (() -> Void)? = nil
    
    var body: some View {
        VStack(spacing: AppDesignSystem.Spacing.lg) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(AppDesignSystem.Colors.warning)
            
            VStack(spacing: AppDesignSystem.Spacing.xs) {
                Text("An Error Occurred")
                    .font(AppDesignSystem.Typography.headline)
                    .fontWeight(.semibold)
                
                Text(error.localizedDescription)
                    .font(AppDesignSystem.Typography.callout)
                    .foregroundStyle(AppDesignSystem.Colors.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            if let onRetry = onRetry {
                Button("Retry", action: onRetry)
                    .buttonStyle(.bordered)
                    .tint(AppDesignSystem.Colors.primary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppDesignSystem.Spacing.xxl)
    }
}

struct StatusIndicator: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: AppDesignSystem.Spacing.xs) {
            Image(systemName: icon)
                .font(AppDesignSystem.Typography.caption2)
            Text(text)
                .font(AppDesignSystem.Typography.caption2)
        }
        .foregroundStyle(AppDesignSystem.Colors.secondary)
    }
}
