import Foundation

class AlphaVantageService {
    private let baseURL = "https://www.alphavantage.co/query"
    
    private var apiKey: String {
        // Use SecureConfigurationManager for consistent API key management
        let configManager = SecureConfigurationManager.shared
        let settingsKey = configManager.alphaVantageAPIKey
        
        if !settingsKey.isEmpty {
            let masked = settingsKey.count >= 4 ? "***" + settingsKey.suffix(4) : "***" + settingsKey
            print("🔑 AlphaVantageService using API key from SecureConfigurationManager: \(masked)")
            return settingsKey
        }
        
        print("🔑 AlphaVantageService using API key: EMPTY (no key configured)")
        return ""
    }
    
    enum AlphaVantageError: Error, LocalizedError {
        case invalidURL
        case noAPIKey
        case noData
        case invalidResponse
        case rateLimitExceeded
        
        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Invalid URL"
            case .noAPIKey:
                return "No API key provided. Please set your Alpha Vantage API key in settings."
            case .noData:
                return "No data received from server"
            case .invalidResponse:
                return "Invalid response format"
            case .rateLimitExceeded:
                return "API rate limit exceeded. Please try again later."
            }
        }
    }
    
    func fetchStockPrice(symbol: String) async throws -> AlphaVantageStock {
        guard !apiKey.isEmpty else {
            throw AlphaVantageError.noAPIKey
        }
        
        guard let url = URL(string: "\(baseURL)?function=GLOBAL_QUOTE&symbol=\(symbol)&apikey=\(apiKey)") else {
            throw AlphaVantageError.invalidURL
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        
        let response = try JSONDecoder().decode(AlphaVantageResponse.self, from: data)
        
        if response.information?.contains("rate limit") == true {
            throw AlphaVantageError.rateLimitExceeded
        }
        
        guard let quote = response.globalQuote else {
            throw AlphaVantageError.invalidResponse
        }
        
        return AlphaVantageStock(
            symbol: quote.symbol,
            currentPrice: Double(quote.price) ?? 0,
            previousClose: Double(quote.previousClose) ?? 0
        )
    }
    
    func searchSymbol(_ query: String) async throws -> [StockSearchResult] {
        guard !apiKey.isEmpty else {
            throw AlphaVantageError.noAPIKey
        }
        
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        guard let url = URL(string: "\(baseURL)?function=SYMBOL_SEARCH&keywords=\(encodedQuery)&apikey=\(apiKey)") else {
            throw AlphaVantageError.invalidURL
        }
        
        print("🔍 Alpha Vantage search URL: \(url.absoluteString)")
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            // Check HTTP response
            if let httpResponse = response as? HTTPURLResponse {
                print("🔍 Alpha Vantage HTTP status: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode == 429 {
                    throw AlphaVantageError.rateLimitExceeded
                }
            }
            
            // Debug: print raw response
            if let jsonString = String(data: data, encoding: .utf8) {
                print("🔍 Alpha Vantage raw response: \(String(jsonString.prefix(200)))...")
            }
            
            let searchResponse = try JSONDecoder().decode(StockSearchResponse.self, from: data)
            
            // Check if response contains error message
            if let jsonDict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let info = jsonDict["Information"] as? String {
                print("🔍 Alpha Vantage info message: \(info)")
                if info.lowercased().contains("rate limit") {
                    throw AlphaVantageError.rateLimitExceeded
                }
            }
            
            let results = searchResponse.bestMatches ?? []
            print("🔍 Alpha Vantage search decoded \(results.count) results")
            return results
            
        } catch let decodingError as DecodingError {
            print("🔍 Alpha Vantage decoding error: \(decodingError)")
            throw AlphaVantageError.invalidResponse
        } catch let error as AlphaVantageError {
            throw error
        } catch {
            print("🔍 Alpha Vantage network error: \(error)")
            throw error
        }
    }
}

// MARK: - Response Models

struct AlphaVantageStock: Sendable {
    let symbol: String
    let currentPrice: Double
    let previousClose: Double
}

struct AlphaVantageResponse: Codable {
    let globalQuote: AlphaVantageGlobalQuote?
    let information: String?
    
    enum CodingKeys: String, CodingKey {
        case globalQuote = "Global Quote"
        case information = "Information"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.globalQuote = try? container.decode(AlphaVantageGlobalQuote.self, forKey: .globalQuote)
        self.information = try? container.decode(String.self, forKey: .information)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if let globalQuote = globalQuote {
            try container.encode(globalQuote, forKey: .globalQuote)
        }
        if let information = information {
            try container.encode(information, forKey: .information)
        }
    }
}

struct AlphaVantageGlobalQuote: Codable {
    let symbol: String
    let price: String
    let previousClose: String
    
    enum CodingKeys: String, CodingKey {
        case symbol = "01. symbol"
        case price = "05. price"
        case previousClose = "08. previous close"
    }
}

struct StockSearchResponse: Codable {
    let bestMatches: [StockSearchResult]?
    
    enum CodingKeys: String, CodingKey {
        case bestMatches = "bestMatches"
    }
}

struct StockSearchResult: Codable, Identifiable {
    let id = UUID()
    let symbol: String
    let name: String
    let type: String
    let region: String
    let currency: String
    
    enum CodingKeys: String, CodingKey {
        case symbol = "1. symbol"
        case name = "2. name"
        case type = "3. type"
        case region = "4. region"
        case currency = "8. currency"
    }
}

