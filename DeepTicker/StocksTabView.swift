import SwiftUI
import Playgrounds

// Import for design system components
extension AppDesignSystem {
    // Ensure we have all necessary design system components available
}

struct StocksTabView: View {
    @ObservedObject var aiNewsProvider: AINewsProvider
    @EnvironmentObject var portfolio: PortfolioStore
    @EnvironmentObject var dataRefreshManager: DataRefreshManager

    @State private var isRefreshing = false

    // New add stock state properties
    @State private var isAddingStock = false
    @State private var addSymbol = ""
    @State private var addQuantity = ""
    @State private var addPurchasePrice = ""
    @State private var addError: String? = nil
    @State private var addIsLoading = false

    func triggerAdd(symbol: String, quantity: String, purchasePrice: String?) {
        addSymbol = symbol
        addQuantity = quantity
        addPurchasePrice = purchasePrice ?? ""
        isAddingStock = true
        Task { await addStockAsync() }
    }

    var body: some View {
        NavigationStack {
            List {
                AppHeaderView("DeepTicker", subtitle: "Smart Portfolio Management")
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)

                portfolioSummary
                    .listRowInsets(EdgeInsets(top: AppDesignSystem.Spacing.md, leading: 0, bottom: AppDesignSystem.Spacing.lg, trailing: 0))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)

                Section {
                    if isAddingStock {
                        addStockRow
                            .listRowInsets(EdgeInsets(top: AppDesignSystem.Spacing.sm, leading: AppDesignSystem.Spacing.md, bottom: AppDesignSystem.Spacing.sm, trailing: AppDesignSystem.Spacing.md))

                        if let error = addError {
                            Text(error)
                                .font(AppDesignSystem.Typography.caption1)
                                .foregroundColor(AppDesignSystem.Colors.error)
                                .padding(.horizontal, AppDesignSystem.Spacing.lg)
                                .listRowInsets(EdgeInsets(top: 0, leading: AppDesignSystem.Spacing.md, bottom: 0, trailing: AppDesignSystem.Spacing.md))
                        }
                    }

                    ForEach(portfolio.items, id: \.id) { item in
                        EnhancedStockRowView(
                            item: item,
                            onUpdate: { qty, price in
                                portfolio.update(item, quantity: qty, purchasePrice: price)
                            }
                        )
                        .listRowInsets(EdgeInsets(top: AppDesignSystem.Spacing.sm, leading: AppDesignSystem.Spacing.md, bottom: AppDesignSystem.Spacing.sm, trailing: AppDesignSystem.Spacing.md))
                        .listRowBackground(AppDesignSystem.Colors.cardBackground)
                    }
                    .onDelete(perform: deleteItems)
                } header: {
                    SectionHeaderView(
                        title: "My Investment",
                        icon: "briefcase.fill",
                        action: isAddingStock ? nil : {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isAddingStock = true
                                addError = nil
                                addSymbol = ""
                                addQuantity = ""
                                addPurchasePrice = ""
                                addIsLoading = false
                            }
                        }
                    )
                } footer: {
                    DataSourceFooterView(
                        lastRefresh: portfolio.lastRefresh,
                        dataSource: dataRefreshManager.lastDataSource,
                        isRefreshing: isRefreshing
                    )
                }
            }
            .appListStyle()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await refreshNow() }
                    } label: {
                        if isRefreshing {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .font(AppDesignSystem.Typography.body)
                        }
                    }
                    .disabled(isRefreshing)
                }
            }
        }
    }

    private var portfolioSummary: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(minimum: 150), spacing: AppDesignSystem.Spacing.lg, alignment: .top),
                GridItem(.flexible(minimum: 150), spacing: AppDesignSystem.Spacing.lg, alignment: .top)
            ], 
            alignment: .center,
            spacing: AppDesignSystem.Spacing.lg
        ) {
            PerfectlyAlignedMetricCard(
                title: "Total Value",
                value: portfolio.totalCurrentValue.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD")),
                icon: "dollarsign.circle.fill",
                subtitle: nil,
                subtitleColor: nil
            )
            
            PerfectlyAlignedMetricCard(
                title: "Total Change",
                value: portfolio.earningsPercent.map { "\($0.formatted(.number.precision(.fractionLength(2))))%" } ?? "--",
                icon: "chart.line.uptrend.xyaxis",
                subtitle: {
                    guard let earningsPercent = portfolio.earningsPercent else { return nil }
                    return earningsPercent >= 0 ? "↗ Profit" : "↘ Loss"
                }(),
                subtitleColor: {
                    guard let earningsPercent = portfolio.earningsPercent else { return nil }
                    return earningsPercent >= 0 ? AppDesignSystem.Colors.profit : AppDesignSystem.Colors.loss
                }()
            )
        }
        .padding(.horizontal, AppDesignSystem.Spacing.lg)
        .frame(maxWidth: .infinity)
    }
    
    private var addStockRow: some View {
        HStack(spacing: AppDesignSystem.Spacing.md) {
            StockTextField("Symbol", text: $addSymbol, capitalization: .characters)
            StockTextField("Qty", text: $addQuantity, keyboardType: .decimalPad)
            StockTextField("Price", text: $addPurchasePrice, keyboardType: .decimalPad)
            
            if addIsLoading {
                ProgressView()
                    .frame(width: 24, height: 24)
            } else {
                Button {
                    Task { await addStockAsync() }
                } label: {
                    Image(systemName: "checkmark")
                        .font(AppDesignSystem.Typography.body)
                        .foregroundColor(.white)
                }
                .frame(width: 36, height: 36)
                .background(AppDesignSystem.Colors.success)
                .clipShape(Circle())
                .disabled(addIsLoading)
            }

            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isAddingStock = false
                    addError = nil
                    addSymbol = ""
                    addQuantity = ""
                    addPurchasePrice = ""
                    addIsLoading = false
                }
            } label: {
                Image(systemName: "xmark")
                    .font(AppDesignSystem.Typography.body)
                    .foregroundColor(AppDesignSystem.Colors.error)
            }
            .frame(width: 36, height: 36)
            .background(AppDesignSystem.Colors.sectionBackground)
            .clipShape(Circle())
            .disabled(addIsLoading)
        }
    }

    private func deleteItems(at offsets: IndexSet) {
        for index in offsets {
            let item = portfolio.items[index]
            portfolio.remove(item)
        }
    }

    private func refreshNow() async {
        let refreshFrequency = dataRefreshManager.refreshSettings[.stockPrices] ?? .fiveMinutes
        
        // Check if we should respect rate limiting
        if let lastRefresh = portfolio.lastRefresh,
           let interval = refreshFrequency.timeInterval,
           Date().timeIntervalSince(lastRefresh) < interval {
            // Too soon to refresh based on user settings
            return
        }
        
        isRefreshing = true
        await dataRefreshManager.refreshData(for: .stockPrices, force: true)
        await portfolio.refreshAllPrices()
        isRefreshing = false
    }

    private func addStockAsync() async {
        await MainActor.run {
            addError = nil
            addIsLoading = true
        }

        let symbolTrimmed = addSymbol.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !symbolTrimmed.isEmpty else {
            await MainActor.run {
                addError = "Symbol is required."
                addIsLoading = false
            }
            return
        }

        guard let qty = Double(addQuantity), qty > 0 else {
            await MainActor.run {
                addError = "Quantity must be a valid number greater than zero."
                addIsLoading = false
            }
            return
        }

        var userProvidedPurchasePrice: Double? = nil
        if let pp = Double(addPurchasePrice), pp > 0 {
            userProvidedPurchasePrice = pp
        } else if !addPurchasePrice.isEmpty {
            await MainActor.run {
                addError = "Purchase price must be a valid number greater than zero."
                addIsLoading = false
            }
            return
        }

        do {
            let service = DefaultStockPriceService()
            
            // Fetch price data and search for the name with enhanced service
            async let stockQuoteTask = service.fetchStockPrice(symbol: symbolTrimmed, timeout: 10.0)
            async let searchResultsTask = service.searchSymbol(symbolTrimmed, timeout: 8.0)

            let stockQuote = try await stockQuoteTask
            let searchResults = try await searchResultsTask

            let stockName = searchResults.first(where: { $0.symbol.uppercased() == symbolTrimmed })?.name
            let finalPrice = userProvidedPurchasePrice ?? stockQuote.currentPrice

            await MainActor.run {
                portfolio.add(
                    symbol: symbolTrimmed,
                    name: stockName ?? symbolTrimmed,
                    quantity: qty,
                    purchasePrice: finalPrice,
                    currentPrice: stockQuote.currentPrice,
                    previousClose: stockQuote.previousClose
                )
                withAnimation {
                    isAddingStock = false
                    addSymbol = ""
                    addQuantity = ""
                    addPurchasePrice = ""
                    addError = nil
                    addIsLoading = false
                }
            }
        } catch {
            await MainActor.run {
                addError = "Failed to add stock: \(error.localizedDescription)"
                addIsLoading = false
            }
        }
    }
}

