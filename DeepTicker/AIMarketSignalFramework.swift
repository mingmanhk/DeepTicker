import Foundation
import SwiftUI
import Combine

// MARK: - Supporting Data Types

/// Basic Stock data model for AI analysis
struct AIStock: Identifiable, Codable {
    let id = UUID()
    let symbol: String
    let name: String
    let price: Double
    let change: Double
    let changePercent: Double
    
    enum CodingKeys: String, CodingKey {
        case id, symbol, name, price, change, changePercent
    }
}

/// AI Market Signal Framework - Composite scoring system for portfolio analysis
// Note: Using the public AIMarketSignal from AIMarketSignal.swift instead of defining a duplicate struct

enum SignalStrength: String, CaseIterable {
    case weak = "Weak Signal"
    case moderate = "Moderate Signal"
    case strong = "Strong Signal"
    
    var emoji: String {
        switch self {
        case .weak: return "⚠️"
        case .moderate: return "⚖️"
        case .strong: return "🚀"
        }
    }
    
    var color: Color {
        switch self {
        case .weak: return .red
        case .moderate: return .yellow
        case .strong: return .green
        }
    }
    
    var description: String {
        switch self {
        case .weak: return "Low confidence in positive movement"
        case .moderate: return "Mixed signals, proceed with caution"
        case .strong: return "High confidence in favorable outcomes"
        }
    }
}

/// Enhanced AI insight with market signal data
struct EnhancedAIInsight: Codable, Identifiable {
    var id = UUID()
    let symbol: String
    let marketSignal: AIMarketSignalData
    let technicalIndicators: TechnicalIndicators?
    let volumeAnalysis: VolumeAnalysis?
    let sentimentAnalysis: SentimentAnalysis?
    let riskFactors: [String]
    let timestamp: Date
    let provider: AIProvider
    
    enum CodingKeys: String, CodingKey {
        case id, symbol, marketSignal, technicalIndicators, volumeAnalysis, sentimentAnalysis, riskFactors, timestamp, provider
    }
    
    init(id: UUID = UUID(), symbol: String, marketSignal: AIMarketSignalData, technicalIndicators: TechnicalIndicators?, volumeAnalysis: VolumeAnalysis?, sentimentAnalysis: SentimentAnalysis?, riskFactors: [String], timestamp: Date, provider: AIProvider) {
        self.id = id
        self.symbol = symbol
        self.marketSignal = marketSignal
        self.technicalIndicators = technicalIndicators
        self.volumeAnalysis = volumeAnalysis
        self.sentimentAnalysis = sentimentAnalysis
        self.riskFactors = riskFactors
        self.timestamp = timestamp
        self.provider = provider
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.symbol = try container.decode(String.self, forKey: .symbol)
        self.marketSignal = try container.decode(AIMarketSignalData.self, forKey: .marketSignal)
        self.technicalIndicators = try container.decodeIfPresent(TechnicalIndicators.self, forKey: .technicalIndicators)
        self.volumeAnalysis = try container.decodeIfPresent(VolumeAnalysis.self, forKey: .volumeAnalysis)
        self.sentimentAnalysis = try container.decodeIfPresent(SentimentAnalysis.self, forKey: .sentimentAnalysis)
        self.riskFactors = try container.decode([String].self, forKey: .riskFactors)
        self.timestamp = try container.decode(Date.self, forKey: .timestamp)
        self.provider = try container.decode(AIProvider.self, forKey: .provider)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(symbol, forKey: .symbol)
        try container.encode(marketSignal, forKey: .marketSignal)
        try container.encodeIfPresent(technicalIndicators, forKey: .technicalIndicators)
        try container.encodeIfPresent(volumeAnalysis, forKey: .volumeAnalysis)
        try container.encodeIfPresent(sentimentAnalysis, forKey: .sentimentAnalysis)
        try container.encode(riskFactors, forKey: .riskFactors)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(provider, forKey: .provider)
    }
}

struct AIMarketSignalData: Codable {
    let todaysProfitLikelihood: Double
    let forecastedGainPotential: Double
    let profitConfidenceScore: Double
    let projectedUpsideChance: Double
    
    var compositeScore: Double {
        let weights: [Double] = [0.35, 0.25, 0.25, 0.15]
        let scores = [todaysProfitLikelihood, forecastedGainPotential, profitConfidenceScore, projectedUpsideChance]
        
        return zip(weights, scores).reduce(0.0) { result, pair in
            result + (pair.0 * pair.1)
        }
    }
}

struct TechnicalIndicators: Codable {
    let rsi: Double?
    let macd: Double?
    let sma20: Double?
    let sma50: Double?
    let bollingerBands: BollingerBands?
    
