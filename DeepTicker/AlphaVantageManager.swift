import Foundation
import Combine
import SwiftUI

// MARK: - Alpha Vantage API Manager
@MainActor
class AlphaVantageManager: ObservableObject {
    static let shared = AlphaVantageManager()
    
    private let baseURL = "https://www.alphavantage.co/query"
    private let apiKey = "E1ROYME4HFCB3C94" // Your provided API key
    private let session = URLSession.shared
    private var requestCount = 0
    private var lastRequestTime = Date()
    private var cancellables = Set<AnyCancellable>()
    
    // Rate limiting: 5 requests per minute
    private let maxRequestsPerMinute = 5
    private let requestInterval: TimeInterval = 60.0 // 1 minute
    
    private init() {}
    
    // MARK: - Public Methods
    func fetchQuote(for symbol: String) async throws -> AlphaVantageStockQuote {
        try await enforceRateLimit()
        
        let endpoint = "GLOBAL_QUOTE"
        let url = buildURL(function: endpoint, symbol: symbol)
        
        do {
            let (data, _) = try await session.data(from: url)
            // Log successful response payload
            self.logDebug(endpoint: endpoint, symbol: symbol, requestJSON: nil, responseData: data, error: nil)
            
            let response = try JSONDecoder().decode(AlphaVantageQuoteResponse.self, from: data)
            
            guard let quote = response.globalQuote else {
                throw APIError.invalidResponse
            }
            
            return AlphaVantageStockQuote(
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
        } catch {
            // Log error
            self.logDebug(endpoint: endpoint, symbol: symbol, requestJSON: nil, responseData: nil, error: error)
            throw APIError.networkError(error)
        }
    }
    
    func fetchHistoricalData(for symbol: String, interval: String = "daily") async throws -> [AlphaVantageHistoricalDataPoint] {
        try await enforceRateLimit()
        
        let endpoint = "TIME_SERIES_DAILY"
        let url = buildURL(function: endpoint, symbol: symbol)
        
        do {
            let (data, _) = try await session.data(from: url)
            self.logDebug(endpoint: endpoint, symbol: symbol, requestJSON: nil, responseData: data, error: nil)
            
            let response = try JSONDecoder().decode(AlphaVantageTimeSeriesResponse.self, from: data)
            
            guard let timeSeries = response.timeSeriesDaily else {
                throw APIError.invalidResponse
            }
            
            return timeSeries.compactMap { key, value in
                guard let date = DateFormatter.yyyyMMdd.date(from: key),
                      let open = Double(value.open),
                      let high = Double(value.high),
                      let low = Double(value.low),
                      let close = Double(value.close),
                      let volume = Int(value.volume) else {
                    return nil
                }
                
                return AlphaVantageHistoricalDataPoint(
                    date: date,
                    open: open,
                    high: high,
                    low: low,
                    close: close,
                    volume: volume
                )
            }.sorted { $0.date < $1.date }
        } catch {
            self.logDebug(endpoint: endpoint, symbol: symbol, requestJSON: nil, responseData: nil, error: error)
            throw APIError.networkError(error)
        }
    }
    
    // MARK: - Private Methods
    private func buildURL(function: String, symbol: String) -> URL {
        var components = URLComponents(string: baseURL)!
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
                try await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
                requestCount = 0
                lastRequestTime = Date()
            }
        }
        
        requestCount += 1
    }
    
    private func parseChangePercent(_ changePercent: String) -> Double {
        let cleaned = changePercent.replacingOccurrences(of: "%", with: "")
        return Double(cleaned) ?? 0.0
    }
    
    private func logDebug(endpoint: String, symbol: String?, requestJSON: String? = nil, responseData: Data?, error: Error?) {
        let enabled = DebugSettings.load().debugConsoleEnabled
        guard enabled else { return }
        let responseJSON = responseData.flatMap { String(data: $0, encoding: .utf8) }
        DebugConsoleManager.shared.log(
            endpoint: endpoint,
            symbol: symbol,
            requestJSON: requestJSON,
            responseJSON: responseJSON,
            error: error?.localizedDescription
        )
    }
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
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
