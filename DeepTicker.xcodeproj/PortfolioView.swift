import SwiftUI

struct PortfolioView: View {
    @EnvironmentObject var portfolioManager: PortfolioManager
    @State private var showingAddStock = false
    @State private var newSymbol = ""
    @State private var newShares = ""
    
    var body: some View {
        NavigationView {
            VStack {
                // Portfolio Summary Card
                portfolioSummaryCard
                
                // Stocks List
                if portfolioManager.stocks.isEmpty {
                    emptyStateView
                } else {
                    stocksList
                }
                
                Spacer()
            }
            .navigationTitle("Portfolio")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        Button(action: {
                            Task {
                                await portfolioManager.refreshAllStocks()
                            }
                        }) {
                            Image(systemName: "arrow.clockwise")
                                .foregroundColor(.blue)
                        }
                        .disabled(portfolioManager.isLoading)
                        
                        Button(action: {
                            showingAddStock = true
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            .refreshable {
                await portfolioManager.refreshAllStocks()
                await portfolioManager.generateAllPredictions()
            }
            .sheet(isPresented: $showingAddStock) {
                addStockSheet
            }
        }
    }
    
    // MARK: - Views
    private var portfolioSummaryCard: some View {
        let stats = portfolioManager.getPortfolioStats()
        
        return VStack {
            HStack {
                VStack(alignment: .leading) {
                    Text("Total Value")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("$\(stats.totalValue, specifier: "%.2f")")
                        .font(.title2)
                        .fontWeight(.bold)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("Today")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    HStack {
                        Text("$\(stats.dailyChange, specifier: "%.2f")")
                        Text("(\(stats.dailyChangePercent >= 0 ? "+" : "")\(stats.dailyChangePercent, specifier: "%.2f")%)")
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(stats.dailyChange >= 0 ? .green : .red)
                }
            }
            
            Divider()
            
            HStack {
                healthIndicator(
                    count: stats.healthyCount,
                    color: .green,
                    icon: "checkmark.circle.fill",
                    label: "Healthy"
                )
                
                Spacer()
                
                healthIndicator(
                    count: stats.warningCount,
                    color: .orange,
                    icon: "exclamationmark.triangle.fill",
                    label: "Warning"
                )
                
                Spacer()
                
                healthIndicator(
                    count: stats.dangerCount,
                    color: .red,
                    icon: "xmark.circle.fill",
                    label: "Danger"
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    private func healthIndicator(count: Int, color: Color, icon: String, label: String) -> some View {
        VStack {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text("\(count)")
                    .fontWeight(.bold)
            }
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var stocksList: some View {
        List {
            ForEach(portfolioManager.stocks.indices, id: \.self) { index in
                StockRowView(
                    stock: portfolioManager.stocks[index],
                    prediction: portfolioManager.predictions[portfolioManager.stocks[index].symbol]
                )
                .listRowBackground(Color(.systemGray6))
            }
            .onDelete { indexSet in
                for index in indexSet {
                    portfolioManager.removeStock(at: index)
                }
            }
        }
        .listStyle(PlainListStyle())
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Stocks Yet")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Add your first stock to start tracking your portfolio")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            Button("Add Stock") {
                showingAddStock = true
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
    
    private var addStockSheet: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Add New Stock")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Stock Symbol")
                        .font(.headline)
                    TextField("e.g., AAPL", text: $newSymbol)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.allCharacters)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Number of Shares (Optional)")
                        .font(.headline)
                    TextField("e.g., 10", text: $newShares)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.decimalPad)
                }
                
                Spacer()
                
                if portfolioManager.isLoading {
                    ProgressView("Adding stock...")
                } else {
                    Button("Add Stock") {
                        Task {
                            let shares = Double(newShares) ?? 0
                            await portfolioManager.addStock(newSymbol, shares: shares)
                            
                            if portfolioManager.errorMessage == nil {
                                showingAddStock = false
                                newSymbol = ""
                                newShares = ""
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(newSymbol.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                
                if let errorMessage = portfolioManager.errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        showingAddStock = false
                        newSymbol = ""
                        newShares = ""
                    }
                }
            }
        }
    }
}

// MARK: - Stock Row View
struct StockRowView: View {
    let stock: Stock
    let prediction: StockPrediction?
    
    var body: some View {
        HStack {
            // Health status indicator
            Circle()
                .fill(healthStatusColor)
                .frame(width: 12, height: 12)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(stock.symbol)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    if let prediction = prediction {
                        predictionIndicator(prediction)
                    }
                }
                
                if stock.shares > 0 {
                    Text("\(stock.shares, specifier: "%.2f") shares")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("$\(stock.currentPrice, specifier: "%.2f")")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                HStack {
                    Text("\(stock.changePercent >= 0 ? "+" : "")\(stock.changePercent, specifier: "%.2f")%")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(stock.changePercent >= 0 ? .green : .red)
                    
                    Image(systemName: stock.changePercent >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.caption)
                        .foregroundColor(stock.changePercent >= 0 ? .green : .red)
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
    
    private var healthStatusColor: Color {
        switch stock.healthStatus {
        case .healthy:
            return .green
        case .warning:
            return .orange
        case .danger:
            return .red
        }
    }
    
    private func predictionIndicator(_ prediction: StockPrediction) -> some View {
        HStack(spacing: 2) {
            Image(systemName: prediction.predictedDirection == .up ? "arrow.up" : 
                            prediction.predictedDirection == .down ? "arrow.down" : "minus")
                .font(.caption)
                .foregroundColor(prediction.predictedDirection == .up ? .green : 
                               prediction.predictedDirection == .down ? .red : .gray)
            
            Text("\(Int(prediction.confidence * 100))%")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 1)
        .background(Color(.systemGray5))
        .cornerRadius(4)
    }
}

#Preview {
    PortfolioView()
        .environmentObject(PortfolioManager())
}