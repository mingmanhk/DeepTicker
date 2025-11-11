// StockPriceService.swift
// Provides a unified stock price service with Alpha Vantage primary and cached data as fallback.

import Foundation
import Combine
import SwiftUI

// MARK: - Enhanced Models
struct StockQuote: Sendable {
    let currentPrice: Double
    let previousClose: Double?
    let dataSource: DataSource
    let timestamp: Date
    let isFromCache: Bool
    
    enum DataSource: String, CaseIterable, Sendable, Codable {
        case alphaVantage = "Alpha Vantage"
        case cache = "Cached Data"
        
        var displayName: String { rawValue }
        var priority: Int {
            switch self {
            case .alphaVantage: return 0
            case .cache: return 1
            }
        }
    }
}

struct SymbolSearchResult: Sendable {
    let symbol: String
    let name: String
    let dataSource: StockQuote.DataSource
}

struct ServiceError: LocalizedError, Sendable {
    let message: String
    let dataSource: StockQuote.DataSource?
    let underlyingError: Error?
    
    var errorDescription: String? { message }
}

// MARK: - Enhanced Protocol
protocol StockPriceProviding: Sendable {
    func fetchStockPrice(symbol: String, timeout: TimeInterval) async throws -> StockQuote
    func searchSymbol(_ query: String, timeout: TimeInterval) async throws -> [SymbolSearchResult]
}

// MARK: - Alpha Vantage Adapter with Enhanced Error Handling
final class AlphaVantageAdapter: StockPriceProviding {
    func fetchStockPrice(symbol: String, timeout: TimeInterval = 10.0) async throws -> StockQuote {
        print("🟢 Alpha Vantage: Fetching price for \(symbol)...")
        let service = AlphaVantageService()
        do {
            let stock = try await withTimeout(timeout) {
                try await service.fetchStockPrice(symbol: symbol)
            }
            
            print("✅ Alpha Vantage: Success! Price: $\(String(format: "%.2f", stock.currentPrice))")
            
            return StockQuote(
                currentPrice: stock.currentPrice,
                previousClose: stock.previousClose,
                dataSource: .alphaVantage,
                timestamp: Date(),
                isFromCache: false
            )
        } catch is CancellationError {
            print("🔴 Alpha Vantage: Request timed out")
            throw ServiceError(
                message: "Alpha Vantage request timed out",
                dataSource: .alphaVantage,
                underlyingError: nil
            )
        } catch {
            print("🔴 Alpha Vantage: Failed - \(error.localizedDescription)")
            throw ServiceError(
                message: "Alpha Vantage service failed: \(error.localizedDescription)",
                dataSource: .alphaVantage,
                underlyingError: error
            )
        }
    }

    func searchSymbol(_ query: String, timeout: TimeInterval = 10.0) async throws -> [SymbolSearchResult] {
        let service = AlphaVantageService()
        do {
            let results = try await withTimeout(timeout) {
                try await service.searchSymbol(query)
            }
            return results.map { 
                SymbolSearchResult(
                    symbol: $0.symbol, 
                    name: $0.name,
                    dataSource: .alphaVantage
                ) 
            }
        } catch is CancellationError {
            throw ServiceError(
                message: "Alpha Vantage search timed out",
                dataSource: .alphaVantage,
                underlyingError: nil
            )
        } catch {
            throw ServiceError(
                message: "Alpha Vantage search failed: \(error.localizedDescription)",
                dataSource: .alphaVantage,
                underlyingError: error
            )
        }
    }
}

// MARK: - Enhanced Default Service with Alpha Vantage Only
@MainActor
final class DefaultStockPriceService: ObservableObject, StockPriceProviding {
    private let primary: StockPriceProviding
    private let marketSignalProvider: MarketSignalProviding
    private let cache: SmartCacheManager
    private let maxRetries: Int
    private let baseTimeout: TimeInterval
    
    // Service status tracking
    @Published private(set) var lastDataSource: StockQuote.DataSource?
    @Published private(set) var lastRefreshTime: Date?
    @Published private(set) var lastError: ServiceError?
    @Published private(set) var marketSignal: AIMarketSignal?

    init(
        primary: StockPriceProviding? = nil,
        marketSignalProvider: MarketSignalProviding? = nil,
        maxRetries: Int = 3,
        baseTimeout: TimeInterval = 10.0
    ) {
        self.primary = primary ?? AlphaVantageAdapter()
        self.marketSignalProvider = marketSignalProvider ?? MockMarketSignalService()
        self.cache = SmartCacheManager.shared
        self.maxRetries = maxRetries
        self.baseTimeout = baseTimeout
        
        print("✅ Stock Price Service initialized with Alpha Vantage")
    }

