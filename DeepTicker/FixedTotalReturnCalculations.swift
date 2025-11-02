// MARK: - Total Return Calculations

/// Total amount invested (purchase price * shares for all holdings)
private var totalInvested: Double {
    UnifiedPortfolioManager.shared.initialValue
}

/// Total return in dollars (current value - total invested)
private var totalReturn: Double {
    UnifiedPortfolioManager.shared.totalCurrentValue - totalInvested
}

/// Total return percentage ((current value - invested) / invested * 100)
private var totalReturnPercentage: Double {
    guard totalInvested > 0 else { return 0 }
    return (totalReturn / totalInvested) * 100
}