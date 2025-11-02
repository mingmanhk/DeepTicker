import SwiftUI
import Combine

struct StockRowView: View {
    let stock: PortfolioStock
    let health: StockHealthStatus
    @EnvironmentObject var portfolioManager: PortfolioManager
    
    var body: some View {
        HStack(spacing: 12) {
            // Health indicator
            healthIndicator
            
            // Stock info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(stock.symbol)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    if let prediction = portfolioManager.predictions[stock.symbol] {
                        predictionBadge(prediction)
                    }
                }
                
                Text(stock.symbol)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Price and change info
            VStack(alignment: .trailing, spacing: 4) {
                Text(formatCurrency(stock.currentPrice))
                    .font(.headline)
                    .fontWeight(.medium)
                
                HStack(spacing: 4) {
                    Image(systemName: stock.dailyChange >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.caption)
                    Text(formatPercentage(stock.dailyChangePercentage))
                        .font(.caption)
                }
                .foregroundColor(stock.dailyChange >= 0 ? .green : .red)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .background(cardBackground)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    private var healthIndicator: some View {
        ZStack {
            Circle()
                .fill(healthColor.opacity(0.2))
                .frame(width: 40, height: 40)
            
            Circle()
                .fill(healthColor)
                .frame(width: 12, height: 12)
                .scaleEffect(health == .danger ? 1.2 : 1.0)
                .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: health == .danger)
        }
    }
    
    private var healthColor: Color {
        switch health {
        case .stable:
            return .green
        case .warning:
            return .orange
        case .danger:
            return .red
        }
    }
    
    private var cardBackground: Color {
        switch health {
        case .stable:
            return Color(UIColor.systemBackground)
        case .warning:
            return Color.orange.opacity(0.05)
        case .danger:
            return Color.red.opacity(0.05)
        }
    }
    
    private func predictionBadge(_ prediction: StockPrediction) -> some View {
        HStack(spacing: 2) {
            Text(prediction.prediction.emoji)
                .font(.caption2)
            Text("\(Int(prediction.confidence * 100))%")
                .font(.caption2)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(predictionBackgroundColor(prediction))
        .cornerRadius(8)
        .foregroundColor(.white)
    }
    
    private func predictionBackgroundColor(_ prediction: StockPrediction) -> Color {
        switch prediction.prediction {
        case .up:
            return .green.opacity(0.8)
        case .down:
            return .red.opacity(0.8)
        case .neutral:
            return .gray.opacity(0.8)
        }
    }
    
    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? "$0.00"
    }
    
    private func formatPercentage(_ value: Double) -> String {
        return String(format: "%.2f%%", value)
    }
}

struct StockRowView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 10) {
            StockRowView(
                stock: PortfolioStock(
                    symbol: "AAPL",
                    currentPrice: 175.50,
                    previousClose: 173.25,
                    quantity: 10
                ),
                health: StockHealthStatus.stable
            )
            
            StockRowView(
                stock: PortfolioStock(
                    symbol: "TSLA",
                    currentPrice: 245.30,
                    previousClose: 255.00,
                    quantity: 5
                ),
                health: StockHealthStatus.warning
            )
            
            StockRowView(
                stock: PortfolioStock(
                    symbol: "NVDA",
                    currentPrice: 420.75,
                    previousClose: 450.25,
                    quantity: 3
                ),
                health: StockHealthStatus.danger
            )
        }
        .padding()
        .environmentObject(PortfolioManager())
        .previewLayout(.sizeThatFits)
    }
}