// MARK: - Enhanced Components

private struct SectionHeaderView: View {
    let title: String
    let icon: String
    let action: (() -> Void)?
    
    init(title: String, icon: String, action: (() -> Void)? = nil) {
        self.title = title
        self.icon = icon
        self.action = action
    }
    
    var body: some View {
        HStack {
            HStack(spacing: AppDesignSystem.Spacing.sm) {
                Image(systemName: icon)
                    .font(AppDesignSystem.Typography.footnote)
                    .foregroundColor(AppDesignSystem.Colors.primary)
                
                Text(title)
                    .font(AppDesignSystem.Typography.sectionHeader)
                    .foregroundColor(AppDesignSystem.Colors.primary)
            }
            
            Spacer()
            
            if let action = action {
                Button(action: action) {
                    Image(systemName: "plus")
                        .font(AppDesignSystem.Typography.body)
                        .foregroundColor(AppDesignSystem.Colors.primary)
                }
            }
        }
        .padding(.vertical, AppDesignSystem.Spacing.xs)
    }
}

private struct StockTextField: View {
    let placeholder: String
    @Binding var text: String
    let keyboardType: UIKeyboardType
    let capitalization: TextInputAutocapitalization
    
    init(_ placeholder: String, text: Binding<String>, keyboardType: UIKeyboardType = .default, capitalization: TextInputAutocapitalization = .never) {
        self.placeholder = placeholder
        self._text = text
        self.keyboardType = keyboardType
        self.capitalization = capitalization
    }
    
