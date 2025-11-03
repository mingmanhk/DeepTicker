import Foundation
import SwiftUI
import Combine

// MARK: - DeepSeek AI Manager
class DeepSeekManager: ObservableObject {
    static let shared = DeepSeekManager()

    private let baseURL = "https://api.deepseek.com/v1/chat/completions"
    private let session = URLSession.shared

    private var apiKey: String {
        // Get API key from SecureConfigurationManager (System tab API key)
        if let systemKey = SecureConfigurationManager.shared.getAPIKey(for: .deepSeek) {
            return systemKey
        }
        
        // Fallback to environment variable
        if let envKey = ProcessInfo.processInfo.environment["DEEPSEEK_API_KEY"], !envKey.isEmpty {
            return envKey
        }
        
        // Last resort: return empty string (will trigger hasValidAPIKey to return false)
        return ""
    }
    
    private var hasValidAPIKey: Bool { 
        let key = apiKey
        return !key.isEmpty && !key.hasPrefix("REPLACE_") && !key.hasPrefix("your_")
    }

    private init() {}

    // MARK: - Public Methods
    func generateStockPrediction(
        for stock: Stock,
        historicalData: [HistoricalDataPoint]
    ) async throws -> StockPrediction {

        let prompt = AIInsightSystemPrompt(for: stock, with: historicalData)

        let requestBody = DeepSeekAPIRequest(
            model: "deepseek-chat",
            messages: [
                DeepSeekAPIMessage(role: "system", content: systemPrompt),
                DeepSeekAPIMessage(role: "user", content: prompt)
            ],
            temperature: 0.3,
            max_tokens: 500
        )

        var request = URLRequest(url: URL(string: baseURL)!)
        guard hasValidAPIKey else { throw DeepSeekError.noAPIKey }
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        do {
            let jsonData = try JSONEncoder().encode(requestBody)
            request.httpBody = jsonData

            let (data, _) = try await session.data(for: request)
            let response = try JSONDecoder().decode(DeepSeekAPIResponse.self, from: data)

            guard let firstChoice = response.choices.first,
                  !firstChoice.message.content.isEmpty else {
                throw DeepSeekError.invalidResponse
            }
            let content = firstChoice.message.content

            return try parsePredictionResponse(content: content, symbol: stock.symbol)

        } catch {
            throw DeepSeekError.networkError(error)
        }
    }

    func generatePortfolioAnalysis(for stocks: [Stock]) async throws -> PortfolioAnalysis {
        let prompt = SummaryConfidencePrompt(for: stocks)

        let requestBody = DeepSeekAPIRequest(
            model: "deepseek-chat",
            messages: [
                DeepSeekAPIMessage(role: "system", content: SummaryRiskSystemPrompt),
                DeepSeekAPIMessage(role: "user", content: prompt)
            ],
            temperature: 0.4,
            max_tokens: 800
        )

        var request = URLRequest(url: URL(string: baseURL)!)
        guard hasValidAPIKey else { throw DeepSeekError.noAPIKey }
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        do {
            let jsonData = try JSONEncoder().encode(requestBody)
            request.httpBody = jsonData

            let (data, _) = try await session.data(for: request)
            let response = try JSONDecoder().decode(DeepSeekAPIResponse.self, from: data)

            guard let firstChoice = response.choices.first,
                  !firstChoice.message.content.isEmpty else {
                throw DeepSeekError.invalidResponse
            }
            let content = firstChoice.message.content

            return try parsePortfolioAnalysisResponse(content: content)

        } catch {
            throw DeepSeekError.networkError(error)
        }
    }

    func generateMarketingBriefing(for stockSymbols: [String], customPrompt: String) async throws -> MarketingBriefing {
        let prompt = buildMarketingBriefingPrompt(for: stockSymbols, customPrompt: customPrompt)
        
        let requestBody = DeepSeekAPIRequest(
            model: "deepseek-chat",
            messages: [
                DeepSeekAPIMessage(role: "system", content: marketingBriefingSystemPrompt),
                DeepSeekAPIMessage(role: "user", content: prompt)
            ],
            temperature: 0.5,
            max_tokens: 1200
        )

        var request = URLRequest(url: URL(string: baseURL)!)
        guard hasValidAPIKey else { throw DeepSeekError.noAPIKey }
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        do {
            let jsonData = try JSONEncoder().encode(requestBody)
            request.httpBody = jsonData

            let (data, _) = try await session.data(for: request)
            let response = try JSONDecoder().decode(DeepSeekAPIResponse.self, from: data)

            guard let firstChoice = response.choices.first,
                  !firstChoice.message.content.isEmpty else {
                throw DeepSeekError.invalidResponse
            }
            let content = firstChoice.message.content
            
            // Check for pessimistic responses
            if isPessimisticResponse(content) {
                throw DeepSeekError.pessimisticResponse
            }

            return try parseMarketingBriefingResponse(content: content)

        } catch let error as DeepSeekError {
            throw error
        } catch {
            throw DeepSeekError.networkError(error)
        }
    }

