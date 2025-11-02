import Foundation
import SwiftUI
import Combine

/// Unified Portfolio Management System
/// Combines the original PortfolioStore functionality with the new DataManager compatibility
@MainActor
final class UnifiedPortfolioManager: ObservableObject {
    static let shared = UnifiedPortfolioManager()
    
    // MARK: - Published Properties
    @Published var items: [StockItem] = [] {
        didSet { persist() }
    }
    @Published var lastRefresh: Date? = nil
    @Published var isRefreshing: Bool = false
    
    // MARK: - Legacy Stock Compatibility
    /// Legacy Stock items for compatibility with new AI system
    var legacyStocks: [PortfolioStock] {
        items.map { item in
            PortfolioStock(
                symbol: item.symbol,
                currentPrice: item.currentPrice ?? 0,
                previousClose: item.previousClose ?? item.currentPrice ?? 0,
                quantity: item.quantity
            )
        }
    }
    
    // MARK: - Services & Dependencies
    private let defaultsKey = "PortfolioStore.items"
    private let refreshKey = "PortfolioStore.lastRefresh"
    private let cache = SmartCacheManager.shared
    private let dataRefreshManager = DataRefreshManager.shared
    private let priceEndpoint = "https://mcp.alphavantage.co/mcp?apikey=E1ROYME4HFCB3C94&symbol="

    private init() {
        restore()
        setupNotificationObservers()
    }

    // MARK: - Computed Properties
    var totalCurrentValue: Double {
        items.reduce(0) { $0 + $1.totalValue }
    }

    var initialValue: Double {
        items.reduce(0) { partial, item in
            guard let pp = item.purchasePrice else { return partial }
            return partial + (pp * item.quantity)
        }
    }

    var earningsPercent: Double? {
        let initial = initialValue
        guard initial > 0 else { return nil }
        let current = totalCurrentValue
        return (current - initial) / initial * 100.0
    }
    
    var totalDailyChange: Double {
        items.reduce(0) { total, item in
            guard let current = item.currentPrice,
                  let previous = item.previousClose,
                  previous > 0 else { return total }
            return total + ((current - previous) * item.quantity)
        }
    }
    
    var totalDailyChangePercentage: Double {
        let previousTotal = items.reduce(0) { total, item in
            guard let previous = item.previousClose else { return total }
            return total + (previous * item.quantity)
        }
        guard previousTotal > 0 else { return 0 }
        return (totalDailyChange / previousTotal) * 100
    }

    // MARK: - CRUD Operations
    func add(symbol: String, name: String?, quantity: Double, purchasePrice: Double?, currentPrice: Double? = nil, previousClose: Double? = nil) {
        print("🔵 UnifiedPortfolioManager.add called:")
        print("   - Symbol: \(symbol)")
        print("   - Name: \(name ?? "nil")")
        print("   - Quantity: \(quantity)")
        print("   - Purchase Price: \(purchasePrice ?? 0.0)")
        print("   - Current Price: \(currentPrice ?? 0.0)")
        print("   - Previous Close: \(previousClose ?? 0.0)")
        
        let item = StockItem(
            symbol: symbol,
            name: name,
            quantity: quantity,
            purchasePrice: purchasePrice,
            currentPrice: currentPrice,
            previousClose: previousClose,
            lastUpdated: (currentPrice != nil) ? Date() : nil
        )
        
        items.append(item)
        print("✅ Stock added to portfolio. Total items: \(items.count)")
        print("   - Current portfolio symbols: \(items.map { $0.symbol })")
        
        notifyPortfolioChanged()
    }

    func remove(_ item: StockItem) {
        items.removeAll { $0.id == item.id }
        notifyPortfolioChanged()
    }
    
    func remove(at index: Int) {
        guard index < items.count else { return }
        items.remove(at: index)
        notifyPortfolioChanged()
    }

    func update(_ item: StockItem, quantity: Double, purchasePrice: Double?) {
        guard let idx = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[idx].quantity = quantity
        items[idx].purchasePrice = purchasePrice
        notifyPortfolioChanged()
    }
    
    func update(at index: Int, quantity: Double) {
        guard index < items.count else { return }
        items[index].quantity = quantity
        notifyPortfolioChanged()
    }
    