    var body: some View {
        TextField(placeholder, text: $text)
            .font(AppDesignSystem.Typography.body)
            .textInputAutocapitalization(capitalization)
            .autocorrectionDisabled()
            .keyboardType(keyboardType)
            .padding(AppDesignSystem.Spacing.md)
            .background(AppDesignSystem.Colors.sectionBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppDesignSystem.CornerRadius.sm))
    }
}

private struct EnhancedStockRowView: View {
    let item: StockItem
    let onUpdate: (Double, Double?) -> Void

    @State private var isEditing = false
    @State private var quantityString: String = ""
    @State private var purchasePriceString: String = ""
    @FocusState private var isQtyFocused: Bool

    private var currencyCode: String {
        Locale.current.currency?.identifier ?? "USD"
    }
    
    private var changeColor: Color {
        guard let purchasePriceUnwrapped = item.purchasePrice,
              let current = item.currentPrice else { return AppDesignSystem.Colors.neutral }
        let change = current - purchasePriceUnwrapped
        return change >= 0 ? AppDesignSystem.Colors.profit : AppDesignSystem.Colors.loss
    }
    
    private var changePercentage: Double? {
        guard let purchasePrice = item.purchasePrice, 
              let current = item.currentPrice, 
              purchasePrice > 0 else { return nil }
        let change = current - purchasePrice
        return (change / purchasePrice) * 100
    }

