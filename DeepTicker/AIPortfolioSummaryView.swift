import SwiftUI

struct AIPortfolioSummaryView: View {
    let confidenceScore: Double
    let riskLevel: String

    private var confidenceText: String {
        String(format: "%.0f%%", confidenceScore * 100)
    }

    private var riskColor: Color {
        switch riskLevel.lowercased() {
        case "low": return .green
        case "medium", "moderate": return .yellow
        case "high": return .red
        default: return .accentColor
        }
    }

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("AI Confidence")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .bold()
                Text(confidenceText)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.primary)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 6) {
                Text("Risk Level")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .bold()
                HStack(spacing: 8) {
                    Circle()
                        .fill(riskColor)
                        .frame(width: 10, height: 10)
                    Text(riskLevel.capitalized)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.primary)
                        .minimumScaleFactor(0.8)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

#Preview {
    VStack(spacing: 16) {
        AIPortfolioSummaryView(confidenceScore: 0.82, riskLevel: "Low")
        AIPortfolioSummaryView(confidenceScore: 0.55, riskLevel: "Medium")
        AIPortfolioSummaryView(confidenceScore: 0.23, riskLevel: "High")
    }
    .padding()
}
