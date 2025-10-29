import Combine
import Foundation

public struct SymbolPrediction {
    public let profitLikelihood: Double?
    public let forecastedGain: Double?
    public let confidence: Double?
    public let upside: Double?
    public let factors: [String]
}

@MainActor
class AINewsProvider: ObservableObject {
    @Published var aiSummary: AISummary? = nil
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var lastSummaryUpdate: Date?

    private let summaryCacheKey = "AINewsProvider.summaryCache"
    private let summaryTimestampKey = "AINewsProvider.summaryTimestamp"

    init() {
        // Load from cache on initialization to provide data immediately
        loadSummaryFromCache()
    }

    func refreshInsights(for portfolio: PortfolioStore) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        
        guard !portfolio.items.isEmpty else {
            aiSummary = nil
            lastSummaryUpdate = nil
            clearSummaryCache() // Clear cache if portfolio becomes empty
            return
        }

        // Map PortfolioStore.StockItem to DeepSeekManager.Stock
        let stocks: [DeepSeekManager.Stock] = portfolio.items.map { item in
            DeepSeekManager.Stock(
                symbol: item.symbol,
                currentPrice: item.currentPrice ?? 0,
                previousClose: item.previousClose ?? (item.currentPrice ?? 0),
                quantity: item.quantity
            )
        }

        do {
            let analysis = try await DeepSeekManager.shared.generatePortfolioAnalysis(for: stocks)
            
            // On success, update summary, timestamp, and save to cache
            self.aiSummary = AISummary(confidenceScore: analysis.confidenceScore, riskLevel: analysis.riskLevel)
            self.lastSummaryUpdate = Date()
            saveSummaryToCache()
        } catch {
            // On failure, set an error message. The view will show this error,
            // while the stale data from the cache remains visible.
            self.errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func prediction(for symbol: String) async throws -> SymbolPrediction? {
        // TODO: Replace this with a real implementation that calls DeepSeekManager.
        // This is a placeholder to resolve compiler errors. For example:
        // return try await DeepSeekManager.shared.generateSymbolPrediction(for: symbol)

        // Returning mock data for now.
        return SymbolPrediction(
            profitLikelihood: Double.random(in: 40...95),
            forecastedGain: Double.random(in: -2...8),
            confidence: Double.random(in: 60...98),
            upside: Double.random(in: 10...75),
            factors: [
                "Based on recent market trends.",
                "Upcoming product announcement could be a catalyst.",
                "Analyst ratings have been positive."
            ]
        )
    }

    // MARK: - Caching
    private func saveSummaryToCache() {
        guard let summary = aiSummary else { return }
        do {
            let data = try JSONEncoder().encode(summary)
            UserDefaults.standard.set(data, forKey: summaryCacheKey)
            UserDefaults.standard.set(Date(), forKey: summaryTimestampKey)
        } catch {
            print("Failed to save AI summary to cache: \(error)")
        }
    }

    private func loadSummaryFromCache() {
        guard let data = UserDefaults.standard.data(forKey: summaryCacheKey),
              let summary = try? JSONDecoder().decode(AISummary.self, from: data) else {
            return
        }
        self.aiSummary = summary
        self.lastSummaryUpdate = UserDefaults.standard.object(forKey: summaryTimestampKey) as? Date
    }

    private func clearSummaryCache() {
        UserDefaults.standard.removeObject(forKey: summaryCacheKey)
        UserDefaults.standard.removeObject(forKey: summaryTimestampKey)
    }
}
