import Foundation

/// Shared portfolio analysis model used across the app.
/// Consolidates previous nested definitions inside DeepSeek managers.
public struct PortfolioAnalysis: Identifiable, Codable, Equatable {
    public let id: UUID
    public let confidenceScore: Double
    public let riskLevel: String

    public init(id: UUID = UUID(), confidenceScore: Double, riskLevel: String) {
        self.id = id
        self.confidenceScore = confidenceScore
        self.riskLevel = riskLevel
    }
}
