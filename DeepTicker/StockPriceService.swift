// StockPriceService.swift
// Provides a unified stock price service with RapidAPI primary, Alpha Vantage fallback, Twelve Data secondary fallback, and cached data as final fallback.

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
        case rapidAPI = "RapidAPI"
        case alphaVantage = "Alpha Vantage"
        case twelveData = "Twelve Data"
        case cache = "Cached Data"
        
        var displayName: String { rawValue }
        var priority: Int {
            switch self {
            case .rapidAPI: return 0
            case .alphaVantage: return 1
            case .twelveData: return 2
            case .cache: return 3
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

// MARK: - RapidAPI Service with Enhanced Error Handling
final class RapidAPIService: StockPriceProviding {
    private let session: URLSession
    private let rapidAPIKey: String
    private let rapidAPIHost = "apidojo-yahoo-finance-v1.p.rapidapi.com"
    
    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10.0
        config.timeoutIntervalForResource = 20.0
        self.session = URLSession(configuration: config)
        
        self.rapidAPIKey = SecureConfigurationManager.shared.rapidAPIKey.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
    }
    
    enum RapidAPIError: LocalizedError, Sendable {
        case invalidURL
        case networkTimeout
        case noData
        case notFound
        case decoding(String)
        case serverError(Int)
        case rateLimited
        case missingPriceData
        
        var errorDescription: String? {
            switch self {
            case .invalidURL: return "Invalid RapidAPI URL"
            case .networkTimeout: return "RapidAPI request timed out"
            case .noData: return "No data from RapidAPI"
            case .notFound: return "Symbol not found on RapidAPI"
            case .decoding(let details): return "Failed to decode RapidAPI response: \(details)"
            case .serverError(let code): return "RapidAPI server error: \(code)"
            case .rateLimited: return "RapidAPI rate limit exceeded"
            case .missingPriceData: return "Price data missing in RapidAPI response"
            }
        }
    }
    
    func fetchStockPrice(symbol: String, timeout: TimeInterval = 8.0) async throws -> StockQuote {
        let sym = symbol.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? symbol
        guard let url = URL(string: "https://\(rapidAPIHost)/stock/v2/get-summary?symbol=\(sym)") else {
            throw RapidAPIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.addValue(rapidAPIKey, forHTTPHeaderField: "x-rapidapi-key")
        request.addValue(rapidAPIHost, forHTTPHeaderField: "x-rapidapi-host")
        
        do {
            let (data, response) = try await withTimeout(timeout) {
                try await self.session.data(for: request)
            }
            
            guard let http = response as? HTTPURLResponse else {
                throw RapidAPIError.noData
            }
            
            switch http.statusCode {
            case 200..<300:
                break
            case 429:
                throw RapidAPIError.rateLimited
            case 404:
                throw RapidAPIError.notFound
            case 500...599:
                throw RapidAPIError.serverError(http.statusCode)
            default:
                throw RapidAPIError.noData
            }
            
            let decoded = try JSONDecoder().decode(RapidAPIQuoteResponse.self, from: data)
            
            // Extract price safely from price or summaryDetail
            let priceObj = decoded.price ?? decoded.summaryDetail
            guard let current = priceObj?.regularMarketPrice?.raw, current > 0 else {
                throw RapidAPIError.missingPriceData
            }
            let prev = priceObj?.regularMarketPreviousClose?.raw
            
            return StockQuote(
                currentPrice: current,
                previousClose: prev,
                dataSource: .rapidAPI,
                timestamp: Date(),
                isFromCache: false
            )
            
        } catch is CancellationError {
            throw RapidAPIError.networkTimeout
        } catch let error as DecodingError {
            throw RapidAPIError.decoding(error.localizedDescription)
        } catch let rapidError as RapidAPIError {
            throw rapidError
        } catch {
            throw RapidAPIError.noData
        }
    }
    
    func searchSymbol(_ query: String, timeout: TimeInterval = 8.0) async throws -> [SymbolSearchResult] {
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        guard let url = URL(string: "https://\(rapidAPIHost)/auto-complete?q=\(encodedQuery)") else {
            throw RapidAPIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.addValue(rapidAPIKey, forHTTPHeaderField: "x-rapidapi-key")
        request.addValue(rapidAPIHost, forHTTPHeaderField: "x-rapidapi-host")
        
        do {
            let (data, response) = try await withTimeout(timeout) {
                try await self.session.data(for: request)
            }
            
            guard let http = response as? HTTPURLResponse else {
                throw RapidAPIError.noData
            }
            
            switch http.statusCode {
            case 200..<300:
                break
            case 429:
                throw RapidAPIError.rateLimited
            case 404:
                throw RapidAPIError.notFound
            case 500...599:
                throw RapidAPIError.serverError(http.statusCode)
            default:
                throw RapidAPIError.noData
            }
            
            let searchResponse = try JSONDecoder().decode(RapidAPISearchResponse.self, from: data)
            
            let results = searchResponse.quotes?.compactMap { quote -> SymbolSearchResult? in
                guard !quote.symbol.isEmpty, !quote.shortname.isEmpty else { return nil }
                return SymbolSearchResult(
                    symbol: quote.symbol,
                    name: quote.shortname,
                    dataSource: .rapidAPI
                )
            } ?? []
            
            return Array(results.prefix(10))
            
        } catch is CancellationError {
            throw RapidAPIError.networkTimeout
        } catch let error as DecodingError {
            // Fallback to simple validation if search endpoint fails
            print("RapidAPI search endpoint failed, falling back to validation: \(error)")
            return await fallbackToValidation(query: query, timeout: timeout)
        } catch let rapidError as RapidAPIError {
            throw rapidError
        } catch {
            return await fallbackToValidation(query: query, timeout: timeout)
        }
    }
    
    private func fallbackToValidation(query: String, timeout: TimeInterval) async -> [SymbolSearchResult] {
        // Only try validation for short, symbol-like queries
        guard query.count <= 6 && query.range(of: "^[A-Za-z0-9.:-]+$", options: .regularExpression) != nil else {
            return []
        }
        
        do {
            _ = try await fetchStockPrice(symbol: query, timeout: timeout)
            return [SymbolSearchResult(
                symbol: query.uppercased(),
                name: query.uppercased(),
                dataSource: .rapidAPI
            )]
        } catch {
            return []
        }
    }
}

// MARK: - RapidAPI response models
private struct RapidAPIQuoteResponse: Decodable {
    let price: RapidAPIPriceSection?
    let summaryDetail: RapidAPIPriceSection?
}

private struct RapidAPIPriceSection: Decodable {
    let regularMarketPrice: RapidAPIValue?
    let regularMarketPreviousClose: RapidAPIValue?
}

private struct RapidAPIValue: Decodable {
    let raw: Double?
    let fmt: String?
}

private struct RapidAPISearchResponse: Decodable {
    let quotes: [RapidAPISearchQuote]?
}

private struct RapidAPISearchQuote: Decodable {
    let symbol: String
    let shortname: String
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

// MARK: - Twelve Data Adapter Stub
final class TwelveDataAdapter: StockPriceProviding {
    func fetchStockPrice(symbol: String, timeout: TimeInterval = 10.0) async throws -> StockQuote {
        throw ServiceError(
            message: "Twelve Data not configured",
            dataSource: .twelveData,
            underlyingError: nil
        )
    }
    
    func searchSymbol(_ query: String, timeout: TimeInterval = 10.0) async throws -> [SymbolSearchResult] {
        throw ServiceError(
            message: "Twelve Data not configured",
            dataSource: .twelveData,
            underlyingError: nil
        )
    }
}

// MARK: - Enhanced Default Service with Comprehensive Fallback Logic
@MainActor
final class DefaultStockPriceService: ObservableObject, StockPriceProviding {
    private let primary: StockPriceProviding
    private let fallback: StockPriceProviding
    private let secondaryFallback: StockPriceProviding
    private let marketSignalProvider: MarketSignalProviding
    private let cache: SmartCacheManager
    private let maxRetries: Int
    private let baseTimeout: TimeInterval
    
    // Service status tracking
    @Published private(set) var lastDataSource: StockQuote.DataSource?
    @Published private(set) var lastRefreshTime: Date?
    @Published private(set) var isAlphaVantageAvailable: Bool
    @Published private(set) var isTwelveDataAvailable: Bool
    @Published private(set) var lastError: ServiceError?
    @Published private(set) var marketSignal: AIMarketSignal?

    init(
        primary: StockPriceProviding? = nil,
        fallback: StockPriceProviding? = nil,
        secondaryFallback: StockPriceProviding? = nil,
        marketSignalProvider: MarketSignalProviding? = nil,
        maxRetries: Int = 3,
        baseTimeout: TimeInterval = 8.0
    ) {
        self.primary = primary ?? RapidAPIService()
        self.fallback = fallback ?? AlphaVantageAdapter()
        self.secondaryFallback = secondaryFallback ?? TwelveDataAdapter()
        self.marketSignalProvider = marketSignalProvider ?? MockMarketSignalService()
        self.cache = SmartCacheManager.shared
        self.maxRetries = maxRetries
        self.baseTimeout = baseTimeout
        
        // This assignment forces the initializer to be isolated to the main actor,
        // which resolves a warning about calling a main-actor isolated initializer
        // from a non-isolated context.
        self.isAlphaVantageAvailable = true
        self.isTwelveDataAvailable = true
    }

    func fetchStockPrice(symbol: String, timeout: TimeInterval = 8.0) async throws -> StockQuote {
        let cacheKey = "stock_quote_\(symbol.uppercased())"
        
        // Attempt primary source (RapidAPI)
        do {
            let quote = try await retryWithExponentialBackoff(maxRetries: maxRetries) {
                try await self.primary.fetchStockPrice(symbol: symbol, timeout: timeout)
            }
            
            await cacheQuote(quote, key: cacheKey)
            updateStatus(dataSource: .rapidAPI, error: nil)
            return quote
            
        } catch {
            print("RapidAPI failed for \(symbol): \(error.localizedDescription)")
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
        
        // Attempt secondary fallback source (Twelve Data) if available
        if isTwelveDataAvailable {
            do {
                let quote = try await retryWithExponentialBackoff(maxRetries: maxRetries) {
                    try await self.secondaryFallback.fetchStockPrice(symbol: symbol, timeout: timeout * 2.0)
                }
                
                await cacheQuote(quote, key: cacheKey)
                updateStatus(dataSource: .twelveData, error: nil)
                return quote
                
            } catch {
                print("Twelve Data failed for \(symbol): \(error.localizedDescription)")
                
                if error.localizedDescription.contains("API key") || error.localizedDescription.contains("429") {
                    disableTwelveDataTemporarily()
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
        // Try primary service first (RapidAPI)
        if let results = try? await primary.searchSymbol(query, timeout: timeout), !results.isEmpty {
            updateStatus(dataSource: .rapidAPI, error: nil)
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
        
        // Secondary fallback to Twelve Data if available
        if isTwelveDataAvailable {
            do {
                let results = try await secondaryFallback.searchSymbol(query, timeout: timeout * 2.0)
                updateStatus(dataSource: .twelveData, error: nil)
                return results
            } catch {
                if error.localizedDescription.contains("API key") || error.localizedDescription.contains("429") {
                    disableTwelveDataTemporarily()
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
    
    private func disableTwelveDataTemporarily() {
        isTwelveDataAvailable = false
        
        // Re-enable Twelve Data after 10 minutes
        Task {
            try await Task.sleep(for: .seconds(600))
            await MainActor.run {
                self.isTwelveDataAvailable = true
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
        
        // Cache for 5 minutes for RapidAPI real-time data, 10 minutes for fallbacks
        let cacheExpiry: TimeInterval = quote.dataSource == .rapidAPI ? 300 : 600
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
