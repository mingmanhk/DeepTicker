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
            LazyVStack(spacing: 16) {
                if !portfolioManager.items.isEmpty {
                    portfolioHeaderSection
                    quickStatsSection
                    holdingsSection
                } else {
                    emptyStateSection
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
    }
    
    private var holdingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Holdings")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                
                Spacer()
                
                Text("\(portfolioManager.items.count) stocks")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            LazyVStack(spacing: 8) {
                ForEach(Array(portfolioManager.items.enumerated()), id: \.element.id) { index, stock in
                    stockRow(stock: stock, index: index)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                portfolioManager.remove(at: index)
                                // Trigger refresh after deletion
                                handleHoldingsChange()
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            }
        }
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
    
    private var portfolioHeaderSection: some View {
        VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Portfolio Value")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                    
                    Text("$\(portfolioManager.totalCurrentValue, specifier: "%.2f")")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .minimumScaleFactor(0.8)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Today")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    HStack(spacing: 4) {
                        Image(systemName: portfolioManager.totalDailyChange >= 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.caption2)
                            .fontWeight(.semibold)
                        
                        VStack(alignment: .trailing, spacing: 1) {
                            Text("$\(portfolioManager.totalDailyChange, specifier: "%.2f")")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            
                            Text("(\(portfolioManager.totalDailyChangePercentage, specifier: "%.2f")%)")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                    }
                    .foregroundStyle(portfolioManager.totalDailyChange >= 0 ? .green : .red)
                }
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
    
    private var quickStatsSection: some View {
        HStack(spacing: 12) {
            quickStatCard(
                title: "Best",
                value: bestPerformingStock?.symbol ?? "—",
                change: bestPerformingStock?.dailyChange ?? 0,
                color: .green
            )
            
            quickStatCard(
                title: "Worst", 
                value: worstPerformingStock?.symbol ?? "—",
                change: worstPerformingStock?.dailyChange ?? 0,
                color: .red
            )
            
            quickStatCard(
                title: "Holdings",
                value: "\(portfolioManager.items.count)",
                change: nil,
                color: .blue
            )
        }
    }
    
    private func quickStatCard(title: String, value: String, change: Double?, color: Color) -> some View {
        VStack(spacing: 6) {
            HStack {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                
                Text(title)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.callout)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                if let change = change {
                    Text("\(change >= 0 ? "+" : "")\(change, specifier: "%.1f")%")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(change >= 0 ? .green : .red)
                } else {
                    Text(" ")
                        .font(.caption2)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
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
    
    // MARK: - Portfolio Summary Panel
    
    private var portfolioSummaryPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "briefcase.fill")
                        .foregroundStyle(.blue)
                        .font(.title2)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Portfolio Summary")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Text("\(portfolioManager.items.count) Holdings")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
            }
            
            HStack(spacing: 16) {
                // Total Value
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Text("Total Value")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Image(systemName: "dollarsign.circle.fill")
                            .font(.caption2)
                            .foregroundStyle(.green)
                    }
                    
                    Text("$\(portfolioManager.totalCurrentValue, specifier: "%.2f")")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)
                        .minimumScaleFactor(0.8)
                }
                
                Divider()
                    .frame(height: 60)
                
                // Daily Change
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Text("Today's Change")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Image(systemName: portfolioManager.totalDailyChange >= 0 ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                            .font(.caption2)
                            .foregroundStyle(portfolioManager.totalDailyChange >= 0 ? .green : .red)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("$\(portfolioManager.totalDailyChange, specifier: "%.2f")")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(portfolioManager.totalDailyChange >= 0 ? .green : .red)
                        
                        Text("(\(portfolioManager.totalDailyChangePercentage, specifier: "%.2f")%)")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(portfolioManager.totalDailyChange >= 0 ? .green : .red)
                    }
                }
            }
        }
        .padding()
        .background(.regularMaterial)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
        )
    }
    
    // MARK: - Portfolio Performance Panel
    
    private var portfolioPerformancePanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .foregroundStyle(.green)
                        .font(.title2)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Performance")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        if let earningsPercent = portfolioManager.earningsPercent {
                            Text("Overall \(earningsPercent >= 0 ? "Gain" : "Loss")")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                Spacer()
            }
            
            if portfolioManager.initialValue > 0 {
                HStack(spacing: 20) {
                    // Initial Investment
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Initial Investment")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Text("$\(portfolioManager.initialValue, specifier: "%.2f")")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                    }
                    
                    // Total Earnings
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Total Earnings")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        let earnings = portfolioManager.totalCurrentValue - portfolioManager.initialValue
                        HStack(spacing: 4) {
                            Text("$\(earnings, specifier: "%.2f")")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundStyle(earnings >= 0 ? .green : .red)
                            
                            if let earningsPercent = portfolioManager.earningsPercent {
                                Text("(\(earningsPercent, specifier: "%.1f")%)")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundStyle(earnings >= 0 ? .green : .red)
                            }
                        }
                    }
                    
                    Spacer()
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "info.circle")
                        .font(.title2)
                        .foregroundStyle(.orange)
                    
                    Text("Add purchase prices to see performance")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
        }
        .padding()
        .background(.regularMaterial)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.green.opacity(0.3), lineWidth: 1)
        )
    }
    
    // MARK: - Stocks List Panel
    
    private var stocksListPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "list.bullet.rectangle.portrait")
                        .foregroundStyle(.purple)
                        .font(.title2)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Holdings")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Text("\(portfolioManager.items.count) stocks")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
            }
            
            LazyVStack(spacing: 12) {
                ForEach(Array(portfolioManager.items.enumerated()), id: \.element.id) { index, stock in
                    stockRow(stock: stock, index: index)
                }
            }
        }
        .padding()
        .background(.regularMaterial)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.purple.opacity(0.3), lineWidth: 1)
        )
    }
    
    private func stockRow(stock: StockItem, index: Int) -> some View {
        Button {
            showingStockDetail = stock
        } label: {
            HStack(spacing: 12) {
                // Symbol and Name
                VStack(alignment: .leading, spacing: 4) {
                    Text(stock.symbol)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                    
                    if let name = stock.name {
                        Text(name)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    } else {
                        Text("\(stock.quantity, specifier: "%.2f") shares")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                // Price and Change
                VStack(alignment: .trailing, spacing: 4) {
                    if let currentPrice = stock.currentPrice {
                        Text("$\(currentPrice, specifier: "%.2f")")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                        
                        if let dailyChange = stock.dailyChange {
                            HStack(spacing: 4) {
                                Image(systemName: dailyChange >= 0 ? "arrow.up" : "arrow.down")
                                    .font(.caption2)
                                Text("\(dailyChange, specifier: "%.2f")%")
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            .foregroundStyle(dailyChange >= 0 ? .green : .red)
                        }
                    } else {
                        Text("No Price")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                // Total Value
                VStack(alignment: .trailing, spacing: 4) {
                    Text("$\(stock.totalValue, specifier: "%.2f")")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                    
                    Text("Value")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                
                // Edit Button
                Button {
                    editingStock = EditingStock(stock: stock, index: index)
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(12)
            .background(.ultraThinMaterial)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Empty Portfolio Panel
    
    private var emptyPortfolioPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle")
                        .foregroundStyle(.gray)
                        .font(.title2)
                    
                    Text("Start Your Portfolio")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                
                Spacer()
            }
            
            VStack(spacing: 20) {
                Image(systemName: "chart.line.uptrend.xyaxis.circle")
                    .font(.system(size: 60))
                    .foregroundStyle(.secondary)
                
                VStack(spacing: 8) {
                    Text("No Stocks Yet")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                    
                    Text("Add your first stock to start tracking your investment portfolio")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                Button(action: {
                    handleAddStock()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                        Text("Add Stock")
                    }
                    .font(.headline)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isAddingStock)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
        }
        .padding()
        .background(.regularMaterial)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
    }
    
    // MARK: - Toolbar Buttons
    
    private var refreshButton: some View {
        Button {
            Task {
                await refreshAllData()
            }
        } label: {
            if isRefreshing || portfolioManager.isRefreshing {
                ProgressView()
                    .scaleEffect(0.8)
            } else {
                Image(systemName: "arrow.clockwise")
            }
        }
        .disabled(isRefreshing || portfolioManager.isRefreshing)
    }
    
    private var addStockButton: some View {
        Button {
            showingAddStock = true
        } label: {
            Image(systemName: "plus")
        }
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
