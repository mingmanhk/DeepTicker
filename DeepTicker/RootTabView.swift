import SwiftUI
import BackgroundTasks

struct RootTabView: View {
    @StateObject private var aiNewsProvider = AINewsProvider()
    @EnvironmentObject var portfolioStore: PortfolioStore
    @EnvironmentObject var dataRefreshManager: DataRefreshManager
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView {
            StocksTabView(aiNewsProvider: aiNewsProvider)
                .environmentObject(portfolioStore)
                .tabItem {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(AppDesignSystem.Typography.footnote)
                    Text("Portfolio")
                        .font(AppDesignSystem.Typography.caption2)
                }

            AINewsTabView(provider: aiNewsProvider)
                .environmentObject(portfolioStore)
                .tabItem {
                    Image(systemName: "bolt.horizontal.fill")
                        .font(AppDesignSystem.Typography.footnote)
                    Text("AI Insights")
                        .font(AppDesignSystem.Typography.caption2)
                }

            SettingsView()
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
                await dataRefreshManager.refreshAllData(force: false)
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
        .environmentObject(PortfolioStore.preview)
        .environmentObject(DataRefreshManager.shared)
}