    var body: some View {
        if isEditing {
            editingView
        } else {
            displayView
        }
    }

    private var displayView: some View {
        AppCard(padding: AppDesignSystem.Spacing.lg) {
            VStack(alignment: .leading, spacing: AppDesignSystem.Spacing.md) {
                HStack {
                    VStack(alignment: .leading, spacing: AppDesignSystem.Spacing.xs) {
                        Text(item.symbol)
                            .font(AppDesignSystem.Typography.headline)
                            .foregroundColor(.primary)
                        
                        if let name = item.name, !name.isEmpty {
                            Text(name)
                                .font(AppDesignSystem.Typography.subheadline)
                                .foregroundColor(AppDesignSystem.Colors.secondary)
                                .lineLimit(1)
                        }
                    }

                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: AppDesignSystem.Spacing.xs) {
                        Text(item.currentPrice ?? 0, format: .currency(code: currencyCode))
                            .font(AppDesignSystem.Typography.headline)
                            .foregroundColor(.primary)
                        
                        if let changePercentage = changePercentage {
                            Text("\(changePercentage >= 0 ? "+" : "")\(changePercentage.formatted(.number.precision(.fractionLength(2))))%")
                                .font(AppDesignSystem.Typography.caption1)
                                .foregroundColor(changeColor)
                                .fontWeight(.medium)
                        }
                    }
                }

                HStack {
                    MetricView(label: "Quantity", value: item.quantity.formatted(.number.precision(.fractionLength(2))))
                    
                    Spacer()
                    
                    MetricView(label: "Avg. Price", 
                             value: item.purchasePrice?.formatted(.currency(code: currencyCode)) ?? "—")
                    
                    Spacer()
                    
                    MetricView(label: "Total Value", 
                             value: item.totalValue.formatted(.currency(code: currencyCode)),
                             isAccented: true)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            quantityString = "\(item.quantity)"
            purchasePriceString = item.purchasePrice.map { "\($0)" } ?? ""
            withAnimation(.easeInOut(duration: 0.3)) {
                isEditing = true
            }
            isQtyFocused = true
        }
    }

    private var editingView: some View {
        AppCard(padding: AppDesignSystem.Spacing.lg) {
            VStack(alignment: .leading, spacing: AppDesignSystem.Spacing.md) {
                HStack {
                    VStack(alignment: .leading, spacing: AppDesignSystem.Spacing.xs) {
                        Text(item.symbol)
                            .font(AppDesignSystem.Typography.headline)
                            .foregroundColor(.primary)
                        
                        if let name = item.name, !name.isEmpty {
                            Text(name)
                                .font(AppDesignSystem.Typography.subheadline)
                                .foregroundColor(AppDesignSystem.Colors.secondary)
                                .lineLimit(1)
                        }
                    }
                    Spacer()
                }
                
                HStack(spacing: AppDesignSystem.Spacing.md) {
                    VStack(alignment: .leading, spacing: AppDesignSystem.Spacing.xs) {
                        Text("Quantity")
                            .font(AppDesignSystem.Typography.caption1)
                            .foregroundColor(AppDesignSystem.Colors.secondary)
                        TextField("Quantity", text: $quantityString)
                            .keyboardType(.decimalPad)
                            .font(AppDesignSystem.Typography.body)
                            .padding(AppDesignSystem.Spacing.sm)
                            .background(AppDesignSystem.Colors.sectionBackground)
                            .clipShape(RoundedRectangle(cornerRadius: AppDesignSystem.CornerRadius.sm))
                            .focused($isQtyFocused)
                    }

                    VStack(alignment: .leading, spacing: AppDesignSystem.Spacing.xs) {
                        Text("Avg. Price")
                            .font(AppDesignSystem.Typography.caption1)
                            .foregroundColor(AppDesignSystem.Colors.secondary)
                        TextField("Avg. Price", text: $purchasePriceString)
                            .keyboardType(.decimalPad)
                            .font(AppDesignSystem.Typography.body)
                            .padding(AppDesignSystem.Spacing.sm)
                            .background(AppDesignSystem.Colors.sectionBackground)
                            .clipShape(RoundedRectangle(cornerRadius: AppDesignSystem.CornerRadius.sm))
                    }

                    VStack(spacing: AppDesignSystem.Spacing.xs) {
                        Button {
                            let newQty = Double(quantityString) ?? item.quantity
                            var newPrice: Double? = item.purchasePrice
                            if purchasePriceString.isEmpty {
                                newPrice = nil
                            } else if let price = Double(purchasePriceString) {
                                newPrice = price
                            }
                            onUpdate(newQty, newPrice)
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isEditing = false
                            }
                        } label: {
                            Image(systemName: "checkmark")
                                .font(AppDesignSystem.Typography.body)
                                .foregroundColor(.white)
                        }
                        .frame(width: 32, height: 32)
                        .background(AppDesignSystem.Colors.success)
                        .clipShape(Circle())

                        Button {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isEditing = false
                            }
                        } label: {
                            Image(systemName: "xmark")
                                .font(AppDesignSystem.Typography.body)
                                .foregroundColor(AppDesignSystem.Colors.error)
                        }
                        .frame(width: 32, height: 32)
                        .background(AppDesignSystem.Colors.sectionBackground)
                        .clipShape(Circle())
                    }
                }
            }
        }
    }
}

