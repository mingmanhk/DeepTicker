import SwiftUI

// MARK: - Core Types

/// Represents the trend of a market signal compared to the previous day.
public enum MarketTrend: String, Codable, Sendable {
    case up = "↑"
    case neutral = "→"
    case down = "↓"
}

/// Represents the color code for a given signal, with a convenience for SwiftUI `Color`.
public enum SignalColor: String, Codable, Sendable {
    case red
    case yellow
    case green
    case gray
    
    public var color: Color {
        switch self {
        case .red: return .red
        case .yellow: return .yellow
        case .green: return .green
        case .gray: return .gray
        }
    }
}

// MARK: - Composite Score

/// The main AI Market Signal composite score and its properties.
public struct AIMarketSignalCompositeScore: Codable, Sendable {
    public let value: Double // 0-100
    public let trend: MarketTrend
    
    public var label: String {
        switch value {
        case 0...40: return "Weak Signal"
        case 41...70: return "Moderate Signal"
        default: return "Strong Signal"
        }
    }
    
    public var color: SignalColor {
        switch value {
        case 0...40: return .red
        case 41...70: return .yellow
        default: return .green
        }
    }
    
    public var icon: String {
        switch value {
        case 0...40: return "⚠️"
        case 41...70: return "⚖️"
        default: return "🚀"
        }
    }
}

// MARK: - Individual Metric

/// A model for an individual metric within the AI Market Signal.
public struct MarketSignalMetric: Identifiable, Codable, Sendable {
    public var id = UUID()
    public let type: MetricType
    public let value: Double // The raw value, e.g., percentage
    public let trend: MarketTrend
    
    public enum MetricType: String, CaseIterable, Codable, Sendable {
        case profitLikelihood
        case gainPotential
        case profitConfidence
        case upsideChance
        
        public var name: String {
            switch self {
            case .profitLikelihood: return "Today’s Profit Likelihood"
            case .gainPotential: return "Forecasted Gain Potential"
            case .profitConfidence: return "Profit Confidence Score"
            case .upsideChance: return "Projected Upside Chance"
            }
        }
        
        public var tooltip: String {
            switch self {
            case .profitLikelihood: return "Estimated chance of a positive return today, based on momentum, volume, sentiment, and historical patterns."
            case .gainPotential: return "Projected magnitude of upside movement if the stock performs well."
            case .profitConfidence: return "Model certainty based on clarity and consistency of signals."
            case .upsideChance: return "Probability of upward price movement based on technical and sentiment indicators."
            }
        }
    }
    
    /// Computed property for color based on the value, as per the specification.
    public var color: SignalColor {
        switch type {
        case .profitLikelihood:
            switch value {
            case 0...40: return .red
            case 41...70: return .yellow
            default: return .green // 71-100
            }
        case .gainPotential:
            switch value {
            case 0...1: return .gray
            case 1.1...3: return .yellow
            default: return .green // >3
            }
        case .profitConfidence:
            switch value {
            case 0...50: return .red
            case 51...80: return .yellow
            default: return .green // 81-100
            }
        case .upsideChance:
            switch value {
            case 0...40: return .red
            case 41...70: return .yellow
            default: return .green // 71-100
            }
        }
    }
}

// MARK: - Main AI Market Signal Model

/// The complete AI Market Signal for a stock, including the composite score and underlying metrics.
public struct AIMarketSignal: Identifiable, Codable, Sendable {
    public var id = UUID()
    public let symbol: String
    public let compositeScore: AIMarketSignalCompositeScore
    public let metrics: [MarketSignalMetric]

    /// Calculates a complete `AIMarketSignal` from raw metric values.
    /// - Parameters:
    ///   - symbol: The stock symbol.
    ///   - profitLikelihood: Today’s Profit Likelihood (0-100).
    ///   - gainPotential: Forecasted Gain Potential (e.g., 3.5 for 3.5%).
    ///   - profitConfidence: Profit Confidence Score (0-100).
    ///   - upsideChance: Projected Upside Chance (0-100).
    ///   - previousCompositeScore: The composite score from the previous day, for trend calculation.
    ///   - previousMetrics: A dictionary of previous metric values for trend calculation.
    /// - Returns: A fully calculated `AIMarketSignal`.
    public static func calculate(
        symbol: String,
        profitLikelihood: Double,
        gainPotential: Double,
        profitConfidence: Double,
        upsideChance: Double,
        previousCompositeScore: Double?,
        previousMetrics: [MarketSignalMetric.MetricType: Double]?
    ) -> AIMarketSignal {
        
        let weights: [MarketSignalMetric.MetricType: Double] = [
            .profitLikelihood: 0.35,
            .gainPotential: 0.25,
            .profitConfidence: 0.25,
            .upsideChance: 0.15
        ]
        
        // Normalize gain potential to a 0-100 scale for composite score calculation.
        // We assume a 5% daily gain is a strong potential, mapping it to 100 on our scale.
        let normalizedGainPotential = normalize(gainPotential, from: 0.0, to: 5.0)

        let weightedScore = (profitLikelihood * weights[.profitLikelihood]!) +
                             (normalizedGainPotential * weights[.gainPotential]!) +
                             (profitConfidence * weights[.profitConfidence]!) +
                             (upsideChance * weights[.upsideChance]!)
        
        let finalScore = min(max(weightedScore, 0), 100) // Clamp to 0-100
        
        let compositeTrend = determineTrend(current: finalScore, previous: previousCompositeScore)
        let composite = AIMarketSignalCompositeScore(value: finalScore, trend: compositeTrend)
        
        let metrics: [MarketSignalMetric] = [
            .init(type: .profitLikelihood, value: profitLikelihood, trend: determineTrend(current: profitLikelihood, previous: previousMetrics?[.profitLikelihood])),
            .init(type: .gainPotential, value: gainPotential, trend: determineTrend(current: gainPotential, previous: previousMetrics?[.gainPotential])),
            .init(type: .profitConfidence, value: profitConfidence, trend: determineTrend(current: profitConfidence, previous: previousMetrics?[.profitConfidence])),
            .init(type: .upsideChance, value: upsideChance, trend: determineTrend(current: upsideChance, previous: previousMetrics?[.upsideChance]))
        ]
        
        return AIMarketSignal(symbol: symbol, compositeScore: composite, metrics: metrics)
    }
    
    private static func determineTrend(current: Double, previous: Double?) -> MarketTrend {
        guard let previous = previous else { return .neutral }
        // Use a small tolerance to avoid flagging negligible changes as a trend.
        if current > previous + 0.1 { return .up }
        if current < previous - 0.1 { return .down }
        return .neutral
    }
    
    private static func normalize(_ value: Double, from inputMin: Double, to inputMax: Double) -> Double {
        let clampedValue = min(max(value, inputMin), inputMax)
        let normalized = (clampedValue - inputMin) / (inputMax - inputMin)
        return normalized * 100.0
    }
}
