import Foundation
import SwiftUI
import BackgroundTasks
import Combine
import UIKit

// MARK: - Refresh Configuration

enum RefreshFrequency: String, CaseIterable, Codable {
    case realTime = "realtime"
    case fiveMinutes = "5m"
    case fifteenMinutes = "15m"
    case thirtyMinutes = "30m"
    case manual = "manual"
    
    var displayName: String {
        switch self {
        case .realTime: return "Real-time"
        case .fiveMinutes: return "Every 5 minutes"
        case .fifteenMinutes: return "Every 15 minutes"
        case .thirtyMinutes: return "Every 30 minutes"
        case .manual: return "Manual only"
        }
    }
    
    var timeInterval: TimeInterval? {
        switch self {
        case .realTime: return 10.0 // 10 seconds for real-time simulation
        case .fiveMinutes: return 5.0 * 60.0
        case .fifteenMinutes: return 15.0 * 60.0
        case .thirtyMinutes: return 30.0 * 60.0
        case .manual: return nil
        }
    }
    
    var cacheExpiry: TimeInterval {
        switch self {
        case .realTime: return 15.0 // Very short for real-time
        case .fiveMinutes: return 10.0 * 60.0
        case .fifteenMinutes: return 20.0 * 60.0
        case .thirtyMinutes: return 45.0 * 60.0
        case .manual: return 24.0 * 60.0 * 60.0 // 24 hours for manual
        }
    }
}

enum DataType: String, CaseIterable {
    case stockPrices = "stock_prices"
    case aiInsights = "ai_insights"
    case portfolioData = "portfolio_data"
    case marketNews = "market_news"
    
    var displayName: String {
        switch self {
        case .stockPrices: return "Stock Prices"
        case .aiInsights: return "AI Insights"
        case .portfolioData: return "Portfolio Data"
        case .marketNews: return "Market News"
        }
    }
    
    var backgroundTaskIdentifier: String {
        return "com.deepticker.refresh.\(rawValue)"
    }
}

// MARK: - Supporting Models

struct StockData: Sendable {
    let symbol: String
    let currentPrice: Double
    let previousClose: Double
    let change: Double
    let changePercent: Double
    let timestamp: Date
}

// MARK: - Nonisolated Codable Conformances

extension StockData: Codable {
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.symbol = try container.decode(String.self, forKey: .symbol)
        self.currentPrice = try container.decode(Double.self, forKey: .currentPrice)
        self.previousClose = try container.decode(Double.self, forKey: .previousClose)
        self.change = try container.decode(Double.self, forKey: .change)
        self.changePercent = try container.decode(Double.self, forKey: .changePercent)
        self.timestamp = try container.decode(Date.self, forKey: .timestamp)
    }
    
    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(symbol, forKey: .symbol)
        try container.encode(currentPrice, forKey: .currentPrice)
        try container.encode(previousClose, forKey: .previousClose)
        try container.encode(change, forKey: .change)
        try container.encode(changePercent, forKey: .changePercent)
        try container.encode(timestamp, forKey: .timestamp)
    }
    
    private enum CodingKeys: String, CodingKey {
        case symbol
        case currentPrice
        case previousClose
        case change
        case changePercent
        case timestamp
    }
}

extension AIInsight: Codable {
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.symbol = try container.decode(String.self, forKey: .symbol)
        self.profitLikelihood = try container.decodeIfPresent(Double.self, forKey: .profitLikelihood)
        self.forecastedGain = try container.decodeIfPresent(Double.self, forKey: .forecastedGain)
        self.confidence = try container.decodeIfPresent(Double.self, forKey: .confidence)
        self.upside = try container.decodeIfPresent(Double.self, forKey: .upside)
        self.factors = try container.decode([String].self, forKey: .factors)
        self.timestamp = try container.decode(Date.self, forKey: .timestamp)
    }
    
    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(symbol, forKey: .symbol)
        try container.encodeIfPresent(profitLikelihood, forKey: .profitLikelihood)
        try container.encodeIfPresent(forecastedGain, forKey: .forecastedGain)
        try container.encodeIfPresent(confidence, forKey: .confidence)
        try container.encodeIfPresent(upside, forKey: .upside)
        try container.encode(factors, forKey: .factors)
        try container.encode(timestamp, forKey: .timestamp)
    }
    
    private enum CodingKeys: String, CodingKey {
        case symbol
        case profitLikelihood
        case forecastedGain
        case confidence
        case upside
        case factors
        case timestamp
    }
}

