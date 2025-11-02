import Foundation
import SwiftUI
import Combine

/// Central data manager coordinating portfolio, quotes, predictions, and caching
@MainActor
class DataManager: ObservableObject {
    static let shared = DataManager()
    
    // MARK: - Published Properties
    @Published var portfolio: [PortfolioStock] = []
    @Published var quotes: [String: StockQuote] = [:]
    @Published var predictions: [String: AIInsight] = [:]
    @Published var portfolioAnalysis: PortfolioAnalysis?
    
    @Published var isRefreshing = false
    @Published var lastUpdateTime: Date?
    @Published var errorMessage: String?
    
    // MARK: - Services
    private let stockPriceService = StockPriceService()
    private let aiService = MultiProviderAIService()
    private let cacheStore = CacheStore()
    private let notificationService = NotificationService()
    
    // Bridge to legacy portfolio system
    private let portfolioManager = UnifiedPortfolioManager.shared
    
    // MARK: - Cache Keys
    private let portfolioCacheKey = "DataManager.portfolio"
    private let predictionsCacheKey = "DataManager.predictions"
    private let analysisCacheKey = "DataManager.analysis"
    private let lastUpdateCacheKey = "DataManager.lastUpdate"
    
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Error Types
    private enum DataManagerError: Error, LocalizedError {
        case portfolioAnalysisFailed(String)
        
        var errorDescription: String? {
            switch self {
            case .portfolioAnalysisFailed(let message):
                return message
            }
        }
    }
    
    private init() {
        loadFromCache()
        setupPortfolioObserver()
    }
    
    // MARK: - Portfolio Observer
    