    // MARK: - Private Methods
    private func AIInsightSystemPrompt(for stock: Stock, with historicalData: [HistoricalDataPoint]) -> String {
        let recentData = Array(historicalData.suffix(10)) // Last 10 days
        let dataString = recentData.map { point in
            "Date: \(DateFormatter.shortDate.string(from: point.date)), Close: $\(point.close), Volume: \(point.volume)"
        }.joined(separator: "\n")

        return """
        Analyze the following stock data for \(stock.symbol):

        Current Information:
        - Symbol: \(stock.symbol)
        - Current Price: $\(stock.currentPrice)
        - Previous Close: $\(stock.previousClose)

        Recent Historical Data (Last 10 trading days):
        \(dataString)

        \(SecureConfigurationManager.shared.getPromptTemplate(for: .prediction))
        """
    }

    private func SummaryConfidencePrompt(for stocks: [Stock]) -> String {
        let stockDetails = stocks.map { stock in
            "- **\(stock.symbol):** \(String(format: "%.2f", stock.quantity)) shares, Current Price: $\(String(format: "%.2f", stock.currentPrice)), Total Value: $\(String(format: "%.2f", stock.totalValue))"
        }.joined(separator: "\n")
        
        let totalPortfolioValue = stocks.reduce(0) { $0 + $1.totalValue }

        return """
        Analyze the following investment portfolio and provide an overall summary and confidence assessment.

        **Portfolio Holdings:**
        \(stockDetails)
        
        **Total Portfolio Value:** $\(String(format: "%.2f", totalPortfolioValue))

        **Instructions:**
        \( SecureConfigurationManager.shared.getPromptTemplate(for: .profitConfidence))
        """
    }
    
    private func buildMarketingBriefingPrompt(for stockSymbols: [String], customPrompt: String) -> String {
        let symbolsList = stockSymbols.joined(separator: ", ")
        
        return """
        Portfolio Stock Symbols: \(symbolsList)
        
        \(customPrompt)
        
        \( SecureConfigurationManager.shared.getPromptTemplate(for: .portfolio))
        """
    }

    private func parsePredictionResponse(content: String, symbol: String) throws -> StockPrediction {
        // Extract JSON from response
        guard let jsonStart = content.range(of: "{"),
              let jsonEnd = content.range(of: "}", options: .backwards),
              jsonStart.lowerBound < jsonEnd.upperBound else {
            throw DeepSeekError.parsingError
        }

        let jsonString = String(content[jsonStart.lowerBound...jsonEnd.upperBound])

        guard let jsonData = jsonString.data(using: .utf8) else {
            throw DeepSeekError.parsingError
        }

        do {
            let predictionData = try JSONDecoder().decode(PredictionData.self, from: jsonData)

            let direction: PredictionDirection
            switch predictionData.direction.lowercased() {
            case "up":
                direction = .up
            case "down":
                direction = .down
            default:
                direction = .neutral
            }

            return StockPrediction(
                stockSymbol: symbol,
                prediction: direction,
                confidence: predictionData.confidence,
                predictedChange: predictionData.predicted_change,
                timestamp: Date(),
                reasoning: predictionData.reasoning
            )
        } catch {
            throw DeepSeekError.parsingError
        }
    }

    private func parsePortfolioAnalysisResponse(content: String) throws -> PortfolioAnalysis {
        // Extract JSON from response
        guard let jsonStart = content.range(of: "{"),
              let jsonEnd = content.range(of: "}", options: .backwards),
              jsonStart.lowerBound < jsonEnd.upperBound else {
            throw DeepSeekError.parsingError
        }

        let jsonString = String(content[jsonStart.lowerBound...jsonEnd.upperBound])

        guard let jsonData = jsonString.data(using: .utf8) else {
            throw DeepSeekError.parsingError
        }

        do {
            let responseData = try JSONDecoder().decode(PortfolioResponseData.self, from: jsonData)

            return PortfolioAnalysis(
                confidenceScore: responseData.insights.confidence_score,
                riskLevel: responseData.insights.risk_level
            )
        } catch {
            throw DeepSeekError.parsingError
        }
    }
    
