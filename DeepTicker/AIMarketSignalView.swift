import SwiftUI

struct AIMarketSignalView: View {
    let signal: AIMarketSignal
    @State private var isPulsing: Bool = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Composite Score Display
            VStack {
                Text(signal.compositeScore.icon + " " + signal.compositeScore.label)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(signal.compositeScore.color.color)
                
                Text("\(signal.compositeScore.value, specifier: "%.0f")")
                    .font(.system(size: 72, weight: .bold))
                    .foregroundColor(.primary)
                
                Text("AI Market Signal Score")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(signal.compositeScore.color.color.opacity(0.1))
            .cornerRadius(16)
            .shadow(color: isPulsing ? signal.compositeScore.color.color.opacity(0.5) : .clear, radius: 10, x: 0, y: 0)
            .onAppear {
                if signal.compositeScore.value > 90 {
                    withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                        isPulsing = true
                    }
                }
            }

            // Individual Metrics Grid
            VStack(alignment: .leading, spacing: 16) {
                Text("Key Metrics")
                    .font(.headline)
                
                ForEach(signal.metrics) { metric in
                    MetricRow(metric: metric)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(radius: 5)
    }
}

private struct MetricRow: View {
    let metric: MarketSignalMetric
    
    var body: some View {
        HStack {
            Text(metric.type.name)
                .font(.subheadline)
                .help(metric.type.tooltip) // Tooltip for macOS and iPadOS
            
            Spacer()
            
            Text(metric.trend.rawValue)
                .font(.caption)
                .bold()
                .foregroundColor(trendColor)
            
            Text(formattedValue)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(metric.color.color)
                .frame(minWidth: 60, alignment: .trailing)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(metric.color.color.opacity(0.15))
                .cornerRadius(8)
        }
    }
    
    private var trendColor: Color {
        switch metric.trend {
        case .up: return .green
        case .down: return .red
        case .neutral: return .secondary
        }
    }
    
    private var formattedValue: String {
        switch metric.type {
        case .gainPotential:
            return String(format: "%.1f%%", metric.value)
        default:
            return String(format: "%.0f%%", metric.value)
        }
    }
}


// MARK: - Preview

#Preview {
    let previousMetrics: [MarketSignalMetric.MetricType: Double] = [
        .profitLikelihood: 65,
        .gainPotential: 2.2,
        .profitConfidence: 75,
        .upsideChance: 60
    ]

    let strongSignal = AIMarketSignal.calculate(
        symbol: "AAPL",
        profitLikelihood: 85,
        gainPotential: 3.5,
        profitConfidence: 92,
        upsideChance: 88,
        previousCompositeScore: 70, // Example previous score
        previousMetrics: previousMetrics
    )

    let moderateSignal = AIMarketSignal.calculate(
        symbol: "GOOG",
        profitLikelihood: 60,
        gainPotential: 1.5,
        profitConfidence: 70,
        upsideChance: 65,
        previousCompositeScore: 68,
        previousMetrics: previousMetrics
    )

    ScrollView {
        VStack(spacing: 30) {
            AIMarketSignalView(signal: strongSignal)
            AIMarketSignalView(signal: moderateSignal)
        }
        .padding()
    }
}