    // MARK: - New Stock Addition (DataManager compatibility)
    func addStock(_ stock: PortfolioStock) {
        let item = StockItem(
            symbol: stock.symbol,
            name: nil,
            quantity: stock.quantity,
            purchasePrice: stock.previousClose > 0 ? stock.previousClose : nil,
            currentPrice: stock.currentPrice > 0 ? stock.currentPrice : nil,
            previousClose: stock.previousClose > 0 ? stock.previousClose : nil,
            lastUpdated: Date()
        )
        items.append(item)
        notifyPortfolioChanged()
    }
    
    // MARK: - Portfolio Change Notification
    private func notifyPortfolioChanged() {
        // Post notification that portfolio has changed
        NotificationCenter.default.post(
            name: .portfolioDidChange,
            object: self,
            userInfo: ["items": items]
        )
    }

    // MARK: - Price Refresh System
    func refreshAllPrices() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        
        await withTaskGroup(of: (UUID, Double?, Double?).self) { group in
            for item in items {
                group.addTask {
                    let (current, previous) = await self.fetchPriceWithCache(for: item.symbol)
                    return (item.id, current, previous)
                }
            }

            var updated: [StockItem] = items
            for await result in group {
                if let idx = updated.firstIndex(where: { $0.id == result.0 }) {
                    updated[idx].currentPrice = result.1
                    updated[idx].previousClose = result.2
                    updated[idx].lastUpdated = Date()
                }
            }
            self.items = updated
            self.lastRefresh = Date()
            self.persistRefresh()
        }
        