struct AIInsight: Sendable {
    let symbol: String
    let profitLikelihood: Double?
    let forecastedGain: Double?
    let confidence: Double?
    let upside: Double?
    let factors: [String]
    let timestamp: Date
}

extension MarketNews: Codable {
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.title = try container.decode(String.self, forKey: .title)
        self.content = try container.decode(String.self, forKey: .content)
        self.timestamp = try container.decode(Date.self, forKey: .timestamp)
    }
    
    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(content, forKey: .content)
        try container.encode(timestamp, forKey: .timestamp)
    }
    
    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case content
        case timestamp
    }
}

struct MarketNews: Identifiable, Sendable {
    let id: UUID
    let title: String
    let content: String
    let timestamp: Date
}

// MARK: - Data Refresh Manager

@MainActor
class DataRefreshManager: ObservableObject {
    static let shared = DataRefreshManager()
    
    @Published var refreshSettings: [DataType: RefreshFrequency] = [:]
    @Published var lastRefreshTimes: [DataType: Date] = [:]
    @Published var isRefreshing: [DataType: Bool] = [:]
    @Published var refreshErrors: [DataType: Error?] = [:]
    @Published var lastDataSource: StockQuote.DataSource? = nil
    
    private let cache = SmartCacheManager.shared
    private var refreshTimers: [DataType: Timer] = [:]
    private let userDefaults = UserDefaults.standard
    
    // Preloading - always enabled by default
    let preloadingEnabled = true
    let preloadOnWiFiOnly = true
    
    private let settingsKey = "DataRefreshSettings"
    
    private init() {
        loadSettings()
        setupNotificationObservers()
        registerBackgroundTasks()
    }
    
    // MARK: - Settings Management
    
    private func loadSettings() {
        // Load refresh settings
        if let data = userDefaults.data(forKey: settingsKey),
           let rawSettings = try? JSONDecoder().decode([String: RefreshFrequency].self, from: data) {
            // Map string keys back to DataType
            var mapped: [DataType: RefreshFrequency] = [:]
            for (key, value) in rawSettings {
                if let type = DataType(rawValue: key) {
                    mapped[type] = value
                }
            }
            if !mapped.isEmpty {
                refreshSettings = mapped
            } else {
                // Fallback to defaults if mapping failed
                refreshSettings = [
                    .stockPrices: .fiveMinutes,
                    .aiInsights: .thirtyMinutes,
                    .portfolioData: .fifteenMinutes,
                    .marketNews: .manual
                ]
            }
        } else {
            // Default settings
            refreshSettings = [
                .stockPrices: .fiveMinutes,
                .aiInsights: .thirtyMinutes,
                .portfolioData: .fifteenMinutes,
                .marketNews: .manual
            ]
        }
        
        // Initialize refresh states
        for dataType in DataType.allCases {
            isRefreshing[dataType] = false
            refreshErrors[dataType] = nil
        }
        
        setupAutoRefresh()
    }
    
    func saveSettings() {
        let rawSettings = Dictionary(uniqueKeysWithValues: refreshSettings.map { ($0.key.rawValue, $0.value) })
        if let data = try? JSONEncoder().encode(rawSettings) {
            userDefaults.set(data, forKey: settingsKey)
        }
        
        setupAutoRefresh()
    }
    
    func setRefreshFrequency(_ frequency: RefreshFrequency, for dataType: DataType) {
        refreshSettings[dataType] = frequency
        saveSettings()
    }
    
    // MARK: - Auto Refresh Setup
    
    private func setupAutoRefresh() {
        // Cancel existing timers
        refreshTimers.values.forEach { $0.invalidate() }
        refreshTimers.removeAll()
        
        // Setup new timers
        for (dataType, frequency) in refreshSettings {
            guard let interval = frequency.timeInterval else { continue }
            
            let timer = Timer(timeInterval: TimeInterval(interval), repeats: true) { [weak self] _ in
                guard let self else { return }
                Task { await self.refreshData(for: dataType, force: false) }
            }
            RunLoop.main.add(timer, forMode: .common)
            
            refreshTimers[dataType] = timer
        }
    }
    
    // MARK: - Data Refresh
    