    private func setupPortfolioObserver() {
        // Sync with UnifiedPortfolioManager
        portfolioManager.$items.sink { [weak self] items in
            self?.portfolio = items.map { item in
                PortfolioStock(
                    symbol: item.symbol,
                    currentPrice: item.currentPrice ?? 0,
                    previousClose: item.previousClose ?? item.currentPrice ?? 0,
                    quantity: item.quantity
                )
            }
            
            // Clear cached AI data when portfolio becomes empty
            if items.isEmpty {
                self?.predictions = [:]
                self?.portfolioAnalysis = nil
            }
        }
        .store(in: &cancellables)
        
        portfolioManager.$lastRefresh.sink { [weak self] date in
            self?.lastUpdateTime = date
        }
        .store(in: &cancellables)
        
        // Listen for portfolio changes to trigger automatic refresh
        NotificationCenter.default.publisher(for: .portfolioDidChange)
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                Task {
                    await self.refreshForPortfolioChanges()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Interface
    
    /// Auto-refresh all data (called on app launch or manual refresh)
    func refreshAll() async {
        guard !isRefreshing else { return }
        
        isRefreshing = true
        errorMessage = nil
        
        do {
            // Use UnifiedPortfolioManager for price refresh
            await portfolioManager.refreshAllPrices()
            
            // Step 2: Refresh AI predictions
            try await refreshPredictions()
            
            // Step 3: Update portfolio analysis
            try await refreshPortfolioAnalysis()
            
            // Step 4: Cache everything
            saveToCache()
            
            lastUpdateTime = Date()
            
            // Step 5: Check for alert conditions
            await notificationService.checkForAlerts(
                portfolio: portfolio,
                predictions: predictions,
                analysis: portfolioAnalysis
            )
            
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isRefreshing = false
    }
    
    /// Fast refresh focused on new/modified stocks only
    func refreshForPortfolioChanges() async {
        guard !isRefreshing else { return }
        
        isRefreshing = true
        errorMessage = nil
        
        do {
            // Fast price refresh first
            await portfolioManager.refreshAllPrices()
            
            // Only refresh predictions for stocks that don't have recent data
            let symbolsNeedingRefresh = portfolio.compactMap { stock in
                let hasRecentPrediction = predictions[stock.symbol] != nil
                return hasRecentPrediction ? nil : stock.symbol
            }
            
            if !symbolsNeedingRefresh.isEmpty {
                try await refreshPredictions(for: symbolsNeedingRefresh)
            }
            
            // Always update portfolio analysis since composition changed
            try await refreshPortfolioAnalysis()
            
            saveToCache()
            lastUpdateTime = Date()
            
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isRefreshing = false
    }
    
    /// Add a new stock to portfolio and refresh related data
    func addStock(_ stock: PortfolioStock) async {
        portfolioManager.addStock(stock)
        // Automatic refresh will be triggered by the notification system
        // No need to manually call refresh here
    }
    
    /// Remove stock from portfolio and refresh
    func removeStock(at index: Int) {
        portfolioManager.remove(at: index)
        // Automatic refresh will be triggered by the notification system
    }
    
    /// Update stock quantity and refresh
    func updateStock(at index: Int, quantity: Double) {
        portfolioManager.update(at: index, quantity: quantity)
        // Automatic refresh will be triggered by the notification system
    }
    
    /// Force a complete refresh of all data (for manual refresh button)
    func forceRefreshAll() async {
        await refreshAll()
    }
    
    // MARK: - Private Refresh Methods
    
    private func refreshQuotes(for symbols: [String]? = nil) async {
        // Quotes are now handled by UnifiedPortfolioManager
        // This method kept for compatibility
    }
    
    private func refreshPredictions(for symbols: [String]? = nil) async throws {
        let symbolsToRefresh = symbols ?? portfolio.map { $0.symbol }
        var firstError: Error?
        
        await withTaskGroup(of: (String, Result<AIInsight?, Error>).self) { group in
            for symbol in symbolsToRefresh {
                group.addTask { [weak self] in
                    do {
                        // Use the first available AI provider (DeepSeek as default)
                        let enhancedInsight = try await self?.aiService.generateStockPrediction(for: symbol, using: .deepSeek)
                        
                        let insight: AIInsight?
                        if let enhancedInsight = enhancedInsight {
                            insight = await enhancedInsight.toAIInsight()
                        } else {
                            insight = nil
                        }
                        
                        return (symbol, .success(insight))
                    } catch {
                        return (symbol, .failure(error))
                    }
                }
            }
            
            for await (symbol, result) in group {
                switch result {
                case .success(let insight):
                    if let insight = insight {
                        predictions[symbol] = insight
                    }
                case .failure(let error):
                    print("Failed to refresh prediction for \(symbol): \(error)")
                    if firstError == nil {
                        firstError = error
                    }
                }
            }
        }
        
        if let error = firstError {
            throw error
        }
    }
    
    private func refreshPortfolioAnalysis() async throws {
        // Convert portfolio to AIStock format for the AI service
        let aiStocks = portfolio.map { stock in
            AIStock(
                symbol: stock.symbol,
                name: stock.symbol, // We don't have name in PortfolioStock, so use symbol
                price: stock.currentPrice,
                change: stock.currentPrice - stock.previousClose,
                changePercent: ((stock.currentPrice - stock.previousClose) / stock.previousClose) * 100
            )
        }
        
        // Generate insights using the AI service
        let insights = await aiService.generateMultiProviderInsights(for: aiStocks)
        
        // Check for errors from the AI service
        if let errorMessage = aiService.errorMessage {
            throw DataManagerError.portfolioAnalysisFailed(errorMessage)
        }
        
        // Use the first available insight for portfolio analysis
        if let firstInsight = insights.values.first {
            portfolioAnalysis = PortfolioAnalysis(
                confidenceScore: firstInsight.confidenceScore,
                riskLevel: firstInsight.riskLevel
            )
        }
    }
    
    // MARK: - Cache Management
    
    private func loadFromCache() {
        portfolio = cacheStore.load([PortfolioStock].self, forKey: portfolioCacheKey) ?? []
        predictions = cacheStore.load([String: AIInsight].self, forKey: predictionsCacheKey) ?? [:]
        portfolioAnalysis = cacheStore.load(PortfolioAnalysis.self, forKey: analysisCacheKey)
        lastUpdateTime = cacheStore.load(Date.self, forKey: lastUpdateCacheKey)
    }
    
    private func saveToCache() {
        cacheStore.save(portfolio, forKey: portfolioCacheKey)
        cacheStore.save(predictions, forKey: predictionsCacheKey)
        cacheStore.save(portfolioAnalysis, forKey: analysisCacheKey)
        cacheStore.save(lastUpdateTime, forKey: lastUpdateCacheKey)
    }
    
    func clearCache() {
        cacheStore.clearAll()
        portfolioManager.clearCache()
        loadFromCache()
    }
}

// MARK: - Supporting Types

struct AIInsight: Codable, Identifiable {
    let id = UUID()
    let profitLikelihood: Double?
    let forecastedGain: Double?
    let confidence: Double?
    let upside: Double?
    let factors: [String]
    let expectedReturn: Double?
    
    enum CodingKeys: CodingKey {
        case profitLikelihood, forecastedGain, confidence, upside, factors, expectedReturn
    }
}

// Simple cache store implementation
class CacheStore {
    private let userDefaults = UserDefaults.standard
    
    func save<T: Codable>(_ object: T, forKey key: String) {
        do {
            let data = try JSONEncoder().encode(object)
            userDefaults.set(data, forKey: key)
        } catch {
            print("Failed to cache \(key): \(error)")
        }
    }
    
    func load<T: Codable>(_ type: T.Type, forKey key: String) -> T? {
        guard let data = userDefaults.data(forKey: key) else { return nil }
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            print("Failed to load \(key): \(error)")
            return nil
        }
    }
    
    func clearAll() {
        let keys = [
            "DataManager.portfolio",
            "DataManager.predictions",
            "DataManager.analysis",
            "DataManager.lastUpdate"
        ]
        keys.forEach { userDefaults.removeObject(forKey: $0) }
    }
}

// Basic notification service
class NotificationService {
    func checkForAlerts(
        portfolio: [PortfolioStock],
        predictions: [String: AIInsight],
        analysis: PortfolioAnalysis?
    ) async {
        // Implementation would check thresholds and trigger notifications
        // This is a placeholder for your notification logic
        print("Checking for alert conditions...")
    }
}

// MARK: - Type Conversion Extensions

extension EnhancedAIInsight {
    func toAIInsight() -> AIInsight {
        return AIInsight(
            profitLikelihood: marketSignal.todaysProfitLikelihood,
            forecastedGain: marketSignal.forecastedGainPotential,
            confidence: marketSignal.profitConfidenceScore,
            upside: marketSignal.projectedUpsideChance,
            factors: riskFactors,
            expectedReturn: nil
        )
    }
}