        isRefreshing = false
    }
    
    func refreshPrice(for symbol: String) async -> (current: Double?, previousClose: Double?) {
        return await fetchPriceWithCache(for: symbol, forceRefresh: true)
    }
    
    private func fetchPriceWithCache(for symbol: String, forceRefresh: Bool = false) async -> (current: Double?, previousClose: Double?) {
        let cacheKey = "stock_price_\(symbol.uppercased())"
        let cacheExpiry: TimeInterval = 5 * 60 // 5 minutes for stock prices
        
        // Check cache first (unless forcing refresh)
        if !forceRefresh, let cachedData: CachedStockPrice = await cache.get(cacheKey, type: CachedStockPrice.self) {
            return (cachedData.currentPrice, cachedData.previousClose)
        }
        
        // Use enhanced service with fallback logic
        do {
            let service = DefaultStockPriceService()
            let quote = try await service.fetchStockPrice(symbol: symbol, timeout: 10.0)
            
            // Cache the result
            let cachedPrice = CachedStockPrice(
                symbol: symbol,
                currentPrice: quote.currentPrice,
                previousClose: quote.previousClose,
                timestamp: quote.timestamp
            )
            await cache.set(cacheKey, value: cachedPrice, expiry: cacheExpiry)
            
            return (quote.currentPrice, quote.previousClose)
            
        } catch {
            print("Failed to fetch price for \(symbol) using enhanced service: \(error.localizedDescription)")
            
            // Final fallback: try legacy Alpha Vantage method
            let (current, previous) = await fetchPrice(for: symbol)
            
            // Cache successful legacy results
            if let currentPrice = current {
                let cachedPrice = CachedStockPrice(
                    symbol: symbol,
                    currentPrice: currentPrice,
                    previousClose: previous,
                    timestamp: Date()
                )
                await cache.set(cacheKey, value: cachedPrice, expiry: cacheExpiry)
            }
            
            return (current, previous)
        }
    }
    
    // MARK: - Multi-source Price Fetching
    private func fetchPrice(for symbol: String) async -> (Double?, Double?) {
        let (current, previous) = await fetchPriceFromYahooFinance(for: symbol)
        if let current = current, current > 0, previous != nil {
            return (current, previous)
        }
        // Fallback to Alpha Vantage if Yahoo Finance fails
        return await fetchPriceFromAlphaVantage(for: symbol)
    }

    private func fetchPriceFromYahooFinance(for symbol: String) async -> (current: Double?, previousClose: Double?) {
        guard let url = URL(string: "https://query1.finance.yahoo.com/v8/finance/chart/\(symbol.uppercased())") else {
            return (nil, nil)
        }

        guard let data = await fetchData(url: url) else { return (nil, nil) }

        do {
            let response = try JSONDecoder().decode(YahooFinanceResponse.self, from: data)
            if let meta = response.chart.result?.first?.meta {
                // Yahoo can return 0 for price on failure; treat as nil
                let currentPrice = meta.regularMarketPrice
                return (currentPrice == 0 ? nil : currentPrice, meta.chartPreviousClose)
            }
        } catch {
            // Data parsing failed
        }
        return (nil, nil)
    }

    private func fetchPriceFromAlphaVantage(for symbol: String) async -> (current: Double?, previousClose: Double?) {
        guard let url = buildURLForAlphaVantage(for: symbol), let data = await fetchData(url: url) else {
            return (nil, nil)
        }
        return parseAlphaVantagePrice(from: data)
    }
    
    // MARK: - Notification Setup
    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            forName: .stockPricesUpdated,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let pricesData = notification.object as? [String: Any] else { return }
            
            Task { @MainActor in
                self.handleStockPriceUpdate(pricesData)
            }
        }
    }
    
    private func handleStockPriceUpdate(_ pricesData: [String: Any]) {
        var updated = items
        
        for (index, item) in updated.enumerated() {
            if let stockData = pricesData[item.symbol] as? CachedStockPrice {
                updated[index].currentPrice = stockData.currentPrice
                updated[index].previousClose = stockData.previousClose
                updated[index].lastUpdated = stockData.timestamp
            }
        }
        
        items = updated
        lastRefresh = Date()
        persistRefresh()
    }
    
    // MARK: - Helper Methods
    private func buildURLForAlphaVantage(for symbol: String) -> URL? {
        let sym = symbol.uppercased().addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? symbol.uppercased()
        return URL(string: priceEndpoint + sym)
    }

    private func parseAlphaVantagePrice(from data: Data) -> (current: Double?, previousClose: Double?) {
        struct Response: Decodable {
            let price: Double?
            let previous_close: Double?
        }
        if let decoded = try? JSONDecoder().decode(Response.self, from: data) {
            return (decoded.price, decoded.previous_close)
        }
        struct AVQuote: Decodable {
            enum CodingKeys: String, CodingKey {
                case globalQuote = "Global Quote"
            }
            let globalQuote: Quote?
            struct Quote: Decodable {
                enum CodingKeys: String, CodingKey {
                    case price = "05. price"
                    case previousClose = "08. previous close"
                }
                let price: String?
                let previousClose: String?
            }
        }
        if let decoded = try? JSONDecoder().decode(AVQuote.self, from: data),
           let priceStr = decoded.globalQuote?.price,
           let prevStr = decoded.globalQuote?.previousClose {
            return (Double(priceStr), Double(prevStr))
        }
        return (nil, nil)
    }

    private func fetchData(url: URL) async -> Data? {
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return data
        } catch {
            return nil
        }
    }

    // MARK: - Persistence
    private func persist() {
        do {
            let data = try JSONEncoder().encode(items)
            UserDefaults.standard.set(data, forKey: defaultsKey)
        } catch {
            print("Failed to persist portfolio: \(error)")
        }
    }

    private func persistRefresh() {
        if let ts = lastRefresh {
            UserDefaults.standard.set(ts.timeIntervalSince1970, forKey: refreshKey)
        } else {
            UserDefaults.standard.removeObject(forKey: refreshKey)
        }
    }

    private func restore() {
        if let data = UserDefaults.standard.data(forKey: defaultsKey),
           let decoded = try? JSONDecoder().decode([StockItem].self, from: data) {
            self.items = decoded
        }
        if let ts = UserDefaults.standard.object(forKey: refreshKey) as? TimeInterval {
            self.lastRefresh = Date(timeIntervalSince1970: ts)
        }
    }
    
    // MARK: - Cache Management
    func clearCache() {
        items = []
        lastRefresh = nil
        UserDefaults.standard.removeObject(forKey: defaultsKey)
        UserDefaults.standard.removeObject(forKey: refreshKey)
    }

    // MARK: - Preview Data
    static var preview: UnifiedPortfolioManager {
        let manager = UnifiedPortfolioManager()
        manager.items = [
            StockItem(symbol: "AAPL", name: "Apple Inc.", quantity: 10, purchasePrice: 165.0, currentPrice: 170.5, previousClose: 169.8, lastUpdated: Date()),
            StockItem(symbol: "MSFT", name: "Microsoft Corp.", quantity: 5, purchasePrice: 310.0, currentPrice: 325.2, previousClose: 322.1, lastUpdated: Date())
        ]
        manager.lastRefresh = Date()
        return manager
    }
    
    // MARK: - Debug & Testing
    func addTestStocks() {
        if items.isEmpty {
            add(symbol: "AAPL", name: "Apple Inc.", quantity: 10, purchasePrice: 165.0)
            add(symbol: "MSFT", name: "Microsoft Corp.", quantity: 5, purchasePrice: 310.0)
            add(symbol: "GOOGL", name: "Alphabet Inc.", quantity: 3, purchasePrice: 2800.0)
            print("✅ Added test stocks to portfolio")
        } else {
            print("📊 Portfolio already has \(items.count) stocks: \(items.map { $0.symbol })")
        }
    }
}

