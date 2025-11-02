import SwiftUI

struct StockDetailSheet: View {
    let stock: PortfolioStock
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var dataManager: DataManager
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header section
                    headerSection
                    
                    // Price section
                    priceSection
                    
                    // Holdings section
                    holdingsSection
                    
                    // Performance section
                    performanceSection
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle(stock.symbol)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Text(stock.symbol)
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundStyle(.primary)
            
            // You could add company name here if available
            Text("Stock Details")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical)
    }
    
    private var priceSection: some View {
        VStack(spacing: 16) {
            Text("Current Price")
                .font(.headline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack {
                VStack(alignment: .leading) {
                    Text("$\(stock.currentPrice, specifier: "%.2f")")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                    
                    let dailyChange = stock.currentPrice - stock.previousClose
                    let dailyChangePercent = stock.previousClose > 0 ? (dailyChange / stock.previousClose) * 100 : 0
                    
                    HStack(spacing: 8) {
                        Image(systemName: dailyChange >= 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.caption)
                            .fontWeight(.semibold)
                        
                        Text("$\(dailyChange, specifier: "%.2f")")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Text("(\(dailyChangePercent, specifier: "%.2f")%)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(dailyChange >= 0 ? .green : .red)
                }
                
                Spacer()
            }
        }
        .padding()
        .background(.regularMaterial)
        .cornerRadius(12)
    }
    
    private var holdingsSection: some View {
        VStack(spacing: 16) {
            Text("Your Holdings")
                .font(.headline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 12) {
                HStack {
                    Text("Shares Owned")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(stock.quantity, specifier: "%.2f")")
                        .fontWeight(.semibold)
                }
                
                Divider()
                
                HStack {
                    Text("Total Value")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("$\(stock.currentPrice * stock.quantity, specifier: "%.2f")")
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                }
            }
        }
        .padding()
        .background(.regularMaterial)
        .cornerRadius(12)
    }
    
    private var performanceSection: some View {
        VStack(spacing: 16) {
            Text("Performance")
                .font(.headline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 12) {
                HStack {
                    Text("Previous Close")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("$\(stock.previousClose, specifier: "%.2f")")
                        .fontWeight(.medium)
                }
                
                Divider()
                
                let dailyChange = stock.currentPrice - stock.previousClose
                HStack {
                    Text("Daily Change")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("$\(dailyChange, specifier: "%.2f")")
                        .fontWeight(.semibold)
                        .foregroundStyle(dailyChange >= 0 ? .green : .red)
                }
                
                let dailyChangePercent = stock.previousClose > 0 ? (dailyChange / stock.previousClose) * 100 : 0
                HStack {
                    Text("Daily Change %")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(dailyChangePercent, specifier: "%.2f")%")
                        .fontWeight(.semibold)
                        .foregroundStyle(dailyChange >= 0 ? .green : .red)
                }
            }
        }
        .padding()
        .background(.regularMaterial)
        .cornerRadius(12)
    }
}



#Preview {
    StockDetailSheet(stock: PortfolioStock(
        symbol: "AAPL",
        currentPrice: 150.25,
        previousClose: 148.50,
        quantity: 10.0
    ))
    .environmentObject(DataManager.shared)
}