    private func parseMarketingBriefingResponse(content: String) throws -> MarketingBriefing {
        // Extract JSON from response
        guard let jsonStart = content.range(of: "{"),
              let jsonEnd = content.range(of: "}", options: .backwards),
              jsonStart.lowerBound < jsonEnd.upperBound else {
            throw DeepSeekError.parsingError
        }

        let jsonString = String(content[jsonStart.lowerBound...jsonEnd.upperBound])

        guard let jsonData = jsonString.data(using: .utf8) else {
            throw DeepSeekError.parsingError
        }

        do {
            let responseData = try JSONDecoder().decode(MarketingBriefingResponseData.self, from: jsonData)
            
            return MarketingBriefing(
                overview: responseData.overview,
                keyDrivers: responseData.keyDrivers,
                highlightsAndActivity: responseData.highlightsAndActivity,
                riskFactors: responseData.riskFactors,
                timestamp: Date()
            )
        } catch {
            throw DeepSeekError.parsingError
        }
    }
    
    private func isPessimisticResponse(_ content: String) -> Bool {
        let pessimisticKeywords = [
            "significant decline", "major losses", "severe downturn", "catastrophic", 
            "crash", "collapse", "devastating", "extremely risky", "avoid at all costs",
            "massive selloff", "panic selling", "market crash", "bear market incoming"
        ]
        
        let lowercaseContent = content.lowercased()
        return pessimisticKeywords.contains { lowercaseContent.contains($0) }
    }

    // MARK: - Supporting Models
    struct HistoricalDataPoint: Identifiable, Codable {
        let id: UUID
        let date: Date
        let close: Double
        let volume: Int

        enum CodingKeys: String, CodingKey {
            case date, close, volume
        }

        init(date: Date, close: Double, volume: Int) {
            self.id = UUID()
            self.date = date
            self.close = close
            self.volume = volume
        }

