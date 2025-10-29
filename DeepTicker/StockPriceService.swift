// StockPriceService.swift
// Provides a unified stock price service with Yahoo Finance primary, Alpha Vantage fallback, and cached data as final fallback.

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
        case yahooFinance = "Yahoo Finance"
        case alphaVantage = "Alpha Vantage"
        case cache = "Cached Data"
        
        var displayName: String { rawValue }
        var priority: Int {
            switch self {
            case .yahooFinance: return 0
            case .alphaVantage: return 1
            case .cache: return 2
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

// MARK: - Yahoo Finance Service with Enhanced Error Handling
final class YahooFinanceService: StockPriceProviding {
    private let session: URLSession
    
    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10.0
        config.timeoutIntervalForResource = 20.0
        self.session = URLSession(configuration: config)
    }
    
    enum YahooError: LocalizedError, Sendable {
        case invalidURL
        case networkTimeout
        case noData
        case notFound
        case decoding(String)
        case serverError(Int)
        case rateLimited
        
        var errorDescription: String? {
            switch self {
            case .invalidURL: return "Invalid Yahoo Finance URL"
            case .networkTimeout: return "Yahoo Finance request timed out"
            case .noData: return "No data from Yahoo Finance"
            case .notFound: return "Symbol not found on Yahoo Finance"
            case .decoding(let details): return "Failed to decode Yahoo Finance response: \(details)"
            case .serverError(let code): return "Yahoo Finance server error: \(code)"
            case .rateLimited: return "Yahoo Finance rate limit exceeded"
            }
        }
    }

    func fetchStockPrice(symbol: String, timeout: TimeInterval = 8.0) async throws -> StockQuote {
        let sym = symbol.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? symbol
        guard let url = URL(string: "https://query1.finance.yahoo.com/v7/finance/quote?symbols=\(sym)") else {
            throw YahooError.invalidURL
        }
        
        do {
            let (data, response) = try await withTimeout(timeout) {
                try await self.session.data(from: url)
            }
            
            guard let http = response as? HTTPURLResponse else {
                throw YahooError.noData
            }
            
            switch http.statusCode {
            case 200..<300:
                break
            case 429:
                throw YahooError.rateLimited
            case 404:
                throw YahooError.notFound
            case 500...599:
                throw YahooError.serverError(http.statusCode)
            default:
                throw YahooError.noData
            }
            
            let decoded = try JSONDecoder().decode(YahooQuoteResponse.self, from: data)
            guard let result = decoded.quoteResponse.result.first else {
                throw YahooError.notFound
            }
            
            let price = result.regularMarketPrice ?? result.postMarketPrice ?? result.preMarketPrice
            guard let current = price, current > 0 else { 
                throw YahooError.notFound 
            }
            
            let prev = result.regularMarketPreviousClose
            
            return StockQuote(
                currentPrice: current,
                previousClose: prev,
                dataSource: .yahooFinance,
                timestamp: Date(),
                isFromCache: false
            )
            
        } catch is CancellationError {
            throw YahooError.networkTimeout
        } catch let error as DecodingError {
            throw YahooError.decoding(error.localizedDescription)
        } catch let yahooError as YahooError {
            throw yahooError
        } catch {
            throw YahooError.noData
        }
    }

    func searchSymbol(_ query: String, timeout: TimeInterval = 8.0) async throws -> [SymbolSearchResult] {
        do {
            let quote = try await fetchStockPrice(symbol: query, timeout: timeout)
            return [SymbolSearchResult(
                symbol: query.uppercased(), 
                name: query.uppercased(),
                dataSource: .yahooFinance
            )]
        } catch {
            return []
        }
    }
}

// MARK: - Alpha Vantage Adapter with Enhanced Error Handling
final class AlphaVantageAdapter: StockPriceProviding {
    func fetchStockPrice(symbol: String, timeout: TimeInterval = 10.0) async throws -> StockQuote {
        let service = AlphaVantageService()
        do {
            let stock = try await withTimeout(timeout) {
                try await service.fetchStockPrice(symbol: symbol)
            }
            
            return StockQuote(
                currentPrice: stock.currentPrice,
                previousClose: stock.previousClose,
                dataSource: .alphaVantage,
                timestamp: Date(),
                isFromCache: false
            )
        } catch is CancellationError {
            throw ServiceError(
                message: "Alpha Vantage request timed out",
                dataSource: .alphaVantage,
                underlyingError: nil
            )
        } catch {
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

// MARK: - Enhanced Default Service with Comprehensive Fallback Logic
@MainActor
final class DefaultStockPriceService: ObservableObject, StockPriceProviding {
    private let primary: StockPriceProviding
    private let fallback: StockPriceProviding
    private let marketSignalProvider: MarketSignalProviding
    private let cache: SmartCacheManager
    private let maxRetries: Int
    private let baseTimeout: TimeInterval
    
    // Service status tracking
    @Published private(set) var lastDataSource: StockQuote.DataSource?
    @Published private(set) var lastRefreshTime: Date?
    @Published private(set) var isAlphaVantageAvailable: Bool = true
    @Published private(set) var lastError: ServiceError?
    @Published private(set) var marketSignal: AIMarketSignal?

    init(
        primary: StockPriceProviding? = nil,
        fallback: StockPriceProviding? = nil,
        marketSignalProvider: MarketSignalProviding = MockMarketSignalService(),
        maxRetries: Int = 3,
        baseTimeout: TimeInterval = 8.0
    ) {
        self.primary = primary ?? YahooFinanceService()
        self.fallback = fallback ?? AlphaVantageAdapter()
        self.marketSignalProvider = marketSignalProvider
        self.cache = SmartCacheManager.shared
        self.maxRetries = maxRetries
        self.baseTimeout = baseTimeout
    }

    func fetchStockPrice(symbol: String, timeout: TimeInterval = 8.0) async throws -> StockQuote {
        let cacheKey = "stock_quote_\(symbol.uppercased())"
        
        // Attempt primary source (Yahoo Finance)
        do {
            let quote = try await retryWithExponentialBackoff(maxRetries: maxRetries) {
                try await self.primary.fetchStockPrice(symbol: symbol, timeout: timeout)
            }
            
            await cacheQuote(quote, key: cacheKey)
            updateStatus(dataSource: .yahooFinance, error: nil)
            return quote
            
        } catch {
            print("Yahoo Finance failed for \(symbol): \(error.localizedDescription)")
        }
        
        // Attempt fallback source (Alpha Vantage) if available
        if isAlphaVantageAvailable {
            do {
                let quote = try await retryWithExponentialBackoff(maxRetries: maxRetries) {
                    try await self.fallback.fetchStockPrice(symbol: symbol, timeout: timeout * 1.5)
                }
                
                await cacheQuote(quote, key: cacheKey)
                updateStatus(dataSource: .alphaVantage, error: nil)
                return quote
                
            } catch {
                print("Alpha Vantage failed for \(symbol): \(error.localizedDescription)")
                
                // Check if Alpha Vantage API key issue - disable temporarily if so
                if error.localizedDescription.contains("API key") || error.localizedDescription.contains("429") {
                    disableAlphaVantageTemporarily()
                }
            }
        }
        
        // Final fallback: Use cached data if available
        if let cachedQuote: CachedStockQuote = await cache.get(cacheKey, type: CachedStockQuote.self) {
            print("Using cached data for \(symbol)")
            
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
            message: "All data sources failed and no cached data available for \(symbol)",
            dataSource: nil,
            underlyingError: nil
        )
        
        updateStatus(dataSource: nil, error: error)
        throw error
    }

    func searchSymbol(_ query: String, timeout: TimeInterval = 8.0) async throws -> [SymbolSearchResult] {
        // Try primary service first
        if let results = try? await primary.searchSymbol(query, timeout: timeout), !results.isEmpty {
            updateStatus(dataSource: .yahooFinance, error: nil)
            return results
        }
        
        // Fallback to Alpha Vantage if available
        if isAlphaVantageAvailable {
            do {
                let results = try await fallback.searchSymbol(query, timeout: timeout * 1.5)
                updateStatus(dataSource: .alphaVantage, error: nil)
                return results
            } catch {
                if error.localizedDescription.contains("API key") || error.localizedDescription.contains("429") {
                    disableAlphaVantageTemporarily()
                }
            }
        }
        
        let error = ServiceError(
            message: "Symbol search failed for query: \(query)",
            dataSource: nil,
            underlyingError: nil
        )
        
        updateStatus(dataSource: nil, error: error)
        throw error
    }
    
    func fetchMarketSignal(for symbol: String) async {
        do {
            let signal = try await marketSignalProvider.fetchMarketSignal(for: symbol)
            self.marketSignal = signal
            // Reset error on success. A more advanced implementation might use a separate
            // error state for the market signal vs. price fetching.
            self.lastError = nil
        } catch {
            let serviceError = ServiceError(
                message: "Failed to fetch AI Market Signal for \(symbol).",
                dataSource: nil,
                underlyingError: error
            )
            self.lastError = serviceError
            self.marketSignal = nil // Clear any stale signal data on failure
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
    
    private func disableAlphaVantageTemporarily() {
        isAlphaVantageAvailable = false
        
        // Re-enable Alpha Vantage after 10 minutes
        Task {
            try await Task.sleep(for: .seconds(600))
            await MainActor.run {
                self.isAlphaVantageAvailable = true
            }
        }
    }
    
    private func cacheQuote(_ quote: StockQuote, key: String) async {
        let cachedQuote = CachedStockQuote(
            currentPrice: quote.currentPrice,
            previousClose: quote.previousClose,
            dataSource: quote.dataSource,
            timestamp: quote.timestamp
        )
        
        // Cache for 5 minutes for real-time data, longer for fallback data
        let cacheExpiry: TimeInterval = quote.dataSource == .yahooFinance ? 300 : 600
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

// MARK: - Yahoo response models
private struct YahooQuoteResponse: Decodable {
    let quoteResponse: YahooQuoteResponseContainer
}

private struct YahooQuoteResponseContainer: Decodable {
    let result: [YahooQuoteData]
}

private struct YahooQuoteData: Decodable {
    let symbol: String?
    let shortName: String?
    let longName: String?
    let regularMarketPrice: Double?
    let regularMarketPreviousClose: Double?
    let postMarketPrice: Double?
    let preMarketPrice: Double?
}