private struct MetricView: View {
    let label: String
    let value: String
    let isAccented: Bool
    
    init(label: String, value: String, isAccented: Bool = false) {
        self.label = label
        self.value = value
        self.isAccented = isAccented
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppDesignSystem.Spacing.xs) {
            Text(label)
                .font(AppDesignSystem.Typography.caption1)
                .foregroundColor(AppDesignSystem.Colors.secondary)
            Text(value)
                .font(AppDesignSystem.Typography.subheadline)
                .foregroundColor(isAccented ? AppDesignSystem.Colors.primary : .primary)
                .fontWeight(isAccented ? .semibold : .regular)
        }
    }
}

// MARK: - Perfectly Aligned Metric Card Component

private struct PerfectlyAlignedMetricCard: View {
    let title: String
    let value: String
    let icon: String
    let subtitle: String?
    let subtitleColor: Color?
    
    var body: some View {
        AppCard(cornerRadius: AppDesignSystem.CornerRadius.md) {
            VStack(alignment: .leading, spacing: 0) {
                // Header section with title and icon - fixed height
                HStack(alignment: .center) {
                    Text(title)
                        .font(AppDesignSystem.Typography.caption1)
                        .foregroundColor(AppDesignSystem.Colors.secondary)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Image(systemName: icon)
                        .font(AppDesignSystem.Typography.callout)
                        .foregroundColor(AppDesignSystem.Colors.primary)
                }
                .frame(height: 20) // Fixed header height for alignment
                
                Spacer()
                    .frame(minHeight: AppDesignSystem.Spacing.md, maxHeight: AppDesignSystem.Spacing.lg)
                
                // Value section - fixed layout
                VStack(alignment: .leading, spacing: AppDesignSystem.Spacing.xs) {
                    Text(value)
                        .font(AppDesignSystem.Typography.title2)
                        .foregroundColor(.primary)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    
                    // Subtitle area - always present for consistent alignment
                    HStack {
                        if let subtitle = subtitle {
                            Text(subtitle)
                                .font(AppDesignSystem.Typography.footnote)
                                .foregroundColor(subtitleColor ?? AppDesignSystem.Colors.secondary)
                                .fontWeight(.medium)
                        } else {
                            // Invisible placeholder to maintain layout consistency
                            Text(" ")
                                .font(AppDesignSystem.Typography.footnote)
                                .opacity(0)
                        }
                        
                        Spacer()
                    }
                    .frame(height: 18) // Fixed subtitle height
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 120) // Fixed card height for perfect alignment
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Enhanced Metric Card Component

private struct EnhancedMetricCard: View {
    let title: String
    let value: String
    let change: String?
    let changeColor: Color?
    let icon: String?
    let style: CardStyle
    
    enum CardStyle {
        case primary
        case secondary
    }
    
    init(title: String, value: String, change: String? = nil, changeColor: Color? = nil, icon: String? = nil, style: CardStyle = .primary) {
        self.title = title
        self.value = value
        self.change = change
        self.changeColor = changeColor
        self.icon = icon
        self.style = style
    }
    
    var body: some View {
        AppCard(cornerRadius: AppDesignSystem.CornerRadius.md) {
            VStack(alignment: .leading, spacing: AppDesignSystem.Spacing.md) {
                HStack(alignment: .top) {
                    Text(title)
                        .font(AppDesignSystem.Typography.caption1)
                        .foregroundColor(AppDesignSystem.Colors.secondary)
                        .fontWeight(.medium)
                        .multilineTextAlignment(.leading)
                    
                    Spacer()
                    
                    if let icon = icon {
                        Image(systemName: icon)
                            .font(AppDesignSystem.Typography.callout)
                            .foregroundColor(style == .primary ? AppDesignSystem.Colors.primary : AppDesignSystem.Colors.tertiary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .leading, spacing: AppDesignSystem.Spacing.xs) {
                    Text(value)
                        .font(style == .primary ? AppDesignSystem.Typography.title2 : AppDesignSystem.Typography.title3)
                        .foregroundColor(.primary)
                        .fontWeight(.semibold)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                        .multilineTextAlignment(.leading)
                    
                    if let change = change {
                        HStack(spacing: AppDesignSystem.Spacing.xs) {
                            Text(change)
                                .font(AppDesignSystem.Typography.footnote)
                                .foregroundColor(changeColor ?? AppDesignSystem.Colors.secondary)
                                .fontWeight(.medium)
                            
                            Spacer()
                        }
                    }
                }
            }
        }
        .frame(minHeight: 110)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Data Source Footer Component

private struct DataSourceFooterView: View {
    let lastRefresh: Date?
    let dataSource: StockQuote.DataSource?
    let isRefreshing: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppDesignSystem.Spacing.xs) {
            HStack {
                if isRefreshing {
                    HStack(spacing: AppDesignSystem.Spacing.xs) {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("Updating...")
                    }
                } else if let lastRefresh = lastRefresh {
                    Text("Last updated: \(lastRefresh.formatted(date: .omitted, time: .shortened))")
                } else {
                    Text("No data available")
                }
                
                Spacer()
                
                if let dataSource = dataSource {
                    HStack(spacing: AppDesignSystem.Spacing.xs) {
                        Image(systemName: dataSourceIcon(for: dataSource))
                            .font(.caption2)
                        Text("via \(dataSource.displayName)")
                    }
                }
            }
            .font(AppDesignSystem.Typography.caption2)
            .foregroundColor(AppDesignSystem.Colors.tertiary)
        }
        .padding(.horizontal, AppDesignSystem.Spacing.lg)
        .padding(.vertical, AppDesignSystem.Spacing.sm)
    }
    
    private func dataSourceIcon(for source: StockQuote.DataSource) -> String {
        switch source {
        case .yahooFinance:
            return "network"
        case .alphaVantage:
            return "server.rack"
        case .cache:
            return "externaldrive.fill"
        }
    }
}


#Preview {
    StocksTabView(aiNewsProvider: AINewsProvider())
        .environmentObject(PortfolioStore.preview)
}



#Playground {
struct DemoView: View {
    @StateObject private var portfolio = PortfolioStore()
    @State private var stocksView = StocksTabView(aiNewsProvider: AINewsProvider())
    var body: some View {
        VStack {
            stocksView
                .environmentObject(portfolio)
            Button("Add AAPL") {
                stocksView.triggerAdd(symbol: "AAPL", quantity: "10", purchasePrice: "170")
            }
        }
    }
}
}