    func refreshData(for dataType: DataType, force: Bool = false) async {
        guard !isRefreshing[dataType, default: false] else { return }
        
        isRefreshing[dataType] = true
        refreshErrors[dataType] = nil
        
        do {
            switch dataType {
            case .stockPrices:
                try await refreshStockPrices(force: force)
            case .aiInsights:
                try await refreshAIInsights(force: force)
            case .portfolioData:
                try await refreshPortfolioData(force: force)
            case .marketNews:
                try await refreshMarketNews(force: force)
            }
            
            lastRefreshTimes[dataType] = Date()
            
        } catch {
            refreshErrors[dataType] = error
            print("Refresh error for \(dataType): \(error)")
        }
        
        isRefreshing[dataType] = false
    }
    
    func refreshAllData(force: Bool = false) async {
        await withTaskGroup(of: Void.self) { group in
            for dataType in DataType.allCases {
                group.addTask {
                    await self.refreshData(for: dataType, force: force)
                }
            }
        }
    }
    
    // MARK: - Specific Data Refresh Methods
    
    private func refreshStockPrices(force: Bool) async throws {
        let cacheKey = "stock_prices_all"
        let frequency = refreshSettings[.stockPrices, default: .fiveMinutes]
        
        if !force, let cachedPrices: [String: StockData] = await cache.get(cacheKey, type: [String: StockData].self) {
            // Use cached data if not forcing refresh
            lastDataSource = .cache
            NotificationCenter.default.post(name: .stockPricesUpdated, object: cachedPrices)
            return
        }
        
        // Fetch fresh data using enhanced service
        let portfolioStore = PortfolioStore.shared
        let stockService = DefaultStockPriceService()
        var updatedPrices: [String: StockData] = [:]
        var dataSourceUsed: StockQuote.DataSource = .yahooFinance
        
        for item in portfolioStore.items {
            do {
                let quote = try await stockService.fetchStockPrice(symbol: item.symbol, timeout: 10.0)
                let current: Double = quote.currentPrice
                let prev: Double = quote.previousClose ?? 0.0
                let change: Double = current - prev
                let changePct: Double = prev != 0.0 ? ((change / prev) * 100.0) : 0.0
                
                let mapped = StockData(
                    symbol: item.symbol,
                    currentPrice: current,
                    previousClose: prev,
                    change: change,
                    changePercent: changePct,
                    timestamp: quote.timestamp
                )
                updatedPrices[item.symbol] = mapped
                
                // Track the highest priority data source used
                if quote.dataSource.priority < dataSourceUsed.priority {
                    dataSourceUsed = quote.dataSource
                }
            } catch {
                print("Failed to fetch stock price for \(item.symbol): \(error.localizedDescription)")
                // Continue with other stocks even if one fails
            }
        }
        
        // Update the tracked data source
        lastDataSource = dataSourceUsed
        
        // Cache the results
        await cache.set(cacheKey, value: updatedPrices, expiry: frequency.cacheExpiry)
        
        // Notify observers
        NotificationCenter.default.post(name: .stockPricesUpdated, object: updatedPrices)
    }
    
    private func refreshAIInsights(force: Bool) async throws {
        let cacheKey = "ai_insights_all"
        let frequency = refreshSettings[.aiInsights, default: .thirtyMinutes]
        
        if !force, let cachedInsights: [String: AIInsight] = await cache.get(cacheKey, type: [String: AIInsight].self) {
            NotificationCenter.default.post(name: .aiInsightsUpdated, object: cachedInsights)
            return
        }
        
        // Fetch fresh AI insights
        let aiProvider = AINewsProvider()
        let portfolioStore = PortfolioStore.shared
        var insights: [String: AIInsight] = [:]
        
        for item in portfolioStore.items {
            do {
                let prediction = try await aiProvider.prediction(for: item.symbol)
                
                // Handle optional prediction by unwrapping it
                if let prediction = prediction {
                    let mapped = AIInsight(
                        symbol: item.symbol,
                        profitLikelihood: prediction.profitLikelihood,
                        forecastedGain: prediction.forecastedGain,
                        confidence: prediction.confidence,
                        upside: prediction.upside,
                        factors: prediction.factors,
                        timestamp: Date()
                    )
                    insights[item.symbol] = mapped
                } else {
                    print("No prediction data available for \(item.symbol)")
                }
            } catch {
                print("Failed to fetch AI insights for \(item.symbol): \(error)")
                // Continue with other stocks even if one fails
            }
        }
        
        await cache.set(cacheKey, value: insights, expiry: frequency.cacheExpiry)
        NotificationCenter.default.post(name: .aiInsightsUpdated, object: insights)
    }
    
