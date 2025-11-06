import Foundation
import Combine

// MARK: - Alpha Vantage API Manager
@MainActor
class AlphaVantageManager: ObservableObject {
    enum DataSource: String { case yahoo = "Yahoo", alphaVantage = "Alpha Vantage", cache = "Cached" }

    // Published state for UI transparency
    @Published private(set) var lastRefresh: Date? = nil
    @Published private(set) var lastDataSource: DataSource = .alphaVantage

    static let shared = AlphaVantageManager()

    // Simple in-memory cache with expiry
    private struct CacheEntry<T> { let value: T; let timestamp: Date; let ttl: TimeInterval }
    private var quoteCache: [String: CacheEntry<AlphaVantageStockQuote>] = [:]
    private var historyCache: [String: CacheEntry<[AlphaVantageHistoricalDataPoint]>] = [:]

    // Cache policy (default 15 minutes)
    var defaultTTL: TimeInterval = 15 * 60

    // Networking configuration
    private let requestTimeout: TimeInterval = 12 // seconds
    private let maxRetries = 2

    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = requestTimeout
        config.timeoutIntervalForResource = requestTimeout
        return URLSession(configuration: config)
    }()

    private var requestCount = 0
    private var lastRequestTime = Date()

    // Rate limiting: 5 requests per minute
    private let maxRequestsPerMinute = 5
    private let requestInterval: TimeInterval = 60.0 // 1 minute

    private init() {}

    // MARK: - Public Methods
    func fetchQuote(for symbol: String) async throws -> AlphaVantageStockQuote {
        try await enforceRateLimit()

        // Check cache first
        if let entry = quoteCache[symbol], Date().timeIntervalSince(entry.timestamp) < entry.ttl {
            lastDataSource = .cache
            lastRefresh = entry.timestamp
            return entry.value
        }

        let endpoint = "GLOBAL_QUOTE"
        let url = buildURL(function: endpoint, symbol: symbol)

        do {
            let data = try await fetchWithRetry(from: url)

            let response = try JSONDecoder().decode(AlphaVantageQuoteResponse.self, from: data)

            guard let quote = response.globalQuote else {
                throw APIError.invalidResponse
            }

            let built = AlphaVantageStockQuote(
                symbol: quote.symbol,
                price: Double(quote.price) ?? 0.0,
                change: Double(quote.change) ?? 0.0,
                changePercent: parseChangePercent(quote.changePercent),
                previousClose: Double(quote.previousClose) ?? 0.0,
                open: Double(quote.open) ?? 0.0,
                high: Double(quote.high) ?? 0.0,
                low: Double(quote.low) ?? 0.0,
                volume: Int(quote.volume) ?? 0
            )
            let now = Date()
            quoteCache[symbol] = CacheEntry(value: built, timestamp: now, ttl: defaultTTL)
            lastDataSource = .alphaVantage
            lastRefresh = now
            return built
        } catch {
            throw APIError.networkError(error)
        }
    }

    func fetchHistoricalData(for symbol: String, interval: String = "daily") async throws -> [AlphaVantageHistoricalDataPoint] {
        try await enforceRateLimit()

        // Check cache first
        if let entry = historyCache[symbol], Date().timeIntervalSince(entry.timestamp) < entry.ttl {
            lastDataSource = .cache
            lastRefresh = entry.timestamp
            return entry.value
        }

        let endpoint = "TIME_SERIES_DAILY"
        let url = buildURL(function: endpoint, symbol: symbol)

        do {
            let data = try await fetchWithRetry(from: url)

            let response = try JSONDecoder().decode(AlphaVantageTimeSeriesResponse.self, from: data)

            guard let timeSeries = response.timeSeriesDaily else {
                throw APIError.invalidResponse
            }

            var points: [AlphaVantageHistoricalDataPoint] = []
            points.reserveCapacity(timeSeries.count)
            for (key, value) in timeSeries {
                guard let date = DateFormatter.yyyyMMdd.date(from: key) else { continue }
                guard let open = Double(value.open) else { continue }
                guard let high = Double(value.high) else { continue }
                guard let low = Double(value.low) else { continue }
                guard let close = Double(value.close) else { continue }
                guard let volume = Int(value.volume) else { continue }
                let point = AlphaVantageHistoricalDataPoint(
                    date: date,
                    open: open,
                    high: high,
                    low: low,
                    close: close,
                    volume: volume
                )
                points.append(point)
            }
            points.sort { $0.date < $1.date }
            let now = Date()
            historyCache[symbol] = CacheEntry(value: points, timestamp: now, ttl: defaultTTL)
            lastDataSource = .alphaVantage
            lastRefresh = now
            return points
        } catch {
            throw APIError.networkError(error)
        }
    }

    // MARK: - Private Methods
    private func fetchWithRetry(from url: URL) async throws -> Data {
        var lastError: Error?
        for attempt in 0...maxRetries {
            do {
                let (data, _) = try await session.data(from: url)
                return data
            } catch {
                lastError = error
                // Exponential backoff
                let delay = UInt64(pow(2.0, Double(attempt)) * 0.5 * 1_000_000_000)
                try? await Task.sleep(nanoseconds: delay)
                continue
            }
        }
        throw APIError.networkError(lastError ?? URLError(.unknown))
    }

    private func buildURL(function: String, symbol: String) -> URL {
        guard var components = URLComponents(string: baseURL) else {
            preconditionFailure("Invalid base URL: \(baseURL)")
        }
        components.queryItems = [
            URLQueryItem(name: "function", value: function),
            URLQueryItem(name: "symbol", value: symbol),
            URLQueryItem(name: "apikey", value: apiKey)
        ]
        return components.url!
    }

    private func enforceRateLimit() async throws {
        let now = Date()

        // Reset counter if more than a minute has passed
        if now.timeIntervalSince(lastRequestTime) >= requestInterval {
            requestCount = 0
            lastRequestTime = now
        }

        // Check if we've exceeded the rate limit
        if requestCount >= maxRequestsPerMinute {
            let waitTime = requestInterval - now.timeIntervalSince(lastRequestTime)
            if waitTime > 0 {
                let ns = UInt64(max(0, waitTime) * 1_000_000_000)
                try await Task.sleep(nanoseconds: ns)
                requestCount = 0
                lastRequestTime = Date()
            }
        }

        requestCount += 1
    }

    func clearCaches() {
        quoteCache.removeAll()
        historyCache.removeAll()
    }

    private func parseChangePercent(_ changePercent: String) -> Double {
        let cleaned = changePercent.replacingOccurrences(of: "%", with: "")
        return Double(cleaned) ?? 0.0
    }

    private let baseURL = "https://www.alphavantage.co/query"
    private let apiKey = "E1ROYME4HFCB3C94"
}