    func fetchStockPrice(symbol: String, timeout: TimeInterval = 10.0) async throws -> StockQuote {
        let cacheKey = "stock_quote_\(symbol.uppercased())"
        
        print("📊 Fetching stock price for: \(symbol)")
        
        // Attempt Alpha Vantage
        do {
            let quote = try await retryWithExponentialBackoff(maxRetries: maxRetries) {
                try await self.primary.fetchStockPrice(symbol: symbol, timeout: timeout)
            }
            
            await cacheQuote(quote, key: cacheKey)
            updateStatus(dataSource: .alphaVantage, error: nil)
            return quote
            
        } catch {
            print("🔴 Alpha Vantage failed for \(symbol): \(error.localizedDescription)")
        }
        
        // Final fallback: Use cached data if available
        if let cachedQuote: CachedStockQuote = await cache.get(cacheKey, type: CachedStockQuote.self) {
            print("📦 Using cached data for \(symbol)")
            
            let quote = StockQuote(
                currentPrice: cachedQuote.currentPrice,
                previousClose: cachedQuote.previousClose,
                dataSource: .cache,
                timestamp: cachedQuote.timestamp,
                isFromCache: true
            )
            
            updateStatus(dataSource: .cache, error: nil)
            return quote
        }
        
        let error = ServiceError(
            message: "Alpha Vantage failed and no cached data available for \(symbol)",
            dataSource: nil,
            underlyingError: nil
        )
        
        updateStatus(dataSource: nil, error: error)
        throw error
    }

    func searchSymbol(_ query: String, timeout: TimeInterval = 10.0) async throws -> [SymbolSearchResult] {
        print("🔍 Searching for: '\(query)'")
        
        do {
            let results = try await primary.searchSymbol(query, timeout: timeout)
            updateStatus(dataSource: .alphaVantage, error: nil)
            return results
        } catch {
            let serviceError = ServiceError(
                message: "Symbol search failed for query: \(query)",
                dataSource: nil,
                underlyingError: error
            )
            
            updateStatus(dataSource: nil, error: serviceError)
            throw serviceError
        }
    }
    
    func fetchMarketSignal(for symbol: String) async {
        do {
            let signal = try await marketSignalProvider.fetchMarketSignal(for: symbol)
            self.marketSignal = signal
            self.lastError = nil
        } catch {
            let serviceError = ServiceError(
                message: "Failed to fetch AI Market Signal for \(symbol).",
                dataSource: nil,
                underlyingError: error
            )
            self.lastError = serviceError
            self.marketSignal = nil
        }
    }
    
    // MARK: - Private Helper Methods
    
    private func retryWithExponentialBackoff<T>(
        maxRetries: Int,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        var lastError: Error?
        
        for attempt in 0..<maxRetries {
            do {
                return try await operation()
            } catch {
                lastError = error
                
                // Don't retry certain errors
                if let serviceError = error as? ServiceError,
                   serviceError.message.contains("not found") ||
                   serviceError.message.contains("invalid") {
                    throw error
                }
                
                // Don't retry on the last attempt
                if attempt == maxRetries - 1 {
                    break
                }
                
                // Exponential backoff: 0.5s, 1s, 2s, etc.
                let delay = 0.5 * pow(2.0, Double(attempt))
                try await Task.sleep(for: .milliseconds(Int(delay * 1000)))
            }
        }
        
        throw lastError ?? ServiceError(
            message: "Max retry attempts exceeded",
            dataSource: nil,
            underlyingError: nil
        )
    }
    
    private func updateStatus(dataSource: StockQuote.DataSource?, error: ServiceError?) {
        lastDataSource = dataSource
        lastRefreshTime = Date()
        lastError = error
    }
    
    private func cacheQuote(_ quote: StockQuote, key: String) async {
        let cachedQuote = CachedStockQuote(
            currentPrice: quote.currentPrice,
            previousClose: quote.previousClose,
            dataSource: quote.dataSource,
            timestamp: quote.timestamp
        )
        
        // Cache for 10 minutes for Alpha Vantage data
        let cacheExpiry: TimeInterval = 600
        await cache.set(key, value: cachedQuote, expiry: cacheExpiry)
    }
}

// MARK: - Cached Stock Quote Model

struct CachedStockQuote: Sendable, Codable {
    let currentPrice: Double
    let previousClose: Double?
    let dataSource: StockQuote.DataSource
    let timestamp: Date
    
    // We must provide a memberwise initializer because defining a custom
    // `init(from:)` below removes the compiler-synthesized one.
    init(currentPrice: Double, previousClose: Double?, dataSource: StockQuote.DataSource, timestamp: Date) {
        self.currentPrice = currentPrice
        self.previousClose = previousClose
        self.dataSource = dataSource
        self.timestamp = timestamp
    }
    
    // Explicitly implementing Codable to avoid synthesized conformance issues
    // that may be incorrectly inferring actor isolation.
    enum CodingKeys: String, CodingKey {
        case currentPrice
        case previousClose
        case dataSource
        case timestamp
    }
    
    // These methods are marked `nonisolated` so they can be called from any
    // actor context, as required by the background caching system.
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        currentPrice = try container.decode(Double.self, forKey: .currentPrice)
        previousClose = try container.decodeIfPresent(Double.self, forKey: .previousClose)
        dataSource = try container.decode(StockQuote.DataSource.self, forKey: .dataSource)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
    }
    
    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(currentPrice, forKey: .currentPrice)
        try container.encodeIfPresent(previousClose, forKey: .previousClose)
        try container.encode(dataSource, forKey: .dataSource)
        try container.encode(timestamp, forKey: .timestamp)
    }
}

// MARK: - Timeout Helper

func withTimeout<T>(_ timeout: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await operation()
        }
        
        group.addTask {
            try await Task.sleep(for: .seconds(timeout))
            throw CancellationError()
        }
        
        let result = try await group.next()!
        group.cancelAll()
        return result
    }
}