    struct BollingerBands: Codable {
        let upper: Double
        let middle: Double
        let lower: Double
        let position: String // "Above", "Below", "Within"
    }
}

struct VolumeAnalysis: Codable {
    let currentVolume: Int
    let averageVolume: Int
    let volumeRatio: Double
    let conviction: String // "High", "Medium", "Low"
    let isHighVolumeSpike: Bool
}

struct SentimentAnalysis: Codable {
    let overallSentiment: String // "Bullish", "Bearish", "Neutral"
    let newsHeadlines: [String]
    let socialBuzz: String // "High", "Medium", "Low"
    let analystRatings: AnalystRatings?
    
    struct AnalystRatings: Codable {
        let buy: Int
        let hold: Int
        let sell: Int
        let averageTarget: Double?
    }
}

// MARK: - Multi-Provider AI Service

@MainActor
class MultiProviderAIService: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var lastUpdateTime: Date?
    
    private let configManager = SecureConfigurationManager.shared
    
    /// Generate insights from all available AI providers
    func generateMultiProviderInsights(for portfolio: [AIStock]) async -> [AIProvider: PortfolioInsights] {
        isLoading = true
        errorMessage = nil
        
        var results: [AIProvider: PortfolioInsights] = [:]
        let availableProviders = configManager.availableAIProviders
        
        await withTaskGroup(of: (AIProvider, PortfolioInsights?).self) { group in
            for provider in availableProviders {
                group.addTask {
                    do {
                        let insights = try await self.generateInsights(for: portfolio, using: provider)
                        return (provider, insights)
                    } catch {
                        print("Failed to get insights from \(await provider.displayName): \(error)")
                        return (provider, nil)
                    }
                }
            }
            
            for await (provider, insights) in group {
                if let insights = insights {
                    results[provider] = insights
                }
            }
        }
        
        lastUpdateTime = Date()
        isLoading = false
        
        return results
    }
    
    /// Generate stock prediction from specific provider
    func generateStockPrediction(for symbol: String, using provider: AIProvider) async throws -> EnhancedAIInsight? {
        guard let apiKey = configManager.getAPIKey(for: provider) else {
            throw AIServiceError.missingAPIKey(provider)
        }
        
        let prompt = configManager.getPromptTemplate(for: .prediction)
        
        switch provider {
        case .deepSeek:
            return try await generateDeepSeekPrediction(symbol: symbol, apiKey: apiKey, prompt: prompt)
        case .openAI:
            return try await generateOpenAIPrediction(symbol: symbol, apiKey: apiKey, prompt: prompt)
        case .openRouter:
            return try await generateOpenRouterPrediction(symbol: symbol, apiKey: apiKey, prompt: prompt)
        case .qwen:
            return try await generateQwenPrediction(symbol: symbol, apiKey: apiKey, prompt: prompt)
        }
    }
    
    // MARK: - Private Implementation
    
    private func generateInsights(for portfolio: [AIStock], using provider: AIProvider) async throws -> PortfolioInsights {
        guard let apiKey = configManager.getAPIKey(for: provider) else {
            throw AIServiceError.missingAPIKey(provider)
        }
        
        switch provider {
        case .deepSeek:
            let profitPrompt = configManager.getPromptTemplate(for: .profitConfidence)
            let riskPrompt = configManager.getPromptTemplate(for: .risk)
            return try await generateDeepSeekInsights(portfolio: portfolio, apiKey: apiKey, profitPrompt: profitPrompt, riskPrompt: riskPrompt)
            
        case .openAI:
            let predictionPrompt = configManager.getPromptTemplate(for: .prediction)
            return try await generateOpenAIInsights(portfolio: portfolio, apiKey: apiKey, prompt: predictionPrompt)
            
        case .qwen:
            let portfolioPrompt = configManager.getPromptTemplate(for: .portfolio)
            return try await generateQwenInsights(portfolio: portfolio, apiKey: apiKey, prompt: portfolioPrompt)
            
        case .openRouter:
            // OpenRouter can use multiple models - we'll use it for diverse analysis
            let portfolioPrompt = configManager.getPromptTemplate(for: .portfolio)
            return try await generateOpenRouterInsights(portfolio: portfolio, apiKey: apiKey, prompt: portfolioPrompt)
        }
    }
    
    // MARK: - Provider-Specific Implementations (Stubs)
    
    private func generateDeepSeekPrediction(symbol: String, apiKey: String, prompt: String) async throws -> EnhancedAIInsight? {
        // Implementation would call DeepSeek API
        // For now, return a mock response
        return EnhancedAIInsight(
            symbol: symbol,
            marketSignal: AIMarketSignalData(
                todaysProfitLikelihood: Double.random(in: 0...100),
                forecastedGainPotential: Double.random(in: 0...100),
                profitConfidenceScore: Double.random(in: 0...100),
                projectedUpsideChance: Double.random(in: 0...100)
            ),
            technicalIndicators: nil,
            volumeAnalysis: nil,
            sentimentAnalysis: nil,
            riskFactors: ["Market volatility", "Sector rotation risk"],
            timestamp: Date(),
            provider: .deepSeek
        )
    }
    
    private func generateDeepSeekInsights(portfolio: [AIStock], apiKey: String, profitPrompt: String, riskPrompt: String) async throws -> PortfolioInsights {
        // Implementation would call DeepSeek API
        return PortfolioInsights(
            provider: .deepSeek,
            confidenceScore: Double.random(in: 0...100),
            riskLevel: ["Low", "Medium", "High"].randomElement() ?? "Medium",
            summary: "DeepSeek analysis of your portfolio",
            keyInsights: ["AI-driven analysis", "Risk assessment", "Profit optimization"],
            timestamp: Date()
        )
    }
    
    private func generateOpenAIPrediction(symbol: String, apiKey: String, prompt: String) async throws -> EnhancedAIInsight? {
        // Implementation would call OpenAI API
        return nil
    }
    
    private func generateOpenRouterPrediction(symbol: String, apiKey: String, prompt: String) async throws -> EnhancedAIInsight? {
        // Implementation would call OpenRouter API
        // For now, return a mock response
        return EnhancedAIInsight(
            symbol: symbol,
            marketSignal: AIMarketSignalData(
                todaysProfitLikelihood: Double.random(in: 0...100),
                forecastedGainPotential: Double.random(in: 0...100),
                profitConfidenceScore: Double.random(in: 0...100),
                projectedUpsideChance: Double.random(in: 0...100)
            ),
            technicalIndicators: nil,
            volumeAnalysis: nil,
            sentimentAnalysis: nil,
            riskFactors: ["Market uncertainty", "Multi-model consensus risk"],
            timestamp: Date(),
            provider: .openRouter
        )
    }
    
    private func generateOpenAIInsights(portfolio: [AIStock], apiKey: String, prompt: String) async throws -> PortfolioInsights {
        // Implementation would call OpenAI API
        return PortfolioInsights(
            provider: .openAI,
            confidenceScore: Double.random(in: 0...100),
            riskLevel: ["Low", "Medium", "High"].randomElement() ?? "Medium",
            summary: "OpenAI analysis of your portfolio",
            keyInsights: ["GPT-powered insights", "Market prediction", "Risk modeling"],
            timestamp: Date()
        )
    }
    
    private func generateQwenPrediction(symbol: String, apiKey: String, prompt: String) async throws -> EnhancedAIInsight? {
        // Implementation would call Qwen API
        return nil
    }
    
    private func generateQwenInsights(portfolio: [AIStock], apiKey: String, prompt: String) async throws -> PortfolioInsights {
        // Implementation would call Qwen API  
        return PortfolioInsights(
            provider: .qwen,
            confidenceScore: Double.random(in: 0...100),
            riskLevel: ["Low", "Medium", "High"].randomElement() ?? "Medium",
            summary: "Qwen market briefing and analysis",
            keyInsights: ["Market overview", "Daily briefing", "Risk factors"],
            timestamp: Date()
        )
    }
    
    private func generateOpenRouterInsights(portfolio: [AIStock], apiKey: String, prompt: String) async throws -> PortfolioInsights {
        // Implementation would call OpenRouter API
        return PortfolioInsights(
            provider: .openRouter,
            confidenceScore: Double.random(in: 0...100),
            riskLevel: ["Low", "Medium", "High"].randomElement() ?? "Medium",
            summary: "OpenRouter multi-model analysis",
            keyInsights: ["Multi-model consensus", "Diverse perspectives", "Ensemble prediction"],
            timestamp: Date()
        )
    }
}

// MARK: - Supporting Types

struct PortfolioInsights {
    let provider: AIProvider
    let confidenceScore: Double
    let riskLevel: String
    let summary: String
    let keyInsights: [String]
    let timestamp: Date
}

enum AIServiceError: LocalizedError {
    case missingAPIKey(AIProvider)
    case invalidResponse
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .missingAPIKey(let provider):
            return "Missing API key for \(provider.displayName)"
        case .invalidResponse:
            return "Invalid response from AI service"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}
