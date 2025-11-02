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

    // MARK: - AI Market Signal Scoring (Data Layer)
    struct MetricDisplay {
        let title: String
        let value: Double // 0-100 for % metrics; Gain Potential is also % of price
        let unit: String // "%"
        let colorHex: String
        let trendArrow: String // ↑ → ↓
        let tooltip: String
        let highlight: Bool // true when value > 90 for emphasis
    }

    struct MarketSignalScore {
        let score: Int // 0-100 composite
        let label: String
        let colorHex: String
    }

    struct MarketSignalBundle {
        let todaysProfitLikelihood: MetricDisplay
        let forecastedGainPotential: MetricDisplay
        let profitConfidenceScore: MetricDisplay
        let projectedUpsideChance: MetricDisplay
        let composite: MarketSignalScore
    }

    // Public entry to compute all four metrics and composite
    // Inputs are assumed to be already normalized or raw values as described per metric.
    func buildMarketSignal(
        previous: MarketSignalBundle?,
        rsi: Double,
        macd: Double,
        volumeSurge: Double, // 0-100
        sentimentScore: Double, // 0-100
        historicalWinRate: Double, // 0-100
        recentIntradayGains: Double, // %
        atrPercent: Double, // ATR expressed as % of price
        breakoutDistancePercent: Double, // % to resistance
        signalClarity: Double, // 0-100
        dataConsistency: Double, // 0-100
        noiseLevel: Double, // 0-100 (higher is noisier)
        macdEmaCrossover: Double, // 0-100 probability proxy
        rsiTrend: Double, // 0-100 upward trend strength
        sectorMomentum: Double, // 0-100
        socialBuzz: Double // 0-100
    ) -> MarketSignalBundle {
        // 1) Today's Profit Likelihood (%): normalized 0-100
        let profitLikelihoodRaw = normalize01(
            0.25 * normalizeRSI(rsi) +
            0.25 * normalizeMACD(macd) +
            0.20 * clamp01(volumeSurge / 100.0) +
            0.15 * clamp01(sentimentScore / 100.0) +
            0.15 * clamp01(historicalWinRate / 100.0)
        ) * 100.0
        let profitLikelihood = clampPercent(profitLikelihoodRaw)
        let profitLikelihoodColor = colorForProfitLikelihood(profitLikelihood)

        // 2) Forecasted Gain Potential (% of price)
        // Combine recent intraday gains, ATR%, and breakout distance (smaller distance -> higher potential)
        let breakoutComponent = max(0, 1.0 - clamp01(breakoutDistancePercent / 10.0)) // closer than 10% is stronger
        let gainPotentialPct = max(0.0, recentIntradayGains) * 0.5 + atrPercent * 0.3 + breakoutComponent * 100.0 * 0.2
        let gainPotentialColor = colorForGainPotential(gainPotentialPct)

        // 3) Profit Confidence Score (%): higher clarity/consistency, lower noise
        let confidenceRaw = normalize01(
            0.45 * clamp01(signalClarity / 100.0) +
            0.35 * clamp01(dataConsistency / 100.0) +
            0.20 * (1.0 - clamp01(noiseLevel / 100.0))
        ) * 100.0
        let confidence = clampPercent(confidenceRaw)
        let confidenceColor = colorForConfidence(confidence)

        // 4) Projected Upside Chance (%): directional blend
        let upsideRaw = normalize01(
            0.35 * clamp01(macdEmaCrossover / 100.0) +
            0.25 * clamp01(rsiTrend / 100.0) +
            0.25 * clamp01(sectorMomentum / 100.0) +
            0.15 * clamp01(socialBuzz / 100.0)
        ) * 100.0
        let upside = clampPercent(upsideRaw)
        let upsideColor = colorForUpside(upside)

        // Trend arrows comparing to previous values (if provided)
        let arrowPL = trendArrow(current: profitLikelihood, previous: previous?.todaysProfitLikelihood.value)
        let arrowGP = trendArrow(current: gainPotentialPct, previous: previous?.forecastedGainPotential.value)
        let arrowCS = trendArrow(current: confidence, previous: previous?.profitConfidenceScore.value)
        let arrowUC = trendArrow(current: upside, previous: previous?.projectedUpsideChance.value)

        let pl = MetricDisplay(
            title: "Today’s Profit Likelihood",
            value: profitLikelihood,
            unit: "%",
            colorHex: profitLikelihoodColor,
            trendArrow: arrowPL,
            tooltip: "Chance of closing higher today. Inputs: RSI, MACD, volume surge, sentiment score, historical win rate.",
            highlight: profitLikelihood >= 90
        )
        let gp = MetricDisplay(
            title: "Forecasted Gain Potential",
            value: gainPotentialPct,
            unit: "%",
            colorHex: gainPotentialColor,
            trendArrow: arrowGP,
            tooltip: "Estimated magnitude of upside if bullish. Inputs: recent intraday gains, ATR, breakout distance.",
            highlight: gainPotentialPct >= 90
        )
        let cs = MetricDisplay(
            title: "Profit Confidence Score",
            value: confidence,
            unit: "%",
            colorHex: confidenceColor,
            trendArrow: arrowCS,
            tooltip: "AI certainty in its prediction. Inputs: signal clarity, data consistency, noise level.",
            highlight: confidence >= 90
        )
        let uc = MetricDisplay(
            title: "Projected Upside Chance",
            value: upside,
            unit: "%",
            colorHex: upsideColor,
            trendArrow: arrowUC,
            tooltip: "Probability of upward movement. Inputs: MACD/EMA crossover, RSI trend, sector momentum, social buzz.",
            highlight: upside >= 90
        )

        // Composite score using default weights 35/25/25/15
        let composite = computeMarketSignalScore(
            todayProfitLikelihood: profitLikelihood,
            forecastedGainPotential: min(100, gainPotentialPct),
            profitConfidenceScore: confidence,
            projectedUpsideChance: upside,
            weights: nil
        )

        return MarketSignalBundle(
            todaysProfitLikelihood: pl,
            forecastedGainPotential: gp,
            profitConfidenceScore: cs,
            projectedUpsideChance: uc,
            composite: composite
        )
    }

    // Composite score and banding
    func computeMarketSignalScore(todayProfitLikelihood: Double,
                                  forecastedGainPotential: Double,
                                  profitConfidenceScore: Double,
                                  projectedUpsideChance: Double,
                                  weights: (Double, Double, Double, Double)? = nil) -> MarketSignalScore {
        let w = weights ?? (0.35, 0.25, 0.25, 0.15)
        let raw = todayProfitLikelihood * w.0 +
                  forecastedGainPotential * w.1 +
                  profitConfidenceScore * w.2 +
                  projectedUpsideChance * w.3
        let clamped = max(0, min(100, Int(round(raw))))
        let band: (String, String)
        switch clamped {
        case 0...40: band = ("Weak Signal", "#FF3B30")
        case 41...70: band = ("Moderate Signal", "#FFCC00")
        default: band = ("Strong Signal", "#34C759")
        }
        return MarketSignalScore(score: clamped, label: band.0, colorHex: band.1)
    }

    // MARK: - Metric Color Helpers
    private func colorForProfitLikelihood(_ v: Double) -> String {
        switch v {
        case ..<40: return "#FF3B30" // Red
        case 41...70: return "#FFCC00" // Yellow
        default: return "#34C759" // Green
        }
    }

    private func colorForGainPotential(_ v: Double) -> String {
        if v <= 1.0 { return "#C7C7CC" } // Gray
        if v <= 3.0 { return "#FFCC00" } // Yellow
        return "#34C759" // Green
    }

    private func colorForConfidence(_ v: Double) -> String {
        switch v {
        case ..<50: return "#FF3B30" // Red
        case 51...80: return "#FFCC00" // Yellow
        default: return "#34C759" // Green
        }
    }

    private func colorForUpside(_ v: Double) -> String {
        switch v {
        case ..<40: return "#FF3B30"
        case 41...70: return "#FFCC00"
        default: return "#34C759"
        }
    }

    // MARK: - Normalization & Trends
    private func normalizeRSI(_ rsi: Double) -> Double {
        // RSI 30-70 maps to 0-1, with tails clamped
        let clamped = max(0, min(100, rsi))
        return clamp01((clamped - 30.0) / 40.0)
    }

    private func normalizeMACD(_ macd: Double) -> Double {
        // Heuristic: tanh to compress extremes
        return clamp01(0.5 + 0.5 * tanh(macd))
    }

    private func clampPercent(_ v: Double) -> Double { return max(0, min(100, v)) }
    private func clamp01(_ v: Double) -> Double { return max(0, min(1, v)) }
    private func normalize01(_ v: Double) -> Double { return clamp01(v) }

    private func trendArrow(current: Double, previous: Double?) -> String {
        guard let p = previous else { return "→" }
        if current > p + 0.5 { return "↑" }
        if current < p - 0.5 { return "↓" }
        return "→"
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
    private let apiKey = "E1ROYME4HFCB3C94" // Your provided API key
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

