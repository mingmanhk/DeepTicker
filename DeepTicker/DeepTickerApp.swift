import SwiftUI

@main
struct DeepTickerApp: App {
    @StateObject private var portfolio = PortfolioStore.shared
    @StateObject private var settingsManager = SettingsManager.shared
    @StateObject private var dataRefreshManager = DataRefreshManager.shared
    @StateObject private var cacheManager = SmartCacheManager.shared

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
