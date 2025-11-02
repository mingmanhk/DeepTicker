import Foundation

struct StockInsight: Codable, Identifiable, Hashable {
    var id: String { symbol }
    let symbol: String
    let profitLikelihood: Double
    let expectedReturnProbability: Double
    let forecastedGainPotential: Double
    let confidenceScore: Double
    let projectedUpsideChance: Double
    let summary: String

    enum CodingKeys: String, CodingKey {
        case symbol
        case profitLikelihood = "profit_likelihood"
        case expectedReturnProbability = "expected_return_probability"
        case forecastedGainPotential = "forecasted_gain_potential"
        case confidenceScore = "confidence_score"
        case projectedUpsideChance = "projected_upside_chance"
        case summary
    }
}
