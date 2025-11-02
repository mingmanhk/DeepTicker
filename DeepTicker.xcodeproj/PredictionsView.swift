import SwiftUI

struct PredictionsView: View {
    @EnvironmentObject var portfolioManager: PortfolioManager
    @State private var selectedStock: Stock?
    @State private var showingAnalysisSheet = false
    @State private var portfolioAnalysis = ""
    @State private var isLoadingAnalysis = false
    
    var body: some View {
        NavigationView {
            VStack {
                if portfolioManager.stocks.isEmpty {
                    emptyStateView
                } else {
                    predictionsList
                }
            }
            .navigationTitle("AI Predictions")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Generate All Predictions") {
                            Task {
                                await portfolioManager.generateAllPredictions()
                            }
                        }
                        
                        Button("Portfolio Analysis") {
                            generatePortfolioAnalysis()
                        }
                        
                    } label: {
                        Image(systemName: "brain.head.profile")
                            .foregroundColor(.blue)
                    }
                }
            }
            .sheet(isPresented: $showingAnalysisSheet) {
                portfolioAnalysisSheet
            }
        }
    }
    
    // MARK: - Views
    private var predictionsList: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(portfolioManager.stocks) { stock in
                    PredictionCardView(
                        stock: stock,
                        prediction: portfolioManager.predictions[stock.symbol]
                    ) {
                        Task {
                            await portfolioManager.generatePrediction(for: stock)
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
        .refreshable {
            await portfolioManager.generateAllPredictions()
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Predictions Yet")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Add stocks to your portfolio to get AI-powered predictions")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
        }
        .padding()
    }
    
    private var portfolioAnalysisSheet: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Portfolio Analysis")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    if isLoadingAnalysis {
                        HStack {
                            ProgressView()
                            Text("Analyzing your portfolio...")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    } else if portfolioAnalysis.isEmpty {
                        Text("No analysis available")
                            .foregroundColor(.secondary)
                    } else {
                        Text(portfolioAnalysis)
                            .lineLimit(nil)
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showingAnalysisSheet = false
                    }
                }
            }
        }
    }
    
    // MARK: - Private Methods
    private func generatePortfolioAnalysis() {
        guard !portfolioManager.stocks.isEmpty else { return }
        
        isLoadingAnalysis = true
        showingAnalysisSheet = true
        
        Task {
            do {
                let analysis = try await DeepSeekManager.shared.generatePortfolioAnalysis(for: portfolioManager.stocks)
                await MainActor.run {
                    portfolioAnalysis = analysis
                    isLoadingAnalysis = false
                }
            } catch {
                await MainActor.run {
                    portfolioAnalysis = "Failed to generate analysis: \(error.localizedDescription)"
                    isLoadingAnalysis = false
                }
            }
        }
    }
}

// MARK: - Prediction Card View
struct PredictionCardView: View {
    let stock: Stock
    let prediction: StockPrediction?
    let onRefresh: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading) {
                    Text(stock.symbol)
                        .font(.headline)
                        .fontWeight(.bold)
                    
                    Text("$\(stock.currentPrice, specifier: "%.2f")")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: onRefresh) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.blue)
                }
                .buttonStyle(BorderlessButtonStyle())
            }
            
            if let prediction = prediction {
                predictionContent(prediction)
            } else {
                noPredictionContent
            }
        }
        .padding()
        .background(cardBackgroundColor)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(predictionBorderColor, lineWidth: 2)
        )
    }
    
    private func predictionContent(_ prediction: StockPrediction) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Prediction direction and confidence
            HStack {
                directionIndicator(prediction.predictedDirection)
                
                Spacer()
                
                confidenceIndicator(prediction.confidence)
            }
            
            // Predicted change
            if abs(prediction.predictedChange) > 0.1 {
                HStack {
                    Text("Predicted Change:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("\(prediction.predictedChange >= 0 ? "+" : "")\(prediction.predictedChange, specifier: "%.2f")%")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(prediction.predictedChange >= 0 ? .green : .red)
                }
            }
            
            // Reasoning
            VStack(alignment: .leading, spacing: 4) {
                Text("AI Analysis:")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                
                Text(prediction.reasoning)
                    .font(.body)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            // Timestamp
            HStack {
                Spacer()
                Text("Updated \(formatRelativeTime(prediction.timestamp))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var noPredictionContent: some View {
        VStack {
            Image(systemName: "brain")
                .font(.title2)
                .foregroundColor(.gray)
            
            Text("No prediction available")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text("Tap refresh to generate AI prediction")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical)
    }
    
    private func directionIndicator(_ direction: PredictionDirection) -> some View {
        HStack(spacing: 8) {
            Image(systemName: directionIcon(direction))
                .font(.title3)
                .foregroundColor(directionColor(direction))
            
            Text(direction.rawValue.capitalized)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(directionColor(direction))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(directionColor(direction).opacity(0.1))
        .cornerRadius(8)
    }
    
    private func confidenceIndicator(_ confidence: Double) -> some View {
        VStack(alignment: .trailing) {
            Text("\(Int(confidence * 100))%")
                .font(.headline)
                .fontWeight(.bold)
            
            Text("Confidence")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Helper Methods
    private func directionIcon(_ direction: PredictionDirection) -> String {
        switch direction {
        case .up:
            return "arrow.up.right"
        case .down:
            return "arrow.down.right"
        case .neutral:
            return "arrow.right"
        }
    }
    
    private func directionColor(_ direction: PredictionDirection) -> Color {
        switch direction {
        case .up:
            return .green
        case .down:
            return .red
        case .neutral:
            return .gray
        }
    }
    
    private var cardBackgroundColor: Color {
        if let prediction = prediction {
            switch prediction.predictedDirection {
            case .up:
                return Color.green.opacity(0.05)
            case .down:
                return Color.red.opacity(0.05)
            case .neutral:
                return Color(.systemGray6)
            }
        }
        return Color(.systemGray6)
    }
    
    private var predictionBorderColor: Color {
        if let prediction = prediction {
            return directionColor(prediction.predictedDirection).opacity(0.3)
        }
        return Color.clear
    }
    
    private func formatRelativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

#Preview {
    PredictionsView()
        .environmentObject(PortfolioManager())
}