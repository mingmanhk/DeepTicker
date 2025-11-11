import SwiftUI

struct AddStockView: View {
    @EnvironmentObject var portfolioManager: UnifiedPortfolioManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var searchText = ""
    @State private var selectedStock: StockSearchResult?
    @State private var shares = ""
    @State private var purchasePrice = ""
    @State private var searchResults: [StockSearchResult] = []
    @State private var isSearching = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var isLoadingPrice = false
    
    @StateObject private var defaultService = DefaultStockPriceService()
    private let alphaVantageService = AlphaVantageService()
    
    @State private var debounceTask: Task<Void, Never>? = nil
    
    // Computed properties for API key status
    private var hasRapidAPIKey: Bool {
        !SecureConfigurationManager.shared.rapidAPIKey.isEmpty
    }
    
    private var hasAlphaVantageKey: Bool {
        !SecureConfigurationManager.shared.alphaVantageAPIKey.isEmpty
    }
    
    private var hasRequiredAPIKeys: Bool {
        hasRapidAPIKey || hasAlphaVantageKey
    }
    
    var body: some View {
        NavigationView {
            Form {
                // API Status Section
                if !hasRequiredAPIKeys {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text("API Keys Required")
                                    .fontWeight(.semibold)
                            }
                            
                            Text("To fetch real-time stock prices, please configure your RapidAPI and Alpha Vantage keys in Settings.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text("Current Status:")
                                .font(.caption)
                                .fontWeight(.medium)
                                .padding(.top, 4)
                            
                            HStack(spacing: 4) {
                                Image(systemName: hasRapidAPIKey ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundColor(hasRapidAPIKey ? .green : .red)
                                    .font(.caption)
                                Text("RapidAPI")
                                    .font(.caption)
                            }
                            
                            HStack(spacing: 4) {
                                Image(systemName: hasAlphaVantageKey ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundColor(hasAlphaVantageKey ? .green : .red)
                                    .font(.caption)
                                Text("Alpha Vantage")
                                    .font(.caption)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                Section("Search Stocks") {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        
                        TextField("Enter stock symbol or company name", text: $searchText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .onSubmit {
                                print("🔍 TextField onSubmit called with: '\(searchText)'")
                                searchStocks()
                            }
                            .onChange(of: searchText) { oldValue, newValue in
                                print("🔍 TextField onChange: '\(oldValue)' -> '\(newValue)'")
                                debounceSearch(with: newValue)
                            }
                            .autocapitalization(.allCharacters)
                            .disableAutocorrection(true)
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
                                    print("🔍 Selected stock: \(result.symbol) - \(result.name)")
                                    selectedStock = result
                                    searchText = result.symbol
                                    searchResults = []
                                    // Only clear purchase price if user hasn't entered one
                                    if purchasePrice.isEmpty || purchasePrice == "0.00" {
                                        purchasePrice = ""
                                    }
                                    Task { 
                                        print("🔵 Starting fetchAndPrefillDetails for: \(result.symbol)")
                                        await fetchAndPrefillDetails(for: result.symbol) 
                                    }
                                }
                        }
                    } else if !searchText.isEmpty && !isSearching {
                        // Show debug info when no results
                        Text("No results found for '\(searchText)'")
                            .foregroundColor(.secondary)
                            .font(.caption)
                            .padding(.vertical, 4)
                        
                        // Allow manual entry for valid symbols
                        if searchText.range(of: "^[A-Za-z0-9.:-]+$", options: .regularExpression) != nil {
                            Button("Use '\(searchText.uppercased())' as symbol") {
                                let manualResult = StockSearchResult(
                                    symbol: searchText.uppercased(), 
                                    name: searchText.uppercased(), 
                                    type: "Manual Entry", 
                                    region: "", 
                                    currency: ""
                                )
                                selectedStock = manualResult
                                searchResults = []
                                // Only clear purchase price if user hasn't entered one
                                if purchasePrice.isEmpty || purchasePrice == "0.00" {
                                    purchasePrice = ""
                                }
                                Task { 
                                    print("🔵 Starting fetchAndPrefillDetails for manual entry: \(searchText.uppercased())")
                                    await fetchAndPrefillDetails(for: searchText.uppercased()) 
                                }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
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
                                if isLoadingPrice {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                        .frame(width: 80, height: 36)
                                } else {
                                    TextField("0.00", text: $purchasePrice)
                                        .keyboardType(.decimalPad)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                        .frame(width: 80)
                                }
                            }
                        }
                        
                        // Show helpful message if price is estimated or needs manual entry
                        if !isLoadingPrice && purchasePrice.isEmpty {
                            HStack {
                                Image(systemName: "info.circle")
                                    .foregroundColor(.orange)
                                Text("Enter purchase price manually")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                                Spacer()
                            }
                        } else if !isLoadingPrice && !purchasePrice.isEmpty && 
                                  ["150.00", "130.00", "350.00", "200.00", "140.00", "400.00", "100.00"].contains(purchasePrice) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundColor(.orange)
                                Text("Estimated price - please verify")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                                Spacer()
                            }
                        }
                    }
                    
                    Section {
                        Button(action: addStock) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Add to My Investment")
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
                
                if selectedStock == nil && searchResults.isEmpty && !searchText.isEmpty && searchText.count >= 2 {
                    Section("Manual Entry") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Symbol not found? Add manually:")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            Button("Add \(searchText.uppercased()) manually") {
                                addManualStock()
                            }
                            .foregroundColor(.blue)
                        }
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
            .alert(alertMessage.contains("API") ? "API Configuration Required" : "Error", isPresented: $showingAlert) {
                if alertMessage.contains("API") {
                    Button("Enter Manually", role: .cancel) { }
                } else {
                    Button("OK") { }
                }
            } message: {
                Text(alertMessage)
            }
            .task(id: selectedStock?.symbol) {
                // No-op placeholder to keep state updates consistent
            }
            .onDisappear {
                // Cancel any pending search task when view disappears
                debounceTask?.cancel()
            }
        }
    }
    
    private func debounceSearch(with query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        print("🔍 DebounceSearch called with: '\(trimmed)'")
        
        // Cancel any existing debounce task
        debounceTask?.cancel()
        
        // If empty, clear results and selection
        if trimmed.isEmpty {
            searchResults = []
            selectedStock = nil
            return
        }
        
        // Start new debounce task
        debounceTask = Task { @MainActor in
            do {
                // 300ms debounce
                try await Task.sleep(nanoseconds: 300_000_000)
                
                // Check if task was cancelled
                if Task.isCancelled {
                    print("🔍 Search task cancelled for: '\(trimmed)'")
                    return
                }
                
                print("🔍 Performing search after debounce for: '\(trimmed)'")
                await performSearch(for: trimmed)
            } catch {
                // Task was cancelled, which is normal
                print("🔍 Search task cancelled for: '\(trimmed)'")
            }
        }
    }
    
    private func searchStocks() {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        isSearching = true
        searchResults = []

        Task {
            // If user typed an exact symbol (letters/numbers) try direct price fetch to validate
            if query.range(of: "^[A-Za-z0-9.:-]+$", options: .regularExpression) != nil {
                if let validated = await validateSymbol(query.uppercased()) {
                    await MainActor.run {
                        self.selectedStock = validated
                        self.searchText = validated.symbol
                        self.searchResults = []
                        self.isSearching = false
                    }
                    return
                }
            }
            // Otherwise perform provider-backed symbol search (by symbol or name)
            await performSearch(for: query)
        }
    }
    
    private func performSearch(for query: String) async {
        print("🔍 PerformSearch starting for: '\(query)'")
        await MainActor.run { self.isSearching = true }
        
        // Check if task was cancelled before proceeding
        guard !Task.isCancelled else {
            await MainActor.run { self.isSearching = false }
            return
        }
        
        // Debug API key availability
        let configManager = SecureConfigurationManager.shared
        let alphaVantageKey = configManager.alphaVantageAPIKey
        let rapidAPIKey = configManager.rapidAPIKey
        print("🔍 API Keys available:")
        print("   - Alpha Vantage: \(alphaVantageKey.isEmpty ? "EMPTY" : "***\(alphaVantageKey.suffix(4))")")
        print("   - RapidAPI: \(rapidAPIKey.isEmpty ? "EMPTY" : "***\(rapidAPIKey.suffix(4))")")
        
        // Try DefaultStockPriceService first (now with improved Yahoo search + Alpha Vantage fallback)
        do {
            print("🔍 Trying DefaultStockPriceService (Yahoo + AV)...")
            let results = try await defaultService.searchSymbol(query, timeout: 8.0)
            print("🔍 DefaultStockPriceService returned \(results.count) results")
            
            guard !Task.isCancelled else {
                await MainActor.run { self.isSearching = false }
                return
            }
            
            let mapped: [StockSearchResult] = results.map { res in
                StockSearchResult(symbol: res.symbol, name: res.name, type: "Equity", region: "", currency: "")
            }
            await MainActor.run {
                self.searchResults = Array(mapped.prefix(10))
                self.isSearching = false
                print("🔍 Updated searchResults with \(self.searchResults.count) items")
                if !self.searchResults.isEmpty {
                    print("🔍 First result: \(self.searchResults[0].symbol) - \(self.searchResults[0].name)")
                }
            }
            return
        } catch {
            print("🔍 DefaultStockPriceService failed: \(error.localizedDescription)")
        }

        // Direct Alpha Vantage fallback (in case DefaultService's AV is temporarily disabled)
        do {
            print("🔍 Trying direct AlphaVantageService as fallback...")
            let results = try await alphaVantageService.searchSymbol(query)
            print("🔍 Direct AlphaVantageService returned \(results.count) results")
            
            guard !Task.isCancelled else {
                await MainActor.run { self.isSearching = false }
                return
            }
            
            await MainActor.run {
                self.searchResults = Array(results.prefix(10))
                self.isSearching = false
                print("🔍 Updated searchResults with \(self.searchResults.count) items")
                if !self.searchResults.isEmpty {
                    print("🔍 First AV result: \(self.searchResults[0].symbol) - \(self.searchResults[0].name)")
                }
            }
            return
        } catch {
            print("🔍 Direct AlphaVantageService failed: \(error.localizedDescription)")
            // Check if we hit rate limit or API issues
            if error.localizedDescription.contains("rate limit") || error.localizedDescription.contains("API key") {
                await MainActor.run {
                    self.isSearching = false
                    self.alertMessage = "Search temporarily unavailable due to rate limits. Please try again in a moment or use manual entry."
                    self.showingAlert = true
                }
                return
            }
        }

        // If it looks like a direct symbol, try validation as final fallback
        if query.count <= 6 && query.range(of: "^[A-Za-z0-9.:-]+$", options: .regularExpression) != nil {
            print("🔍 Query looks like a symbol, trying validation as final fallback...")
            if let validated = await validateSymbol(query.uppercased()) {
                await MainActor.run {
                    self.selectedStock = validated
                    self.searchText = validated.symbol
                    self.searchResults = []
                    self.isSearching = false
                    print("🔍 Symbol validation successful for: \(validated.symbol)")
                }
                return
            }
        }

        // Final state: no results found
        await MainActor.run {
            self.isSearching = false
            
            // If query looks like a stock symbol, allow manual entry
            if query.range(of: "^[A-Za-z0-9.:-]+$", options: .regularExpression) != nil {
                print("🔍 Search failed for '\(query)', but allowing manual entry")
            } else {
                print("🔍 Search failed for non-symbol query: \(query)")
            }
        }
    }

    private func validateSymbol(_ symbol: String) async -> StockSearchResult? {
        do {
            // Use default service to validate existence by fetching a quote
            _ = try await defaultService.fetchStockPrice(symbol: symbol, timeout: 8.0)
            // If fetch succeeded, we consider it a valid tradable symbol
            return StockSearchResult(symbol: symbol, name: symbol, type: "Equity", region: "", currency: "")
        } catch {
            // Try Alpha Vantage as a fallback validator
            do {
                let price = try await alphaVantageService.fetchStockPrice(symbol: symbol)
                _ = price.currentPrice // ensure non-throwing path
                return StockSearchResult(symbol: symbol, name: symbol, type: "Equity", region: price.previousClose > 0 ? "" : "", currency: "")
            } catch {
                return nil
            }
        }
    }
    
    private func fetchAndPrefillDetails(for symbol: String) async {
        print("🔵 ==================== FETCH PRICE START ====================")
        print("🔵 Fetching price details for: \(symbol)")
        
        // Debug: Check API key configuration
        let configManager = SecureConfigurationManager.shared
        let rapidKey = configManager.rapidAPIKey
        let alphaKey = configManager.alphaVantageAPIKey
        
        print("🔵 API Key Status:")
        print("   📍 RapidAPI: \(rapidKey.isEmpty ? "❌ EMPTY" : "✅ Configured (\(rapidKey.count) chars, ends with: ***\(rapidKey.suffix(4)))")")
        print("   📍 Alpha Vantage: \(alphaKey.isEmpty ? "❌ EMPTY" : "✅ Configured (\(alphaKey.count) chars, ends with: ***\(alphaKey.suffix(4)))")")
        
        await MainActor.run {
            isLoadingPrice = true
        }
        
        print("🔵 Attempting DefaultStockPriceService (RapidAPI primary -> Alpha Vantage fallback)...")
        
        do {
            let quote = try await defaultService.fetchStockPrice(symbol: symbol, timeout: 10.0)
            await MainActor.run {
                // Pre-fill purchase price with current price only if field is empty
                if self.purchasePrice.isEmpty {
                    let prefill = quote.currentPrice
                    self.purchasePrice = String(format: "%.2f", prefill)
                    print("✅ SUCCESS! Pre-filled purchase price: $\(self.purchasePrice) for \(symbol)")
                    print("✅ Data source: \(quote.dataSource.displayName)")
                    print("✅ Timestamp: \(quote.timestamp)")
                } else {
                    print("🔵 Purchase price already set (\(self.purchasePrice)), not overriding")
                }
                self.isLoadingPrice = false
            }
            print("🔵 ==================== FETCH PRICE SUCCESS ====================")
        } catch {
            print("🔴 DefaultService failed for \(symbol): \(error.localizedDescription)")
            print("🔵 Trying direct Alpha Vantage as last resort...")
            
            // As a fallback, try Alpha Vantage with longer timeout
            do {
                let stock = try await alphaVantageService.fetchStockPrice(symbol: symbol)
                await MainActor.run {
                    // Pre-fill purchase price with current price only if field is empty
                    if self.purchasePrice.isEmpty {
                        let prefill = stock.currentPrice
                        self.purchasePrice = String(format: "%.2f", prefill)
                        print("✅ SUCCESS! Pre-filled purchase price from direct Alpha Vantage: $\(self.purchasePrice) for \(symbol)")
                    } else {
                        print("🔵 Purchase price already set (\(self.purchasePrice)), not overriding")
                    }
                    self.isLoadingPrice = false
                }
                print("🔵 ==================== FETCH PRICE SUCCESS (Alpha Vantage) ====================")
            } catch {
                print("🔴 Direct Alpha Vantage also failed for \(symbol): \(error.localizedDescription)")
                print("🔴 ==================== FETCH PRICE FAILED ====================")
                
                // Show error instead of using estimated prices
                await showAPIKeyRequiredAlert(for: symbol, error: error)
            }
        }
    }
    
    private func showAPIKeyRequiredAlert(for symbol: String, error: Error) async {
        await MainActor.run {
            self.isLoadingPrice = false
            self.purchasePrice = "" // Clear any price
            
            // Check which API keys are missing
            let configManager = SecureConfigurationManager.shared
            let hasRapidAPI = !configManager.rapidAPIKey.isEmpty
            let hasAlphaVantage = !configManager.alphaVantageAPIKey.isEmpty
            
            var message = "Unable to fetch real-time price for \(symbol).\n\n"
            
            if !hasRapidAPI && !hasAlphaVantage {
                message += "⚠️ No API keys configured.\n\n"
                message += "Please add your RapidAPI and Alpha Vantage API keys in Settings to get real-time stock prices.\n\n"
            } else if !hasRapidAPI {
                message += "⚠️ RapidAPI key is missing.\n\n"
                message += "RapidAPI is the primary data source. Please add your RapidAPI key in Settings.\n\n"
            } else if !hasAlphaVantage {
                message += "⚠️ Alpha Vantage key is missing.\n\n"
                message += "RapidAPI failed. Please add Alpha Vantage as a fallback in Settings.\n\n"
            } else {
                message += "⚠️ Both API services are unavailable.\n\n"
                message += "This could be due to:\n"
                message += "• Invalid API keys\n"
                message += "• Rate limits exceeded\n"
                message += "• Network connectivity issues\n\n"
                message += "Please check your API keys in Settings.\n\n"
            }
            
            message += "You can still add the stock by entering the purchase price manually."
            
            self.alertMessage = message
            self.showingAlert = true
        }
    }
    
    private func tryFinalPriceFallback(symbol: String) async {
        // This function is now deprecated - we show alerts instead
        await showAPIKeyRequiredAlert(for: symbol, error: NSError(domain: "StockPrice", code: -1, userInfo: [NSLocalizedDescriptionKey: "No price data available"]))
    }
    
    private func addStock() {
        guard let selectedStock = selectedStock else {
            print("❌ No stock selected")
            alertMessage = "Please select a stock first."
            showingAlert = true
            return
        }
        
        guard let sharesDouble = Double(shares), sharesDouble > 0 else {
            print("❌ Invalid shares: '\(shares)'")
            alertMessage = "Please enter a valid number of shares greater than 0."
            showingAlert = true
            return
        }

        print("🔵 Adding stock: \(selectedStock.symbol), Shares: \(sharesDouble), Price: '\(purchasePrice)'")

        Task { @MainActor in
            do {
                // 1) Validate symbol by attempting to fetch a price
                print("🔵 Fetching price for \(selectedStock.symbol)...")
                let quote = try await defaultService.fetchStockPrice(symbol: selectedStock.symbol, timeout: 8.0)
                print("🔵 Got quote - Current: \(quote.currentPrice), Previous: \(quote.previousClose ?? 0)")

                // 2) Determine purchase price: use user input if provided, else use current price
                let priceDouble: Double
                if let userPrice = Double(purchasePrice), userPrice > 0 {
                    priceDouble = userPrice
                    print("🔵 Using user-provided price: \(priceDouble)")
                } else {
                    // Use current price as default
                    priceDouble = quote.currentPrice
                    print("🔵 Using current price: \(priceDouble)")
                }

                print("🔵 Adding to portfolio manager...")
                portfolioManager.add(
                    symbol: selectedStock.symbol,
                    name: selectedStock.name,
                    quantity: sharesDouble,
                    purchasePrice: priceDouble,
                    currentPrice: quote.currentPrice,
                    previousClose: quote.previousClose
                )
                
                print("✅ Stock added successfully! Portfolio now has \(portfolioManager.items.count) items")
                dismiss()
                
            } catch {
                print("🔴 DefaultService failed: \(error.localizedDescription), trying Alpha Vantage...")
                
                // Fallback: try Alpha Vantage directly to validate symbol and get price
                do {
                    let avPrice = try await alphaVantageService.fetchStockPrice(symbol: selectedStock.symbol)
                    print("🔵 Alpha Vantage quote - Current: \(avPrice.currentPrice), Previous: \(avPrice.previousClose)")
                    
                    let priceDouble: Double
                    if let userPrice = Double(purchasePrice), userPrice > 0 {
                        priceDouble = userPrice
                        print("🔵 Using user-provided price: \(priceDouble)")
                    } else {
                        priceDouble = avPrice.previousClose > 0 ? avPrice.previousClose : avPrice.currentPrice
                        print("🔵 Using Alpha Vantage price: \(priceDouble)")
                    }
                    
                    print("🔵 Adding to portfolio manager via Alpha Vantage...")
                    portfolioManager.add(
                        symbol: selectedStock.symbol,
                        name: selectedStock.name,
                        quantity: sharesDouble,
                        purchasePrice: priceDouble,
                        currentPrice: avPrice.currentPrice,
                        previousClose: avPrice.previousClose
                    )
                    
                    print("✅ Stock added successfully via Alpha Vantage! Portfolio now has \(portfolioManager.items.count) items")
                    dismiss()
                    
                } catch {
                    print("🔴 Both services failed. Error: \(error.localizedDescription)")
                    
                    // Allow adding with manual entry if user provided all data
                    if let userPrice = Double(purchasePrice), userPrice > 0 {
                        print("🔵 Adding stock with manual data...")
                        portfolioManager.add(
                            symbol: selectedStock.symbol,
                            name: selectedStock.name,
                            quantity: sharesDouble,
                            purchasePrice: userPrice,
                            currentPrice: nil, // Will be fetched later
                            previousClose: nil
                        )
                        
                        print("✅ Stock added with manual data! Portfolio now has \(portfolioManager.items.count) items")
                        dismiss()
                    } else {
                        alertMessage = "Unable to fetch stock data. Please check the symbol and try again, or enter a purchase price manually."
                        showingAlert = true
                    }
                }
            }
        }
    }
    
    private func addManualStock() {
        let symbol = searchText.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        selectedStock = StockSearchResult(
            symbol: symbol,
            name: symbol,
            type: "Equity",
            region: "United States", 
            currency: "USD"
        )
        
        // Clear search results to show stock details form
        searchResults = []
        
        print("📝 Added manual stock: \(symbol)")
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
            .environmentObject(UnifiedPortfolioManager.preview)
    }
}