        nonisolated init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.id = UUID()
            self.date = try container.decode(Date.self, forKey: .date)
            self.close = try container.decode(Double.self, forKey: .close)
            self.volume = try container.decode(Int.self, forKey: .volume)
        }
    }

    enum PredictionDirection: String, Codable {
        case up, down, neutral
    }

    struct Stock: Identifiable, Codable {
        let id: UUID
        let symbol: String
        let currentPrice: Double
        let previousClose: Double
        var quantity: Double = 1
        var totalValue: Double { currentPrice * quantity }

        enum CodingKeys: String, CodingKey {
            case symbol, currentPrice, previousClose, quantity
        }

        init(symbol: String, currentPrice: Double, previousClose: Double, quantity: Double = 1) {
            self.id = UUID()
            self.symbol = symbol
            self.currentPrice = currentPrice
            self.previousClose = previousClose
            self.quantity = quantity
        }

        nonisolated init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.id = UUID()
            self.symbol = try container.decode(String.self, forKey: .symbol)
            self.currentPrice = try container.decode(Double.self, forKey: .currentPrice)
            self.previousClose = try container.decode(Double.self, forKey: .previousClose)
            self.quantity = try container.decodeIfPresent(Double.self, forKey: .quantity) ?? 1
        }
    }

    struct StockPrediction: Identifiable, Codable {
        let id: UUID
        let stockSymbol: String
        let prediction: PredictionDirection
        let confidence: Double
        let predictedChange: Double
        let timestamp: Date
        let reasoning: String

        enum CodingKeys: String, CodingKey {
            case stockSymbol, prediction, confidence, predictedChange, timestamp, reasoning
        }

        init(stockSymbol: String, prediction: PredictionDirection, confidence: Double, predictedChange: Double, timestamp: Date, reasoning: String) {
            self.id = UUID()
            self.stockSymbol = stockSymbol
            self.prediction = prediction
            self.confidence = confidence
            self.predictedChange = predictedChange
            self.timestamp = timestamp
            self.reasoning = reasoning
        }

        nonisolated init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.id = UUID()
            self.stockSymbol = try container.decode(String.self, forKey: .stockSymbol)
            self.prediction = try container.decode(PredictionDirection.self, forKey: .prediction)
            self.confidence = try container.decode(Double.self, forKey: .confidence)
            self.predictedChange = try container.decode(Double.self, forKey: .predictedChange)
            self.timestamp = try container.decode(Date.self, forKey: .timestamp)
            self.reasoning = try container.decode(String.self, forKey: .reasoning)
        }
    }
    
    struct MarketingBriefing: Identifiable, Codable {
        let id: UUID
        let overview: String
        let keyDrivers: String
        let highlightsAndActivity: String
        let riskFactors: String
        let timestamp: Date
        
        enum CodingKeys: String, CodingKey {
            case overview, keyDrivers, highlightsAndActivity, riskFactors, timestamp
        }
        
        init(overview: String, keyDrivers: String, highlightsAndActivity: String, riskFactors: String, timestamp: Date) {
            self.id = UUID()
            self.overview = overview
            self.keyDrivers = keyDrivers
            self.highlightsAndActivity = highlightsAndActivity
            self.riskFactors = riskFactors
            self.timestamp = timestamp
        }
        
        nonisolated init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.id = UUID()
            self.overview = try container.decode(String.self, forKey: .overview)
            self.keyDrivers = try container.decode(String.self, forKey: .keyDrivers)
            self.highlightsAndActivity = try container.decode(String.self, forKey: .highlightsAndActivity)
            self.riskFactors = try container.decode(String.self, forKey: .riskFactors)
            self.timestamp = try container.decode(Date.self, forKey: .timestamp)
        }
    }

    // MARK: - Prompts
    private var systemPrompt: String {
        return """
        You are a financial analyst AI specialized in short-term stock predictions.
        Analyze stock data and provide concise predictions with confidence levels.
        Always respond with valid JSON format and keep explanations brief but insightful.
        Focus on technical indicators, volume trends, and recent market behavior.
        """
    }

    private var SummaryRiskSystemPrompt: String {
        return """
        You are a financial analyst AI. Your task is to provide a concise daily briefing for a stock portfolio.

        Instructions:
        1. Provide an overall "AI-Driven Stock Risk & Return Insights" section, formatted as a JSON object.
           - confidence_score (number between 0 and 1): Estimate the likelihood the portfolio will gain value today.
           - risk_level (string, one of "High", "Medium", "Low"): Assess the portfolio's overall risk level.

        2. For each stock provided, write a 1-2 sentence summary of critical news or factors impacting it today.
           - Label these summaries as "AI-generated insights".

        Example Response:

        ```json
        {
          "insights": {
            "confidence_score": 0.75,
            "risk_level": "Medium"
          },
          "stock_updates": {
            "AAPL": "AI-generated insights",
            "MSFT": "AI-generated insights"
          }
        }
        """
    }
    
    private var marketingBriefingSystemPrompt: String {
        return SecureConfigurationManager.shared.getPromptTemplate(for: .portfolio)
    }
    
}

// MARK: - Extensions
extension DateFormatter {
    static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM dd"
        return formatter
    }()
}

// MARK: - Request/Response Models
private struct DeepSeekAPIRequest: Codable {
    let model: String
    let messages: [DeepSeekAPIMessage]
    let temperature: Double
    let max_tokens: Int
}

private struct DeepSeekAPIMessage: Codable {
    let role: String
    let content: String
}

private struct DeepSeekAPIResponse: Codable {
    let choices: [DeepSeekChoice]
}

private struct DeepSeekChoice: Codable {
    let message: DeepSeekAPIMessage
}

private struct PredictionData: Codable {
    let direction: String
    let confidence: Double
    let predicted_change: Double
    let reasoning: String
}

private struct PortfolioResponseData: Codable {
    let insights: Insights
}

private struct MarketingBriefingResponseData: Codable {
    let overview: String
    let keyDrivers: String
    let highlightsAndActivity: String
    let riskFactors: String
}

private struct Insights: Codable {
    let confidence_score: Double
    let risk_level: String
}

enum DeepSeekError: Error, LocalizedError {
    case noAPIKey
    case invalidResponse
    case networkError(Error)
    case parsingError
    case pessimisticResponse
    
    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "DeepSeek API key not configured"
        case .invalidResponse:
            return "Invalid response from DeepSeek API"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .parsingError:
            return "Failed to parse AI response"
        case .pessimisticResponse:
            return "AI response too pessimistic - retrying with different parameters"
        }
    }
}