// MARK: - Supporting Types

struct StockItem: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var symbol: String
    var name: String?
    var quantity: Double
    var purchasePrice: Double? // user-defined
    var currentPrice: Double?  // fetched
    var previousClose: Double? // for daily change indicator
    var lastUpdated: Date?

    init(id: UUID = UUID(), symbol: String, name: String? = nil, quantity: Double, purchasePrice: Double? = nil, currentPrice: Double? = nil, previousClose: Double? = nil, lastUpdated: Date? = nil) {
        self.id = id
        self.symbol = symbol.uppercased()
        self.name = name
        self.quantity = quantity
        self.purchasePrice = purchasePrice
        self.currentPrice = currentPrice
        self.previousClose = previousClose
        self.lastUpdated = lastUpdated
    }

    var totalValue: Double {
        (currentPrice ?? 0) * quantity
    }

    var dailyChange: Double? {
        guard let cur = currentPrice, let prev = previousClose, prev != 0 else { return nil }
        return (cur - prev) / prev * 100.0
    }
}

struct YahooFinanceResponse: Decodable {
    let chart: Chart
    struct Chart: Decodable {
        let result: [ChartResult]?
    }
    struct ChartResult: Decodable {
        let meta: Meta
    }
    struct Meta: Decodable {
        let regularMarketPrice: Double?
        let chartPreviousClose: Double?
    }
}

struct CachedStockPrice: Sendable, Codable {
    let symbol: String
    let currentPrice: Double
    let previousClose: Double?
    let timestamp: Date
    
    // Standard memberwise initializer
    init(symbol: String, currentPrice: Double, previousClose: Double? = nil, timestamp: Date) {
        self.symbol = symbol
        self.currentPrice = currentPrice
        self.previousClose = previousClose
        self.timestamp = timestamp
    }
    
    nonisolated var isExpired: Bool {
        Date().timeIntervalSince(timestamp) > 300 // 5 minutes
    }
    
    private enum CodingKeys: String, CodingKey {
        case symbol
        case currentPrice
        case previousClose
        case timestampSeconds
    }
    
    // Provide nonisolated Codable implementation to avoid main-actor isolation issues
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.symbol = try container.decode(String.self, forKey: .symbol)
        self.currentPrice = try container.decode(Double.self, forKey: .currentPrice)
        self.previousClose = try container.decodeIfPresent(Double.self, forKey: .previousClose)
        let seconds = try container.decode(Double.self, forKey: .timestampSeconds)
        self.timestamp = Date(timeIntervalSince1970: seconds)
    }
    
    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(symbol, forKey: .symbol)
        try container.encode(currentPrice, forKey: .currentPrice)
        try container.encodeIfPresent(previousClose, forKey: .previousClose)
        try container.encode(timestamp.timeIntervalSince1970, forKey: .timestampSeconds)
    }
}

// MARK: - Legacy Compatibility

/// Legacy Stock model for backward compatibility
struct PortfolioStock: Identifiable, Codable, Sendable {
    var id = UUID()
    let symbol: String
    var currentPrice: Double
    let previousClose: Double
    var quantity: Double
    
    init(symbol: String, currentPrice: Double, previousClose: Double, quantity: Double) {
        self.symbol = symbol
        self.currentPrice = currentPrice
        self.previousClose = previousClose
        self.quantity = quantity
    }
    
    /// Daily change in dollars
    var dailyChange: Double {
        currentPrice - previousClose
    }
    
    /// Daily change percentage
    var dailyChangePercentage: Double {
        guard previousClose > 0 else { return 0 }
        return ((currentPrice - previousClose) / previousClose) * 100
    }
}

/// Unified PortfolioStore - the main portfolio manager that replaces the legacy system
typealias PortfolioStore = UnifiedPortfolioManager

// MARK: - Notification Extensions
extension Notification.Name {
    static let portfolioDidChange = Notification.Name("portfolioDidChange")
    static let stockPricesUpdated = Notification.Name("stockPricesUpdated")
}

