import Foundation

// MARK: - Stock Model
struct PortfolioStock: Identifiable, Codable, Hashable {
    let id: UUID
    let symbol: String
    var name: String
    var currentPrice: Double
    var previousClose: Double
    var shares: Double
    var purchasePrice: Double
    
    // Computed properties
    var dailyChange: Double {
        currentPrice - previousClose
    }
    
    var dailyChangePercentage: Double {
        guard previousClose > 0 else { return 0 }
        return ((currentPrice - previousClose) / previousClose) * 100
    }
    
    var totalValue: Double {
        currentPrice * shares
    }
    
    var totalGainLoss: Double {
        (currentPrice - purchasePrice) * shares
    }
    
    var totalGainLossPercentage: Double {
        guard purchasePrice > 0 else { return 0 }
        return ((currentPrice - purchasePrice) / purchasePrice) * 100
    }
}

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
