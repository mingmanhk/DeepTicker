import SwiftUI

@MainActor
struct ModernMyInvestmentTab: View {
    @ObservedObject private var portfolioManager = UnifiedPortfolioManager.shared
    @StateObject private var dataManager = DataManager.shared
    @State private var showingAddStock = false
    @State private var showingStockDetail: StockItem?
    @State private var editingStock: EditingStock?
    @State private var isRefreshing = false
    @State private var isAddingStock = false // Prevent duplicate taps
    @State private var lastPortfolioCount = 0 // Track portfolio changes
    @State private var refreshTask: Task<Void, Never>? // For debouncing refreshes
    
    struct EditingStock: Identifiable, Equatable {
        static func == (lhs: EditingStock, rhs: EditingStock) -> Bool {
            lhs.id == rhs.id
        }
        
        let id = UUID()
        let stock: StockItem
        let index: Int
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                backgroundGradient
                content
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    ToolbarAppIconView(showAppName: true)
                }
                ToolbarItem(placement: .principal) {
                    headerTitleView
                }
                ToolbarItem(placement: .topBarTrailing) {
                    toolbarActions
                }
            }
            .fullScreenCover(isPresented: $showingAddStock) {
                AddStockView()
                    .environmentObject(portfolioManager)
                    .onAppear {
                        print("🔥 AddStockView appeared in fullScreenCover!")
                    }
                    .onDisappear {
                        // Reset the adding state when sheet is dismissed
                        isAddingStock = false
                        
                        // Check if portfolio changed and refresh if needed
                        // We'll trigger refresh after a short delay to ensure any new stock is fully added
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            handleHoldingsChange()
                        }
                    }
            }
            .sheet(item: $editingStock) { editingData in
                EditStockView(stock: editingData.stock, index: editingData.index)
                    .environmentObject(portfolioManager)
                    .onDisappear {
                        // Refresh data after editing
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            handleHoldingsChange()
                        }
                    }
            }
            .sheet(item: $showingStockDetail) { stock in
                let portfolioStock = PortfolioStock(
                    symbol: stock.symbol,
                    currentPrice: stock.currentPrice ?? 0,
                    previousClose: stock.previousClose ?? stock.currentPrice ?? 0,
                    quantity: stock.quantity
                )
                StockDetailSheet(stock: portfolioStock)
                    .environmentObject(dataManager)
            }
            .refreshable {
                await refreshAllData()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("PortfolioDidChange"))) { _ in
                // Auto-refresh when portfolio changes
                handleHoldingsChange()
            }
            .onAppear {
                // Set up monitoring for portfolio changes
                setupPortfolioChangeMonitoring()
                lastPortfolioCount = portfolioManager.items.count
            }
            .onChange(of: portfolioManager.items.count) { oldCount, newCount in
                // Auto-refresh when portfolio count changes
                if oldCount != newCount && lastPortfolioCount != newCount {
                    lastPortfolioCount = newCount
                    print("📊 Portfolio count changed from \(oldCount) to \(newCount), triggering refresh...")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        handleHoldingsChange()
                    }
                }
            }
            .onDisappear {
                // Clean up any pending refresh tasks
                refreshTask?.cancel()
            }
        }
    }
    
    
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
    
    private var headerTitleView: some View {
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
    
    private var toolbarActions: some View {
        HStack(spacing: 16) {
            Button {
                Task { await refreshAllData() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.title3)
                    .foregroundStyle(.primary)
                    .rotationEffect(.degrees(isRefreshing || portfolioManager.isRefreshing ? 360 : 0))
                    .animation(.linear(duration: 1).repeatForever(autoreverses: false), 
                              value: isRefreshing || portfolioManager.isRefreshing)
            }
            .disabled(isRefreshing || portfolioManager.isRefreshing)
            
            Button("Add") {
                handleAddStock()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(isAddingStock || isRefreshing || portfolioManager.isRefreshing)
        }
    }
    
    private var content: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                if !portfolioManager.items.isEmpty {
                    portfolioOverviewSection
                    performanceMetricsSection
                    holdingsSection
                } else {
                    emptyStateSection
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
    }
    
    // MARK: - Consolidated Content Sections
    
    private var portfolioOverviewSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Main Portfolio Value Card
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Portfolio Value")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                        
                        Text(String(format: "$%.2f", portfolioManager.totalCurrentValue))
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
                                
                                Text(String(format: "$%.2f", portfolioManager.totalDailyChange))
                                    .font(.callout)
                                    .fontWeight(.bold)
                            }
                            
                            Text(String(format: "(%.2f%%)", portfolioManager.totalDailyChangePercentage))
                                .font(.caption2)
                                .fontWeight(.medium)
                        }
                        .foregroundStyle(portfolioManager.totalDailyChange >= 0 ? .green : .red)
                    }
                }
                
                // Return Performance Row
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
                                Text(String(format: "$%.2f", totalReturn))
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundStyle(totalReturn >= 0 ? .green : .red)
                                
                                Text(String(format: "(%@%.1f%%)", totalReturnPercentage >= 0 ? "+" : "", totalReturnPercentage))
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
                            
                            Text(String(format: "$%.2f", totalInvested))
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
    }
    
    private var performanceMetricsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Performance Metrics")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
            
            HStack(spacing: 12) {
                performanceMetricCard(
                    title: "Best Performer",
                    value: bestPerformingStock?.symbol ?? "—",
                    subtitle: bestPerformingStock != nil ? String(format: "+%.1f%%", bestPerformingStock?.dailyChange ?? 0) : "No data",
                    color: .green,
                    icon: "arrow.up.circle.fill"
                )
                
                performanceMetricCard(
                    title: "Worst Performer", 
                    value: worstPerformingStock?.symbol ?? "—",
                    subtitle: worstPerformingStock != nil ? String(format: "%.1f%%", worstPerformingStock?.dailyChange ?? 0) : "No data",
                    color: .red,
                    icon: "arrow.down.circle.fill"
                )
            }
            
            HStack(spacing: 12) {
                performanceMetricCard(
                    title: "Holdings",
                    value: "\(portfolioManager.items.count)",
                    subtitle: portfolioManager.items.count == 1 ? "Stock" : "Stocks",
                    color: .blue,
                    icon: "chart.pie.fill"
                )
                
                performanceMetricCard(
                    title: "Avg. Return",
                    value: portfolioManager.items.isEmpty ? "—" : String(format: "%.1f%%", averageReturn),
                    subtitle: "Per holding",
                    color: averageReturn >= 0 ? .green : .red,
                    icon: "chart.bar.fill"
                )
            }
        }
    }
    
    private func performanceMetricCard(title: String, value: String, subtitle: String, color: Color, icon: String) -> some View {
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
                    .foregroundStyle(.primary)
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
    
    private var averageReturn: Double {
        guard !portfolioManager.items.isEmpty else { return 0 }
        let totalReturnPercent = portfolioManager.items.compactMap { stock -> Double? in
            guard let purchasePrice = stock.purchasePrice,
                  let currentPrice = stock.currentPrice,
                  purchasePrice > 0 else { return nil }
            return ((currentPrice - purchasePrice) / purchasePrice) * 100
        }
        
        guard !totalReturnPercent.isEmpty else { return 0 }
        return totalReturnPercent.reduce(0, +) / Double(totalReturnPercent.count)
    }
    
    private var emptyStateSection: some View {
        VStack(spacing: 24) {
            Spacer()
                .frame(height: 40)
            
            VStack(spacing: 20) {
                Image(systemName: "chart.line.uptrend.xyaxis.circle")
                    .font(.system(size: 60))
                    .foregroundStyle(.secondary)
                
                VStack(spacing: 8) {
                    Text("Start Your Investment Journey")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)
                    
                    Text("Add stocks to track your portfolio performance and market trends")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                }
                
                Button(action: {
                    handleAddStock()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Your First Stock")
                    }
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                }
                .background(isAddingStock ? Color.secondary : Color.accentColor)
                .cornerRadius(12)
                .disabled(isAddingStock)
            }
            
            Spacer()
        }
        .padding(.horizontal, 24)
    }
    

    
    private var holdingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Holdings")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                
                Spacer()
                
                Text("\(portfolioManager.items.count) \(portfolioManager.items.count == 1 ? "stock" : "stocks")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            LazyVStack(spacing: 12) {
                ForEach(Array(portfolioManager.items.enumerated()), id: \.element.id) { index, stock in
                    enhancedStockRow(stock: stock, index: index)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button {
                                editingStock = EditingStock(stock: stock, index: index)
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(.blue)
                            
                            Button(role: .destructive) {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    portfolioManager.remove(at: index)
                                }
                                handleHoldingsChange()
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                            Button {
                                showingStockDetail = stock
                            } label: {
                                Label("Details", systemImage: "info.circle")
                            }
                            .tint(.green)
                        }
                }
            }
        }
    }
    
    private func enhancedStockRow(stock: StockItem, index: Int) -> some View {
        Button {
            showingStockDetail = stock
        } label: {
            HStack(spacing: 16) {
                // Stock Symbol Circle
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 50, height: 50)
                    
                    Text(stock.symbol.prefix(2).uppercased())
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)
                }
                
                // Stock Info
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(stock.symbol)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                        
                        if let name = stock.name {
                            Text("• \(name)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                    }
                    
                    HStack(spacing: 8) {
                        Text("\(String(format: "%.2f", stock.quantity)) shares")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        if let purchasePrice = stock.purchasePrice {
                            Text("• Avg: $\(String(format: "%.2f", purchasePrice))")
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
                            Text("$\(String(format: "%.2f", currentPrice))")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.primary)
                        } else {
                            Text("No Price")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Text("$\(String(format: "%.2f", stock.totalValue))")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                    }
                    
                    // Daily Change Badge
                    if let dailyChange = stock.dailyChange {
                        HStack(spacing: 4) {
                            Image(systemName: dailyChange >= 0 ? "arrow.up" : "arrow.down")
                                .font(.caption2)
                            
                            Text("\(String(format: "%.1f%%", dailyChange))")
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
                Button {
                    editingStock = EditingStock(stock: stock, index: index)
                } label: {
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
    
    // MARK: - Total Return Calculations
    
    /// Total amount invested (purchase price * shares for all holdings)
    private var totalInvested: Double {
        portfolioManager.items.reduce(0.0) { accumulator, stockItem in
            accumulator + ((stockItem.purchasePrice ?? 0) * stockItem.quantity)
        }
    }
    
    /// Total return in dollars (current value - total invested)
    private var totalReturn: Double {
        portfolioManager.totalCurrentValue - totalInvested
    }
    

    
    /// Total return percentage ((current value - invested) / invested * 100)
    private var totalReturnPercentage: Double {
        guard totalInvested > 0 else { return 0 }
        return (totalReturn / totalInvested) * 100
    }
    

    

    

    

    

    

    
    // MARK: - Helper Functions
    
    private func handleAddStock() {
        // Prevent duplicate taps
        guard !isAddingStock else { return }
        
        isAddingStock = true
        showingAddStock = true
        
        // Reset the flag after a short delay to prevent rapid successive taps
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isAddingStock = false
        }
    }
    
    private func refreshAllData() async {
        isRefreshing = true
        
        // Use the comprehensive refresh method
        await dataManager.forceRefreshAll()
        
        isRefreshing = false
    }
    
    private func handleHoldingsChange() {
        // Cancel any existing refresh task to debounce
        refreshTask?.cancel()
        
        // Create a new debounced refresh task
        refreshTask = Task {
            // Wait a bit to debounce multiple rapid changes
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            // Check if task was cancelled
            guard !Task.isCancelled else { return }
            
            // Automatically refresh all data when holdings change
            print("📊 Auto-refreshing all data due to portfolio changes...")
            await refreshAllData()
        }
    }
    
    private func setupPortfolioChangeMonitoring() {
        // This will help us detect changes in portfolio
        // The actual change detection will be handled in the UI actions
    }
}

// MARK: - Preview

#Preview {
    ModernMyInvestmentTab()
        .environmentObject(DataManager.shared)
}
