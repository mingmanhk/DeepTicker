import SwiftUI

@MainActor
struct ModernMyInvestmentTab: View {
    // MARK: - Properties
    @ObservedObject private var portfolioManager = UnifiedPortfolioManager.shared
    @StateObject private var dataManager = DataManager.shared
    
    // MARK: - UI State
    @State private var showingAddStock = false
    @State private var showingStockDetail: StockItem?
    @State private var editingStock: EditingStock?
    @State private var isRefreshing = false
    @State private var isAddingStock = false
    @State private var refreshTask: Task<Void, Never>?
    
    // MARK: - Supporting Types
    struct EditingStock: Identifiable, Equatable {
        let id = UUID()
        let stock: StockItem
        let index: Int
        
        static func == (lhs: EditingStock, rhs: EditingStock) -> Bool {
            lhs.id == rhs.id
        }
    }
    
    // MARK: - Main View
    var body: some View {
        NavigationStack {
            ZStack {
                backgroundGradient
                content
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .refreshable { await refreshAllData() }
            .onChange(of: portfolioManager.items.count) { _, _ in
                handleHoldingsChange()
            }
            .onDisappear {
                refreshTask?.cancel()
            }
        }
        .fullScreenCover(isPresented: $showingAddStock) {
            AddStockView()
                .environmentObject(portfolioManager)
                .onDisappear {
                    isAddingStock = false
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 100_000_000)
                        handleHoldingsChange()
                    }
                }
        }
        .sheet(item: $editingStock) { editingData in
            EditStockView(stock: editingData.stock, index: editingData.index)
                .environmentObject(portfolioManager)
                .onDisappear {
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 100_000_000)
                        handleHoldingsChange()
                    }
                }
        }
        .sheet(item: $showingStockDetail) { stock in
            StockDetailSheet(stock: PortfolioStock(
                symbol: stock.symbol,
                currentPrice: stock.currentPrice ?? 0,
                previousClose: stock.previousClose ?? stock.currentPrice ?? 0,
                quantity: stock.quantity
            ))
            .environmentObject(dataManager)
        }
    }
    
    // MARK: - View Components
    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(.systemBackground),
                Color(.systemBackground).opacity(0.8),
                Color(.systemGroupedBackground)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            ToolbarAppIconView(showAppName: true)
        }
        
        ToolbarItem(placement: .principal) {
            VStack(spacing: 2) {
                Text("My Portfolio")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
                
                if let lastUpdate = portfolioManager.lastRefresh {
                    Text("Updated \(lastUpdate, style: .relative)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        
        ToolbarItem(placement: .topBarTrailing) {
            HStack(spacing: 12) {
                Button {
                    Task { await refreshAllData() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.title3)
                        .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                        .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: isRefreshing)
                }
                .disabled(isRefreshing)
                
                Button("Add", action: handleAddStock)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(isAddingStock || isRefreshing)
            }
        }
    }
    
    private var content: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                if portfolioManager.items.isEmpty {
                    emptyStateSection
                } else {
                    portfolioOverviewSection
                    performanceMetricsSection
                    holdingsSection
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
    }
    
    // MARK: - Content Sections
    private var portfolioOverviewSection: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Portfolio Value")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                    
                    Text(portfolioManager.totalCurrentValue, format: .currency(code: "USD"))
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .minimumScaleFactor(0.8)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 6) {
                    Text("Today's Change")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        HStack(spacing: 4) {
                            Image(systemName: portfolioManager.totalDailyChange >= 0 ? "arrow.up.right" : "arrow.down.right")
                                .font(.caption)
                                .fontWeight(.semibold)
                            
                            Text(portfolioManager.totalDailyChange, format: .currency(code: "USD"))
                                .font(.callout)
                                .fontWeight(.bold)
                        }
                        
                        Text("(\(portfolioManager.totalDailyChangePercentage, specifier: "%.2f")%)")
                            .font(.caption2)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(portfolioManager.totalDailyChange >= 0 ? .green : .red)
                }
            }
            
            if totalInvested > 0 {
                Divider()
                    .padding(.vertical, 4)
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Total Return")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                        
                        HStack(spacing: 6) {
                            Text(totalReturn, format: .currency(code: "USD"))
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundStyle(totalReturn >= 0 ? .green : .red)
                            
                            Text("(\(totalReturnPercentage >= 0 ? "+" : "")\(totalReturnPercentage, specifier: "%.1f")%)")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(totalReturn >= 0 ? .green : .red)
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Invested")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Text(totalInvested, format: .currency(code: "USD"))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                    }
                }
            }
        }
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
    
    private var performanceMetricsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Performance Metrics")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                performanceCard(
                    title: "Best Performer",
                    value: bestPerformingStock?.symbol ?? "—",
                    subtitle: bestPerformingStock != nil ? String(format: "+%.1f%%", bestPerformingStock?.dailyChange ?? 0) : "No data",
                    color: .green,
                    icon: "arrow.up.circle.fill"
                )
                
                performanceCard(
                    title: "Worst Performer", 
                    value: worstPerformingStock?.symbol ?? "—",
                    subtitle: worstPerformingStock != nil ? String(format: "%.1f%%", worstPerformingStock?.dailyChange ?? 0) : "No data",
                    color: .red,
                    icon: "arrow.down.circle.fill"
                )
                
                performanceCard(
                    title: "Holdings",
                    value: "\(portfolioManager.items.count)",
                    subtitle: portfolioManager.items.count == 1 ? "Stock" : "Stocks",
                    color: .blue,
                    icon: "chart.pie.fill"
                )
                
                performanceCard(
                    title: "Avg. Return",
                    value: portfolioManager.items.isEmpty ? "—" : String(format: "%.1f%%", averageReturn),
                    subtitle: "Per holding",
                    color: averageReturn >= 0 ? .green : .red,
                    icon: "chart.bar.fill"
                )
            }
        }
    }
    
    private func performanceCard(title: String, value: String, subtitle: String, color: Color, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.title3)
                    .fontWeight(.bold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Helper Functions
    private func handleAddStock() {
        guard !isAddingStock else { return }
        isAddingStock = true
        showingAddStock = true
        
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000)
            isAddingStock = false
        }
    }
    
    private func refreshAllData() async {
        isRefreshing = true
        await dataManager.forceRefreshAll()
        isRefreshing = false
    }
    
    private func handleHoldingsChange() {
        refreshTask?.cancel()
        refreshTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else { return }
            await refreshAllData()
        }
    }
    
    private var emptyStateSection: some View {
        VStack(spacing: 32) {
            VStack(spacing: 20) {
                Image(systemName: "chart.line.uptrend.xyaxis.circle")
                    .font(.system(size: 60))
                    .foregroundStyle(.secondary)
                
                VStack(spacing: 8) {
                    Text("Start Your Investment Journey")
                        .font(.title2)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    
                    Text("Add stocks to track your portfolio performance and market trends")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            
            Button("Add Your First Stock", action: handleAddStock)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(isAddingStock)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 24)
    }
    
    private var holdingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Holdings")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("\(portfolioManager.items.count) \(portfolioManager.items.count == 1 ? "stock" : "stocks")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            LazyVStack(spacing: 12) {
                ForEach(Array(portfolioManager.items.enumerated()), id: \.element.id) { index, stock in
                    stockRow(stock: stock, index: index)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button("Edit") { editingStock = EditingStock(stock: stock, index: index) }
                                .tint(.blue)
                            
                            Button("Delete", role: .destructive) {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    portfolioManager.remove(at: index)
                                }
                                handleHoldingsChange()
                            }
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                            Button("Details") { showingStockDetail = stock }
                                .tint(.green)
                        }
                }
            }
        }
    }
    
    private func stockRow(stock: StockItem, index: Int) -> some View {
        Button { showingStockDetail = stock } label: {
            HStack(spacing: 16) {
                // Stock Symbol Circle
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 50, height: 50)
                    .overlay {
                        Text(stock.symbol.prefix(2).uppercased())
                            .font(.headline)
                            .fontWeight(.bold)
                    }
                
                // Stock Info
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(stock.symbol)
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        if let name = stock.name {
                            Text("• \(name)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                    }
                    
                    HStack(spacing: 8) {
                        Text("\(stock.quantity, specifier: "%.2f") shares")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        if let purchasePrice = stock.purchasePrice {
                            Text("• Avg: \(purchasePrice, format: .currency(code: "USD"))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                // Price and Performance
                VStack(alignment: .trailing, spacing: 6) {
                    VStack(alignment: .trailing, spacing: 2) {
                        if let currentPrice = stock.currentPrice {
                            Text(currentPrice, format: .currency(code: "USD"))
                                .font(.headline)
                                .fontWeight(.semibold)
                        } else {
                            Text("No Price")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Text(stock.totalValue, format: .currency(code: "USD"))
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                    }
                    
                    // Daily Change Badge
                    if let dailyChange = stock.dailyChange {
                        HStack(spacing: 4) {
                            Image(systemName: dailyChange >= 0 ? "arrow.up" : "arrow.down")
                                .font(.caption2)
                            
                            Text("\(dailyChange, specifier: "%.1f")%")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .foregroundStyle(dailyChange >= 0 ? .green : .red)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background((dailyChange >= 0 ? Color.green : Color.red).opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                
                // Action Button
                Button { editingStock = EditingStock(stock: stock, index: index) } label: {
                    Image(systemName: "ellipsis")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .frame(width: 30, height: 30)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Computed Properties
    private var bestPerformingStock: StockItem? {
        portfolioManager.items.max { first, second in
            (first.dailyChange ?? -Double.infinity) < (second.dailyChange ?? -Double.infinity)
        }
    }
    
    private var worstPerformingStock: StockItem? {
        portfolioManager.items.min { first, second in
            (first.dailyChange ?? Double.infinity) < (second.dailyChange ?? Double.infinity)
        }
    }
    
    private var totalInvested: Double {
        portfolioManager.items.reduce(0.0) { accumulator, stockItem in
            accumulator + ((stockItem.purchasePrice ?? 0) * stockItem.quantity)
        }
    }
    
    private var totalReturn: Double {
        portfolioManager.totalCurrentValue - totalInvested
    }
    
    private var totalReturnPercentage: Double {
        guard totalInvested > 0 else { return 0 }
        return (totalReturn / totalInvested) * 100
    }
    
    private var averageReturn: Double {
        guard !portfolioManager.items.isEmpty else { return 0 }
        let returns = portfolioManager.items.compactMap { stock -> Double? in
            guard let purchasePrice = stock.purchasePrice,
                  let currentPrice = stock.currentPrice,
                  purchasePrice > 0 else { return nil }
            return ((currentPrice - purchasePrice) / purchasePrice) * 100
        }
        guard !returns.isEmpty else { return 0 }
        return returns.reduce(0, +) / Double(returns.count)
    }
}
// MRK: - Preview
#Preview {
    ModernMyInvestmentTab()
        .environmentObject(DataManager.shared)
}
