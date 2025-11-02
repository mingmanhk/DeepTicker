import Foundation

// MARK: - Stock Health Status
enum StockHealthStatus: CaseIterable {
    case stable
    case warning
    case danger
    
    var color: String {
        switch self {
        case .stable: return "green"
        case .warning: return "orange"
        case .danger: return "red"
        }
    }
    
    var emoji: String {
        switch self {
        case .stable: return "🟢"
        case .warning: return "🟠"
        case .danger: return "🔴"
        }
    }
}

// MARK: - Portfolio Performance
struct PortfolioPerformance {
    let totalValue: Double
    let totalGainLoss: Double
    let totalGainLossPercentage: Double
    let dailyChange: Double
    let dailyChangePercentage: Double
}
