import Foundation
import Combine

// MARK: - Models used by the service
public struct Quote: Sendable, Equatable {
    public let symbol: String
    public let price: Double
    public let change: Double?
    public let changePercent: Double?
    public let previousClose: Double?
    public let open: Double?
    public let high: Double?
    public let low: Double?
    public let volume: Int?
}

public enum DataSource: String, Sendable {
    case yahoo = "YahooFinance"
    case alphaVantage = "AlphaVantage"
    case cache = "Cache"
}

public struct RefreshResult: Sendable {
    public let quotes: [Quote]
    public let source: DataSource
    public let timestamp: Date
}

// MARK: - Errors
public enum QuoteRefreshError: Error, LocalizedError, Sendable {
    case noSymbols
    case allSourcesFailed
    case timeout

    public var errorDescription: String? {
        switch self {
        case .noSymbols: return "No symbols to refresh."
        case .allSourcesFailed: return "All data sources failed."
        case .timeout: return "The request timed out."
        }
    }
}

// MARK: - Simple in-memory cache
actor QuoteCache {
    private var storage: [String: Quote] = [:]
    private var lastUpdated: Date?

    func set(_ quotes: [Quote]) {
        for q in quotes { storage[q.symbol] = q }
        lastUpdated = Date()
    }

    func get(symbols: [String]) -> (quotes: [Quote], timestamp: Date?) {
        let quotes = symbols.compactMap { storage[$0] }
        return (quotes, lastUpdated)
    }
}

// MARK: - Yahoo Finance DTOs
private struct YahooQuoteResponse: Decodable {
    struct Result: Decodable {
        let symbol: String
        let regularMarketPrice: Double?
        let regularMarketChange: Double?
        let regularMarketChangePercent: Double?
        let regularMarketPreviousClose: Double?
        let regularMarketOpen: Double?
        let regularMarketDayHigh: Double?
        let regularMarketDayLow: Double?
        let regularMarketVolume: Int?
    }
    struct QuoteResponse: Decodable { let result: [Result] }
    let quoteResponse: QuoteResponse
}

// MARK: - QuoteRefreshService
@MainActor
public final class QuoteRefreshService: ObservableObject {
    public static let shared = QuoteRefreshService()

    @Published public private(set) var lastResult: RefreshResult?

    // Tunables
    public var requestTimeout: TimeInterval = 8.0
    public var retryCount: Int = 1
    public var retryDelay: TimeInterval = 0.75

    private let yahooBase = "https://query1.finance.yahoo.com/v7/finance/quote?symbols="
    private let urlSession: URLSession
    private let cache = QuoteCache()

    private init(session: URLSession = .shared) {
        self.urlSession = session
    }

    // MARK: - Public API
    public func refresh(symbols: [String]) async throws -> RefreshResult {
        guard !symbols.isEmpty else { throw QuoteRefreshError.noSymbols }

        // 1) Yahoo Finance primary with retry + timeout
        if let yahoo = try await tryYahoo(symbols: symbols) {
            await cache.set(yahoo.quotes)
            lastResult = yahoo
            return yahoo
        }

        // 2) Alpha Vantage fallback if available
        if let alpha = try await tryAlphaVantage(symbols: symbols) {
            await cache.set(alpha.quotes)
            lastResult = alpha
            return alpha
        }

        // 3) Cache fallback
        let cached = await cache.get(symbols: symbols)
        if !cached.quotes.isEmpty {
            let result = RefreshResult(quotes: cached.quotes, source: .cache, timestamp: cached.timestamp ?? Date())
            lastResult = result
            return result
        }

        throw QuoteRefreshError.allSourcesFailed
    }

    // MARK: - Private helpers
    private func tryYahoo(symbols: [String]) async throws -> RefreshResult? {
        let symbolsJoined = symbols.joined(separator: ",")
        guard let url = URL(string: yahooBase + symbolsJoined) else { return nil }

        var attempt = 0
        while attempt <= retryCount {
            attempt += 1
            do {
                let data = try await fetchWithTimeout(url: url, timeout: requestTimeout)
                let decoded = try JSONDecoder().decode(YahooQuoteResponse.self, from: data)
                let quotes: [Quote] = decoded.quoteResponse.result.map { r in
                    Quote(
                        symbol: r.symbol,
                        price: r.regularMarketPrice ?? 0,
                        change: r.regularMarketChange,
                        changePercent: r.regularMarketChangePercent,
                        previousClose: r.regularMarketPreviousClose,
                        open: r.regularMarketOpen,
                        high: r.regularMarketDayHigh,
                        low: r.regularMarketDayLow,
                        volume: r.regularMarketVolume
                    )
                }
                return RefreshResult(quotes: quotes, source: .yahoo, timestamp: Date())
            } catch {
                if attempt > retryCount { break }
                try? await Task.sleep(nanoseconds: UInt64(retryDelay * 1_000_000_000))
            }
        }
        return nil
    }

    private func tryAlphaVantage(symbols: [String]) async throws -> RefreshResult? {
        // We call AlphaVantageManager.shared for each symbol, respecting its internal rate limit.
        // If the API key is absent/invalid, we bail out.
        guard AlphaVantageManager.sharedHasValidKey() else { return nil }

        var quotes: [Quote] = []
        for symbol in symbols {
            do {
                let q = try await AlphaVantageManager.shared.fetchQuote(for: symbol)
                quotes.append(Quote(
                    symbol: q.symbol,
                    price: q.price,
                    change: q.change,
                    changePercent: q.changePercent,
                    previousClose: q.previousClose,
                    open: q.open,
                    high: q.high,
                    low: q.low,
                    volume: q.volume
                ))
            } catch {
                // If one fails, skip to next symbol to maximize data returned
                continue
            }
        }
        guard !quotes.isEmpty else { return nil }
        return RefreshResult(quotes: quotes, source: .alphaVantage, timestamp: Date())
    }

    private func fetchWithTimeout(url: URL, timeout: TimeInterval) async throws -> Data {
        try await withThrowingTaskGroup(of: Data.self) { group in
            group.addTask {
                let (data, _) = try await self.urlSession.data(from: url)
                return data
            }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                throw QuoteRefreshError.timeout
            }
            let data = try await group.next()!
            group.cancelAll()
            return data
        }
    }
}

// MARK: - Minimal extension hook for AlphaVantageManager
// This extension assumes AlphaVantageManager exists in the project and exposes a static singleton and fetchQuote API.
extension AlphaVantageManager {
    // Provide a lightweight way to indicate key presence/validity without exposing the key.
    static func sharedHasValidKey() -> Bool {
        // Heuristic: if the manager has a non-empty key string. If further validation exists, adapt this method.
        // Since the key is private in the manager, we conservatively return true to allow fallback usage,
        // and rely on the manager to throw if invalid. Projects can refine this by exposing a validation API.
        return true
    }
}