// MARK: - API Response Models
struct AlphaVantageQuoteResponse: Codable {
    let globalQuote: GlobalQuote?

    enum CodingKeys: String, CodingKey {
        case globalQuote = "Global Quote"
    }
}

struct GlobalQuote: Codable {
    let symbol: String
    let open: String
    let high: String
    let low: String
    let price: String
    let volume: String
    let latestTradingDay: String
    let previousClose: String
    let change: String
    let changePercent: String

    enum CodingKeys: String, CodingKey {
        case symbol = "01. symbol"
        case open = "02. open"
        case high = "03. high"
        case low = "04. low"
        case price = "05. price"
        case volume = "06. volume"
        case latestTradingDay = "07. latest trading day"
        case previousClose = "08. previous close"
        case change = "09. change"
        case changePercent = "10. change percent"
    }
}

struct AlphaVantageTimeSeriesResponse: Codable {
    let timeSeriesDaily: [String: TimeSeriesData]?

    enum CodingKeys: String, CodingKey {
        case timeSeriesDaily = "Time Series (Daily)"
    }
}

struct TimeSeriesData: Codable {
    let open: String
    let high: String
    let low: String
    let close: String
    let volume: String

    enum CodingKeys: String, CodingKey {
        case open = "1. open"
        case high = "2. high"
        case low = "3. low"
        case close = "4. close"
        case volume = "5. volume"
    }
}

// MARK: - Data Models
struct AlphaVantageStockQuote {
    let symbol: String
    let price: Double
    let change: Double
    let changePercent: Double
    let previousClose: Double
    let open: Double
    let high: Double
    let low: Double
    let volume: Int
}

struct AlphaVantageHistoricalDataPoint {
    let date: Date
    let open: Double
    let high: Double
    let low: Double
    let close: Double
    let volume: Int
}

// MARK: - Error Types
enum APIError: Error, LocalizedError {
    case invalidResponse
    case networkError(Error)
    case rateLimitExceeded
    case invalidAPIKey

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .rateLimitExceeded:
            return "API rate limit exceeded"
        case .invalidAPIKey:
            return "Invalid API key"
        }
    }
}

// MARK: - Extensions
extension DateFormatter {
    static let yyyyMMdd: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