    private func refreshPortfolioData(force: Bool) async throws {
        // Portfolio data is typically managed by PortfolioStore
        // This could include portfolio statistics, performance metrics, etc.
        let portfolioStore = PortfolioStore.shared
        await portfolioStore.refreshAllPrices()
    }
    
    private func refreshMarketNews(force: Bool) async throws {
        let cacheKey = "market_news"
        let frequency = refreshSettings[.marketNews, default: .manual]
        
        if !force, let cachedNews: [MarketNews] = await cache.get(cacheKey, type: [MarketNews].self) {
            NotificationCenter.default.post(name: .marketNewsUpdated, object: cachedNews)
            return
        }
        
        // Simulate fetching market news
        let mockNews = generateMockNews()
        await cache.set(cacheKey, value: mockNews, expiry: frequency.cacheExpiry)
        NotificationCenter.default.post(name: .marketNewsUpdated, object: mockNews)
    }
    
    // MARK: - Background Tasks
    
    private func registerBackgroundTasks() {
        #if canImport(BackgroundTasks)
        for dataType in DataType.allCases {
            BGTaskScheduler.shared.register(forTaskWithIdentifier: dataType.backgroundTaskIdentifier, using: nil) { task in
                if let appRefreshTask = task as? BGAppRefreshTask {
                    self.handleBackgroundRefresh(task: appRefreshTask, dataType: dataType)
                } else {
                    task.setTaskCompleted(success: false)
                }
            }
        }
        #else
        // BackgroundTasks not available on this platform
        #endif
    }
    
    private func handleBackgroundRefresh(task: BGAppRefreshTask, dataType: DataType) {
        #if canImport(BackgroundTasks)
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }

        Task {
            await self.refreshData(for: dataType, force: false)
            task.setTaskCompleted(success: true)
            self.scheduleNextBackgroundRefresh(for: dataType)
        }
        #else
        // No-op when BackgroundTasks is unavailable
        #endif
    }
    
    func scheduleBackgroundRefresh() {
        #if canImport(BackgroundTasks)
        for dataType in DataType.allCases {
            scheduleNextBackgroundRefresh(for: dataType)
        }
        #else
        // BackgroundTasks not available
        #endif
    }
    
    private func scheduleNextBackgroundRefresh(for dataType: DataType) {
        #if canImport(BackgroundTasks)
        guard let frequency = refreshSettings[dataType] else { return }
        guard let interval = frequency.timeInterval else { return }

        let request = BGAppRefreshTaskRequest(identifier: dataType.backgroundTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: TimeInterval(interval))

        try? BGTaskScheduler.shared.submit(request)
        #else
        // BackgroundTasks not available
        #endif
    }
    
    // MARK: - Preloading
    
    func preloadData() async {
        guard preloadingEnabled else { return }
        
        if preloadOnWiFiOnly && !isOnWiFi() {
            return
        }
        
        // Preload data that's likely to be accessed soon
        await withTaskGroup(of: Void.self) { group in
            for dataType in DataType.allCases {
                group.addTask {
                    await self.refreshData(for: dataType, force: false)
                }
            }
        }
    }
    
    private func isOnWiFi() -> Bool {
        // Simplified WiFi check - in a real app, you'd use more sophisticated network detection
        return true // For now, assume always on WiFi
    }
    
    // MARK: - Notification Setup
    
    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task {
                await self.refreshAllData(force: false)
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                self.scheduleBackgroundRefresh()
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func generateMockNews() -> [MarketNews] {
        return [
            MarketNews(id: UUID(), title: "Market Update", content: "Latest market trends...", timestamp: Date()),
            MarketNews(id: UUID(), title: "Economic Indicators", content: "Recent economic data...", timestamp: Date())
        ]
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let stockPricesUpdated = Notification.Name("stockPricesUpdated")
    static let aiInsightsUpdated = Notification.Name("aiInsightsUpdated")
    static let marketNewsUpdated = Notification.Name("marketNewsUpdated")
}
