import SwiftUI

@main
struct DeepTickerApp: App {
    // Use explicit types to avoid ambiguity
    @StateObject private var portfolio: UnifiedPortfolioManager = UnifiedPortfolioManager.shared
    @StateObject private var settingsManager: SettingsManager = SettingsManager.shared
    @StateObject private var dataRefreshManager: DataRefreshManager = DataRefreshManager.shared
    @StateObject private var cacheManager: SmartCacheManager = SmartCacheManager.shared

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(portfolio)
                .environmentObject(settingsManager)
                .environmentObject(dataRefreshManager)
                .environmentObject(cacheManager)
                .task {
                    // Initialize background refresh scheduling
                    dataRefreshManager.scheduleBackgroundRefresh()
                    
                    // Preload data if enabled
                    if dataRefreshManager.preloadingEnabled {
                        await dataRefreshManager.preloadData()
                    }
                }
        }
    }
}

