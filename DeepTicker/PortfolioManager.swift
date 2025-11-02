import Foundation
import Combine

@MainActor
class PortfolioManager: ObservableObject {
    @Published var stocks: [PortfolioStock] = []
    @Published var predictions: [String: StockPrediction] = [:]
    @Published var isLoading: Bool = false

    private var cancellables = Set<AnyCancellable>()

    init() {
        // Load mock data for previews and initial development
        self.stocks = mockStocks
        self.predictions = mockPredictions
    }

    // You can add methods to fetch real data here
    // For example:
    // func fetchPortfolio() async { ... }
    // func fetchPredictions() async { ... }
}

// MARK: - Mock Data
private extension PortfolioManager {
    var mockStocks: [PortfolioStock] {
        [
            PortfolioStock(
                symbol: "AAPL",
                currentPrice: 175.50,
                previousClose: 173.25,
                quantity: 10
            ),
            PortfolioStock(
                symbol: "TSLA",
                currentPrice: 245.30,
                previousClose: 255.00,
                quantity: 5
            ),
            PortfolioStock(
                symbol: "NVDA",
                currentPrice: 420.75,
                previousClose: 450.25,
                quantity: 3
            )
        ]
    }

    var mockPredictions: [String: StockPrediction] {
        [
            "AAPL": StockPrediction(
                stockSymbol: "AAPL",
                prediction: .up,
                confidence: 0.85,
                predictedChange: 2.5,
                timestamp: Date(),
                reasoning: "Positive market sentiment and upcoming product releases."
            ),
            "TSLA": StockPrediction(
                stockSymbol: "TSLA",
                prediction: .down,
                confidence: 0.70,
                predictedChange: -5.0,
                timestamp: Date(),
                reasoning: "Increased competition and recent production concerns."
            )
        ]
    }
}
