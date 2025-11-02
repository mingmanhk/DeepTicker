import SwiftUI

struct EditStockView: View {
    @EnvironmentObject var portfolioManager: UnifiedPortfolioManager
    @Environment(\.dismiss) private var dismiss
    
    let stock: StockItem
    let index: Int
    
    @State private var shares: String
    @State private var purchasePrice: String
    @State private var showingRemoveAlert = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    init(stock: StockItem, index: Int) {
        self.stock = stock
        self.index = index
        _shares = State(initialValue: String(stock.quantity))
        _purchasePrice = State(initialValue: stock.purchasePrice != nil ? String(stock.purchasePrice!) : "")
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Stock Information") {
                    HStack {
                        Text("Symbol:")
                        Spacer()
                        Text(stock.symbol)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                    }
                    
                    if let name = stock.name {
                        HStack {
                            Text("Company:")
                            Spacer()
                            Text(name)
                                .multilineTextAlignment(.trailing)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if let currentPrice = stock.currentPrice {
                        HStack {
                            Text("Current Price:")
                            Spacer()
                            Text(String(format: "$%.2f", currentPrice))
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                        }
                    }
                    
                    HStack {
                        Text("Total Value:")
                        Spacer()
                        Text(String(format: "$%.2f", stock.totalValue))
                            .fontWeight(.semibold)
                            .foregroundColor(.green)
                    }
                }
                
                Section("Edit Holdings") {
                    HStack {
                        Text("Shares:")
                        Spacer()
                        TextField("0", text: $shares)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 100)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    HStack {
                        Text("Purchase Price:")
                        Spacer()
                        HStack(spacing: 4) {
                            Text("$")
                                .foregroundColor(.secondary)
                            TextField("0.00", text: $purchasePrice)
                                .keyboardType(.decimalPad)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .frame(width: 80)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                    
                    if let purchasePriceValue = Double(purchasePrice),
                       let currentPrice = stock.currentPrice,
                       let sharesValue = Double(shares),
                       purchasePriceValue > 0, sharesValue > 0 {
                        let totalInvested = purchasePriceValue * sharesValue
                        let currentValue = currentPrice * sharesValue
                        let gain = currentValue - totalInvested
                        let gainPercent = (gain / totalInvested) * 100
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Total Invested:")
                                Spacer()
                                Text(String(format: "$%.2f", totalInvested))
                                    .fontWeight(.medium)
                            }
                            
                            HStack {
                                Text("Gain/Loss:")
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(String(format: "$%.2f", gain))
                                        .fontWeight(.semibold)
                                        .foregroundColor(gain >= 0 ? .green : .red)
                                    Text(String(format: "(%.1f%%)", gainPercent))
                                        .font(.caption)
                                        .foregroundColor(gain >= 0 ? .green : .red)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                Section("Actions") {
                    Button(action: saveChanges) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Save Changes")
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                    }
                    .listRowBackground(Color.clear)
                    .disabled(shares.isEmpty || (Double(shares) ?? 0) <= 0)
                    
                    Button(action: {
                        showingRemoveAlert = true
                    }) {
                        HStack {
                            Image(systemName: "trash.circle.fill")
                            Text("Remove from Portfolio")
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .cornerRadius(10)
                    }
                    .listRowBackground(Color.clear)
                }
            }
            .navigationTitle("Edit Stock")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveChanges()
                    }
                    .disabled(shares.isEmpty || (Double(shares) ?? 0) <= 0)
                }
            }
            .alert("Remove Stock", isPresented: $showingRemoveAlert) {
                Button("Remove", role: .destructive) {
                    removeStock()
                }
            } message: {
                Text("Are you sure you want to remove \(stock.symbol) from your portfolio?")
            }
            .alert("Error", isPresented: $showingAlert) {
                Button("OK") { }
            } message: {
                Text(alertMessage)
            }
        }
    }
    
    private func saveChanges() {
        guard let sharesDouble = Double(shares), sharesDouble > 0 else {
            alertMessage = "Please enter a valid number of shares greater than 0."
            showingAlert = true
            return
        }
        
        let priceDouble = purchasePrice.isEmpty ? nil : Double(purchasePrice)
        if !purchasePrice.isEmpty && priceDouble == nil {
            alertMessage = "Please enter a valid purchase price."
            showingAlert = true
            return
        }
        
        portfolioManager.update(stock, quantity: sharesDouble, purchasePrice: priceDouble)
        dismiss()
    }
    
    private func removeStock() {
        portfolioManager.remove(stock)
        dismiss()
    }
}

struct EditStockView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleStock = StockItem(
            symbol: "AAPL",
            name: "Apple Inc.",
            quantity: 10,
            purchasePrice: 165.0,
            currentPrice: 170.5,
            previousClose: 169.8,
            lastUpdated: Date()
        )
        
        EditStockView(stock: sampleStock, index: 0)
            .environmentObject(UnifiedPortfolioManager.preview)
    }
}
