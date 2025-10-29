import SwiftUI

struct AddStockView: View {
    @EnvironmentObject var portfolioStore: PortfolioStore
    @Environment(\.dismiss) private var dismiss
    
    @State private var searchText = ""
    @State private var selectedStock: StockSearchResult?
    @State private var shares = ""
    @State private var purchasePrice = ""
    @State private var searchResults: [StockSearchResult] = []
    @State private var isSearching = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    private let alphaVantageService = AlphaVantageService()
    
    var body: some View {
        NavigationView {
            Form {
                Section("Search Stocks") {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        
                        TextField("Enter stock symbol or company name", text: $searchText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .onSubmit {
                                searchStocks()
                            }
                    }
                    
                    if isSearching {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Searching...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 8)
                    }
                    
                    if !searchResults.isEmpty {
                        ForEach(searchResults) { result in
                            StockSearchRowView(result: result, isSelected: selectedStock?.symbol == result.symbol)
                                .onTapGesture {
                                    selectedStock = result
                                    searchText = result.symbol
                                    searchResults = []
                                }
                        }
                    }
                }
                
                if selectedStock != nil {
                    Section("Stock Details") {
                        HStack {
                            Text("Symbol:")
                            Spacer()
                            Text(selectedStock?.symbol ?? "")
                                .fontWeight(.semibold)
                        }
                        
                        HStack {
                            Text("Company:")
                            Spacer()
                            Text(selectedStock?.name ?? "")
                                .multilineTextAlignment(.trailing)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("Shares:")
                            Spacer()
                            TextField("0", text: $shares)
                                .keyboardType(.decimalPad)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .frame(width: 100)
                        }
                        
                        HStack {
                            Text("Purchase Price:")
                            Spacer()
                            HStack {
                                Text("$")
                                TextField("0.00", text: $purchasePrice)
                                    .keyboardType(.decimalPad)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .frame(width: 80)
                            }
                        }
                    }
                    
                    Section {
                        Button(action: addStock) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Add to Portfolio")
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(10)
                        }
                        .listRowBackground(Color.clear)
                        .disabled(selectedStock == nil || shares.isEmpty || purchasePrice.isEmpty)
                    }
                }
                
                if selectedStock == nil && searchResults.isEmpty && !searchText.isEmpty {
                    Section {
                        Button("Add \(searchText.uppercased()) manually") {
                            addManualStock()
                        }
                        .foregroundColor(.blue)
                    }
                }
            }
            .navigationTitle("Add Stock")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $showingAlert) {
                Button("OK") { }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    private func searchStocks() {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        isSearching = true
        searchResults = []
        
        Task {
            do {
                let results = try await alphaVantageService.searchSymbol(searchText)
                await MainActor.run {
                    searchResults = Array(results.prefix(5)) // Limit to 5 results
                    isSearching = false
                }
            } catch {
                await MainActor.run {
                    isSearching = false
                    alertMessage = error.localizedDescription
                    showingAlert = true
                }
            }
        }
    }
    
    private func addStock() {
        guard let selectedStock = selectedStock,
              let sharesDouble = Double(shares),
              let priceDouble = Double(purchasePrice) else {
            alertMessage = "Please enter valid numbers for shares and purchase price."
            showingAlert = true
            return
        }
        
        Task {
            do {
                // Fetch current price from Alpha Vantage
                let stockData = try await alphaVantageService.fetchStockPrice(symbol: selectedStock.symbol)
                
                await MainActor.run {
                    portfolioStore.add(
                        symbol: selectedStock.symbol,
                        name: selectedStock.name,
                        quantity: sharesDouble,
                        purchasePrice: priceDouble,
                        currentPrice: stockData.currentPrice,
                        previousClose: stockData.previousClose
                    )
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    alertMessage = "Failed to fetch current price: \(error.localizedDescription)"
                    showingAlert = true
                }
            }
        }
    }
    
    private func addManualStock() {
        selectedStock = StockSearchResult(
            symbol: searchText.uppercased(),
            name: searchText.uppercased(),
            type: "Equity",
            region: "United States",
            currency: "USD"
        )
    }
}

struct StockSearchRowView: View {
    let result: StockSearchResult
    let isSelected: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(result.symbol)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                }
            }
            
            Text(result.name)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
            
            HStack {
                Text(result.type)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(4)
                
                Text(result.region)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct AddStockView_Previews: PreviewProvider {
    static var previews: some View {
        AddStockView()
            .environmentObject(PortfolioStore.preview)
    }
}
