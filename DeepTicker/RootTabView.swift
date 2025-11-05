import SwiftUI
#if canImport(BackgroundTasks)
import BackgroundTasks
#endif

struct RootTabView: View {
    @EnvironmentObject var portfolioStore: UnifiedPortfolioManager
    @EnvironmentObject var dataRefreshManager: DataRefreshManager
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView {
            ModernMyInvestmentTab()
                .environmentObject(portfolioStore)
                .tabItem {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(AppDesignSystem.Typography.footnote)
                    Text("My Investment")
                        .font(AppDesignSystem.Typography.caption2)
                }

            EnhancedAIInsightsTab()
                .environmentObject(portfolioStore)
                .environmentObject(SettingsManager.shared)
                .tabItem {
                    Image(systemName: "bolt.horizontal.fill")
                        .font(AppDesignSystem.Typography.footnote)
                    Text("AI Insights")
                        .font(AppDesignSystem.Typography.caption2)
                }

            ComprehensiveSettingsView()
                .tabItem {
                    Image(systemName: "gear")
                        .font(AppDesignSystem.Typography.footnote)
                    Text("Settings")
                        .font(AppDesignSystem.Typography.caption2)
                }
        }
        .accentColor(AppDesignSystem.Colors.primary)
        .onChange(of: scenePhase) { _, newPhase in
            handleScenePhaseChange(newPhase)
        }
    }
    
    private func handleScenePhaseChange(_ newPhase: ScenePhase) {
        switch newPhase {
        case .active:
            // App became active - refresh data and schedule background tasks
            Task {
                await portfolioStore.refreshAllPrices()
                if dataRefreshManager.preloadingEnabled {
                    await dataRefreshManager.preloadData()
                }
            }
            
        case .background:
            // App went to background - schedule background refresh
            dataRefreshManager.scheduleBackgroundRefresh()
            
        case .inactive:
            break
            
        @unknown default:
            break
        }
    }
}

#Preview {
    RootTabView()
        .environmentObject(UnifiedPortfolioManager.shared)
        .environmentObject(DataRefreshManager.shared)
        .environmentObject(SettingsManager.shared)
}
