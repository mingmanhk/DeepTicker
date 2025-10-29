import Foundation
import SwiftUI
import Combine

// MARK: - Type Aliases to Resolve Ambiguity
// We are qualifying the model types with the module name `DeepTicker`
// to disambiguate them from the identical, nested types inside DeepSeekManager.
// This ensures we are using the global models as intended.
typealias AppStock = DeepTicker.Stock
typealias AppStockPrediction = DeepTicker.StockPrediction
typealias AppPredictionDirection = DeepTicker.PredictionDirection

// MARK: - DeepSeek AI Manager Extension
// This extends the existing DeepSeekManager with additional functionality
extension DeepSeekManager {
    
    // MARK: - Enhanced Public Methods
    func generateEnhancedStockPrediction(
        for stock: AppStock,
        historicalData: [DeepSeekManager.HistoricalDataPoint]
    ) async throws -> AppStockPrediction {
        
        let prompt = buildEnhancedPredictionPrompt(for: stock, with: historicalData)
        
        let requestBody = EnhancedAPIRequest(
            model: "deepseek-chat",
            messages: [
                EnhancedAPIMessage(role: "system", content: enhancedSystemPrompt),
                EnhancedAPIMessage(role: "user", content: prompt)
            ],
            temperature: 0.3,
            max_tokens: 500
        )
        
        var request = URLRequest(url: URL(string: "https://api.deepseek.com/v1/chat/completions")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer sk-79819a28af4c4d3f8d79253b7a96bf22", forHTTPHeaderField: "Authorization")
        
        do {
            let jsonData = try JSONEncoder().encode(requestBody)
            request.httpBody = jsonData
            
            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode(EnhancedAPIResponse.self, from: data)
            
            guard let firstChoice = response.choices.first else {
                throw EnhancedDeepSeekError.invalidResponse
            }
            
            let content = firstChoice.message.content
            
            return try parseEnhancedPredictionResponse(content: content, symbol: stock.symbol)
            
        } catch {
            throw EnhancedDeepSeekError.networkError(error)
        }
    }
    
    func generateEnhancedPortfolioAnalysis(for stocks: [AppStock]) async throws -> String {
        let prompt = buildEnhancedPortfolioPrompt(for: stocks)
        
        let requestBody = EnhancedAPIRequest(
            model: "deepseek-chat",
            messages: [
                EnhancedAPIMessage(role: "system", content: enhancedPortfolioAnalysisPrompt),
                EnhancedAPIMessage(role: "user", content: prompt)
            ],
            temperature: 0.4,
            max_tokens: 800
        )
        
        var request = URLRequest(url: URL(string: "https://api.deepseek.com/v1/chat/completions")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer sk-79819a28af4c4d3f8d79253b7a96bf22", forHTTPHeaderField: "Authorization")
        
        do {
            let jsonData = try JSONEncoder().encode(requestBody)
            request.httpBody = jsonData
            
            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode(EnhancedAPIResponse.self, from: data)
            
            guard let firstChoice = response.choices.first else {
                throw EnhancedDeepSeekError.invalidResponse
            }
            
            return firstChoice.message.content
            
        } catch {
            throw EnhancedDeepSeekError.networkError(error)
        }
    }
    
    // MARK: - Enhanced Private Methods
    private func buildEnhancedPredictionPrompt(for stock: AppStock, with historicalData: [DeepSeekManager.HistoricalDataPoint]) -> String {
        let recentData = Array(historicalData.suffix(10)) // Last 10 days
        let dataString = recentData.map { point in
            "Date: \(DateFormatter.enhancedShortDate.string(from: point.date)), Close: $\(point.close), Volume: \(point.volume)"
        }.joined(separator: "\n")
        
        return """
        Analyze the following stock data for \(stock.symbol):
        
        Current Information:
        - Symbol: \(stock.symbol)
        - Current Price: $\(stock.currentPrice)
        - Previous Close: $\(stock.previousClose)
        - Today's Change: \(String(format: "%.2f", stock.dailyChangePercentage))%
        
        Recent Historical Data (Last 10 trading days):
        \(dataString)
        
        Please provide a prediction for tomorrow's movement with the following JSON format:
        {
            "direction": "up|down|neutral",
            "confidence": 0.85,
            "predicted_change": 2.5,
            "reasoning": "Brief explanation of analysis"
        }
        """
    }
    
    private func buildEnhancedPortfolioPrompt(for stocks: [AppStock]) -> String {
        let stockSummaries = stocks.map { stock in
            let changeSign = stock.dailyChangePercentage >= 0 ? "+" : ""
            return "\(stock.symbol): $\(stock.currentPrice) (\(changeSign)\(String(format: "%.2f", stock.dailyChangePercentage))%)"
        }.joined(separator: ", ")
        
        return """
        Analyze this portfolio composition and provide insights:
        
        Holdings: \(stockSummaries)
        
        Total Portfolio Value: $\(stocks.reduce(0) { $0 + $1.totalValue })
        
        Please provide a brief portfolio health assessment and any recommendations for diversification or risk management.
        """
    }
    
    private func parseEnhancedPredictionResponse(content: String, symbol: String) throws -> AppStockPrediction {
        // Extract JSON from response
        guard let jsonStart = content.range(of: "{"),
              let jsonEnd = content.range(of: "}", options: .backwards),
              jsonStart.lowerBound < jsonEnd.upperBound else {
            throw EnhancedDeepSeekError.parsingError
        }
        
        let jsonString = String(content[jsonStart.lowerBound...jsonEnd.upperBound])
        
        guard let jsonData = jsonString.data(using: .utf8) else {
            throw EnhancedDeepSeekError.parsingError
        }
        
        do {
            let predictionData = try JSONDecoder().decode(EnhancedPredictionResponseData.self, from: jsonData)
            
            let direction: AppPredictionDirection
            switch predictionData.direction.lowercased() {
            case "up":
                direction = .up
            case "down":
                direction = .down
            default:
                direction = .neutral
            }
            
            return AppStockPrediction(
                stockSymbol: symbol,
                prediction: direction,
                confidence: predictionData.confidence,
                predictedChange: predictionData.predicted_change,
                timestamp: Date(),
                reasoning: predictionData.reasoning
            )
        } catch {
            throw EnhancedDeepSeekError.parsingError
        }
    }
    
    // MARK: - Enhanced Prompts
    private var enhancedSystemPrompt: String {
        return """
        You are a financial analyst AI specialized in short-term stock predictions. 
        Analyze stock data and provide concise predictions with confidence levels.
        Always respond with valid JSON format and keep explanations brief but insightful.
        Focus on technical indicators, volume trends, and recent market behavior.
        """
    }
    
    private var enhancedPortfolioAnalysisPrompt: String {
        return """
        You are a portfolio advisor AI. Analyze the given portfolio composition and provide 
        constructive insights about diversification, risk levels, and potential improvements.
        Keep your analysis concise and actionable.
        """
    }
}

// MARK: - Enhanced API Request/Response Models
private struct EnhancedAPIRequest: Codable {
    let model: String
    let messages: [EnhancedAPIMessage]
    let temperature: Double
    let max_tokens: Int
}

private struct EnhancedAPIMessage: Codable {
    let role: String
    let content: String
}

private struct EnhancedAPIResponse: Codable {
    let choices: [EnhancedAPIChoice]
}

private struct EnhancedAPIChoice: Codable {
    let message: EnhancedAPIMessage
}

private struct EnhancedPredictionResponseData: Codable {
    let direction: String
    let confidence: Double
    let predicted_change: Double
    let reasoning: String
}

// MARK: - Enhanced Error Types
enum EnhancedDeepSeekError: Error, LocalizedError {
    case invalidResponse
    case networkError(Error)
    case parsingError
    case invalidAPIKey
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from DeepSeek AI"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .parsingError:
            return "Failed to parse AI response"
        case .invalidAPIKey:
            return "Invalid DeepSeek API key"
        }
    }
}

// MARK: - Enhanced Extensions
extension DateFormatter {
    static let enhancedShortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM dd"
        return formatter
    }()
}
