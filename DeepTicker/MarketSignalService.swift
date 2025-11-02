import Foundation

/// A protocol for services that can fetch AI Market Signal data.
public protocol MarketSignalProviding: Sendable {
    /// Fetches the AI Market Signal for a given stock symbol.
    /// - Parameter symbol: The stock symbol (e.g., "AAPL").
    /// - Returns: An `AIMarketSignal` object.
    /// - Throws: An error if the data could not be fetched.
    func fetchMarketSignal(for symbol: String) async throws -> AIMarketSignal
}

/// A mock implementation of `MarketSignalProviding` that generates random sample data.
///
/// Use this for developing and testing your UI without needing a live backend.
public final class MockMarketSignalService: MarketSignalProviding {
    public init() {}
    
    public func fetchMarketSignal(for symbol: String) async throws -> AIMarketSignal {
        // Simulate network delay to mimic a real API call.
        try await Task.sleep(for: .milliseconds(Int.random(in: 500...1500)))
        
        // Generate random data for demonstration purposes.
        let profitLikelihood = Double.random(in: 30...95)
        let gainPotential = Double.random(in: 0.5...5.0)
        let profitConfidence = Double.random(in: 40...98)
        let upsideChance = Double.random(in: 35...90)
        
        // Generate a random previous score to demonstrate trend arrows.
        let previousCompositeScore = Double.random(in: 40...80)
        
        // Generate random previous metrics to show individual trends.
        let previousMetrics: [MarketSignalMetric.MetricType: Double] = [
            .profitLikelihood: profitLikelihood * Double.random(in: 0.95...1.05),
            .gainPotential: gainPotential * Double.random(in: 0.95...1.05),
            .profitConfidence: profitConfidence * Double.random(in: 0.95...1.05),
            .upsideChance: upsideChance * Double.random(in: 0.95...1.05)
        ]
        
        return AIMarketSignal.calculate(
            symbol: symbol.uppercased(),
            profitLikelihood: profitLikelihood,
            gainPotential: gainPotential,
            profitConfidence: profitConfidence,
            upsideChance: upsideChance,
            previousCompositeScore: previousCompositeScore,
            previousMetrics: previousMetrics
        )
    }
}
