import SwiftUI

// MARK: - Local AI Stock Insight Data Model
struct LocalAIStockInsight {
    let symbol: String
    let aiMarketSignalScore: Double // 0-100 (composite)
    let profitLikelihood: Double // 0-100 (35% weight)
    let gainPotential: Double // 0-100 (25% weight) 
    let confidenceScore: Double // 0-100 (25% weight)
    let upsideChance: Double // 0-100 (15% weight)
    let timestamp: Date
    
    // Computed property for compatibility with validation
    var aiInsightScore: Double {
        let score = aiMarketSignalScore / 100.0 // Convert to 0-1 range for percentage formatting
        return max(0.0, min(1.0, score)) // Clamp to 0-1 range to prevent UI issues
    }
    
    // Validation computed properties to ensure values are in expected range
    var validatedProfitLikelihood: Double {
        max(0.0, min(100.0, profitLikelihood))
    }
    
    var validatedGainPotential: Double {
        max(0.0, min(100.0, gainPotential))
    }
    
    var validatedConfidenceScore: Double {
        max(0.0, min(100.0, confidenceScore))
    }
    
    var validatedUpsideChance: Double {
        max(0.0, min(100.0, upsideChance))
    }
}


@MainActor
struct IntegratedMyStocksTab: View {
    // MARK: - Portfolio Management
    @ObservedObject private var portfolioManager = UnifiedPortfolioManager.shared
    @StateObject private var dataManager = DataManager.shared
    
    // MARK: - AI Services
    @ObservedObject private var configManager = SecureConfigurationManager.shared
    @StateObject private var aiService = MultiProviderAIService()
    @StateObject private var marketingBriefingManager = MarketingBriefingManager.shared
    
    // MARK: - UI State
    @State private var showingAddStock = false
    @State private var showingStockDetail: StockItem?
    @State private var editingStock: EditingStock?
    @State private var isRefreshing = false
    @State private var refreshTask: Task<Void, Never>?
    
    // MARK: - AI State
    @State private var selectedProvider: AIProvider?
    @State private var aiProviderLoadingStates: [AIProvider: Bool] = [:]
    @State private var todayAISummary: String?
    @State private var stockInsights: [String: LocalAIStockInsight] = [:]
    @State private var marketingBriefing: DeepSeekManager.MarketingBriefing?
    @State private var aiLastUpdate: Date?
    @State private var isAILoading = false
    
    // MARK: - Supporting Types
    struct EditingStock: Identifiable, Equatable {
        let id = UUID()
        let stock: StockItem
        let index: Int
        
        static func == (lhs: EditingStock, rhs: EditingStock) -> Bool {
            lhs.id == rhs.id
        }
    }
    
    private var availableProviders: [AIProvider] {
        configManager.availableAIProviders as [AIProvider]
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                backgroundGradient
                content
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .refreshable { 
                await refreshAllData()
                await refreshAIData()
            }
            .task {
                // Auto-select first available provider
                if selectedProvider == nil, let firstProvider = availableProviders.first {
                    selectedProvider = firstProvider
                    await refreshAIData()
                }
            }
        }
        .fullScreenCover(isPresented: $showingAddStock) {
            AddStockView()
                .environmentObject(portfolioManager)
        }
        .sheet(item: $editingStock) { editingStock in
            EditStockView(stock: editingStock.stock, index: editingStock.index)
                .environmentObject(portfolioManager)
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
    
    // MARK: - Background
    private var backgroundGradient: some View {
        LinearGradient(
            colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.05)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
    
    // MARK: - Content
    private var content: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                headerSection
                
                // AI Provider Selection (if multiple providers available)
                if availableProviders.count > 1 {
                    aiProviderSelectionSection
                }
                
                // Today AI Summary
                if !availableProviders.isEmpty {
                    todayAISummarySection
                }
                
                portfolioSummarySection
                stocksListSection
                
                // AI Stock Insights (integrated with individual stocks)
                if !stockInsights.isEmpty {
                    aiStockInsightsSection
                }
                
                // AI Marketing Briefing
                if !availableProviders.isEmpty {
                    marketingBriefingSection
                }
            }
            .padding()
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("My Stocks")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    HStack(spacing: 4) {
                        if isRefreshing || isAILoading {
                            ProgressView()
                                .scaleEffect(0.7)
                        }
                        
                        if let lastUpdate = dataManager.lastUpdateTime ?? aiLastUpdate {
                            Text("Updated \(lastUpdate, style: .relative)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                Button {
                    showingAddStock = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.blue)
                }
            }
        }
    }
    
    // MARK: - AI Provider Selection
    private var aiProviderSelectionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("AI Analysis Provider")
                .font(.headline)
                .fontWeight(.semibold)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(availableProviders, id: \.self) { provider in
                        Button {
                            selectedProvider = provider
                            Task {
                                await refreshAIData()
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: provider.iconName)
                                    .foregroundStyle(provider.primaryColor)
                                
                                Text(provider.displayName)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                if aiProviderLoadingStates[provider] == true {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(selectedProvider == provider ? provider.primaryColor.opacity(0.2) : Color(.systemGray6))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(selectedProvider == provider ? provider.primaryColor : Color.clear, lineWidth: 2)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 1)
            }
        }
        .padding()
        .background(.regularMaterial)
        .cornerRadius(12)
    }
    
    // MARK: - Today AI Summary
    private var todayAISummarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: selectedProvider?.iconName ?? "brain.head.profile")
                    .foregroundStyle(selectedProvider?.primaryColor ?? .blue)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Today AI Summary")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    if let provider = selectedProvider {
                        Text("Powered by \(provider.displayName)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                if isAILoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            
            // Disclaimer
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.caption)
                
                Text("Experimental AI signal. Not investment advice.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.orange.opacity(0.1))
            .cornerRadius(8)
            
            if let summary = todayAISummary {
                Text(summary)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
            } else if isAILoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Generating AI summary...")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .center)
            } else if portfolioManager.items.isEmpty {
                Text("Add stocks to your portfolio to generate AI summary")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "brain.head.profile")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    
                    Text("AI summary will appear here")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    
                    if selectedProvider == nil {
                        Text("Configure AI providers in Settings to enable analysis")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .padding()
        .background(.regularMaterial)
        .cornerRadius(12)
    }
    
    // MARK: - Portfolio Summary
    private var portfolioSummarySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Portfolio Overview")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                PortfolioMetricCard(
                    title: "Total Value",
                    value: portfolioManager.totalCurrentValue.formatted(.currency(code: "USD")),
                    change: portfolioManager.totalCurrentValue - portfolioManager.initialValue,
                    changePercent: portfolioManager.earningsPercent ?? 0.0,
                    icon: "dollarsign.circle.fill",
                    color: .blue
                )
                
                PortfolioMetricCard(
                    title: "Today's Change",
                    value: portfolioManager.totalDailyChange.formatted(.currency(code: "USD")),
                    change: portfolioManager.totalDailyChange,
                    changePercent: portfolioManager.totalDailyChangePercentage,
                    icon: "chart.line.uptrend.xyaxis",
                    color: portfolioManager.totalDailyChange >= 0 ? .green : .red
                )
            }
        }
        .padding()
        .background(.regularMaterial)
        .cornerRadius(12)
    }
    
    // MARK: - Stocks List
    private var stocksListSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Holdings")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("\(portfolioManager.items.count) stocks")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            if portfolioManager.items.isEmpty {
                emptyStateView
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(Array(portfolioManager.items.enumerated()), id: \.element.id) { index, stock in
                        CustomStockRowView(stock: stock, aiInsight: stockInsights[stock.symbol]) {
                            showingStockDetail = stock
                        }
                        .onLongPressGesture {
                            editingStock = EditingStock(stock: stock, index: index)
                        }
                    }
                }
            }
        }
        .padding()
        .background(.regularMaterial)
        .cornerRadius(12)
    }
    
    // MARK: - AI Stock Insights Summary
    private var aiStockInsightsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "tablecells")
                    .foregroundStyle(selectedProvider?.primaryColor ?? .purple)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("AI Stock Insights Summary")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    if let provider = selectedProvider {
                        Text("Powered by \(provider.displayName)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
            }
            
            // Disclaimer
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.caption)
                
                Text("Experimental AI signal. Not investment advice.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.orange.opacity(0.1))
            .cornerRadius(8)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(Array(stockInsights.keys.sorted()), id: \.self) { symbol in
                    if let insight = stockInsights[symbol] {
                        AIInsightCard(symbol: symbol, insight: insight)
                    }
                }
            }
        }
        .padding()
        .background(.regularMaterial)
        .cornerRadius(12)
    }
    
    // MARK: - Marketing Briefing
    private var marketingBriefingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundStyle(selectedProvider?.primaryColor ?? .orange)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("AI Marketing Briefing")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    if let provider = selectedProvider {
                        Text("Powered by \(provider.displayName)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                if isAILoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            
            // Disclaimer
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.caption)
                
                Text("Experimental AI signal. Not investment advice.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.orange.opacity(0.1))
            .cornerRadius(8)
            
            if let briefing = marketingBriefing {
                VStack(alignment: .leading, spacing: 12) {
                    if !briefing.overview.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Market Overview")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Text(briefing.overview)
                                .font(.body)
                                .foregroundStyle(.primary)
                        }
                    }
                    
                    if !briefing.keyDrivers.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Key Drivers")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Text(briefing.keyDrivers)
                                .font(.body)
                                .foregroundStyle(.primary)
                        }
                    }
                    
                    if !briefing.highlightsAndActivity.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Highlights & Activity")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Text(briefing.highlightsAndActivity)
                                .font(.body)
                                .foregroundStyle(.primary)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
            } else if isAILoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Generating marketing briefing...")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .center)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    
                    Text("Marketing briefing will appear here")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    
                    if selectedProvider == nil {
                        Text("Configure AI providers in Settings to enable briefing")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .padding()
        .background(.regularMaterial)
        .cornerRadius(12)
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.pie")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            
            Text("No Stocks Yet")
                .font(.headline)
                .fontWeight(.medium)
            
            Text("Add your first stock to start tracking your portfolio and get AI-powered insights.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Button {
                showingAddStock = true
            } label: {
                Label("Add Stock", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.vertical, 40)
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Toolbar
    private var toolbarContent: some ToolbarContent {
        Group {
            ToolbarItem(placement: .topBarLeading) {
                ToolbarAppIconView(showAppName: true)
            }
            
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task {
                        await refreshAllData()
                        await refreshAIData()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(isRefreshing || isAILoading)
            }
        }
    }
    
    // MARK: - Data Management
    private func refreshAllData() async {
        guard !isRefreshing else { return }
        
        isRefreshing = true
        defer { isRefreshing = false }
        
        refreshTask?.cancel()
        refreshTask = Task {
            await dataManager.refreshAll()
            await portfolioManager.refreshAllPrices()
        }
        
        await refreshTask?.value
    }
    
    private func refreshAIData() async {
        guard let selectedProvider = selectedProvider, !portfolioManager.items.isEmpty else { return }
        
        isAILoading = true
        aiProviderLoadingStates[selectedProvider] = true
        defer { 
            isAILoading = false
            aiProviderLoadingStates[selectedProvider] = false
        }
        
        // Convert portfolio items to AIStock format
        let aiStocks = portfolioManager.items.map { stock in
            AIStock(
                symbol: stock.symbol,
                name: stock.name ?? stock.symbol, // Using symbol as name if no name
                price: stock.currentPrice ?? 0,
                change: (stock.currentPrice ?? 0) - (stock.purchasePrice ?? 0),
                changePercent: stock.dailyChange ?? 0
            )
        }
        
        // Generate insights using the existing MultiProviderAIService
        let portfolioInsights = await aiService.generateMultiProviderInsights(for: aiStocks)
        
        // Extract data for the selected provider
        if let insights = portfolioInsights[selectedProvider] {
            todayAISummary = insights.summary
            aiLastUpdate = insights.timestamp
        }
        
        // Generate individual stock insights
        var newStockInsights: [String: LocalAIStockInsight] = [:]
        for stock in portfolioManager.items {
            do {
                if let enhancedInsight = try await aiService.generateStockPrediction(for: stock.symbol, using: selectedProvider) {
                    // Convert EnhancedAIInsight to LocalAIStockInsight
                    let aiStockInsight = LocalAIStockInsight(
                        symbol: stock.symbol,
                        aiMarketSignalScore: enhancedInsight.marketSignal.compositeScore,
                        profitLikelihood: enhancedInsight.marketSignal.todaysProfitLikelihood,
                        gainPotential: enhancedInsight.marketSignal.forecastedGainPotential,
                        confidenceScore: enhancedInsight.marketSignal.profitConfidenceScore,
                        upsideChance: enhancedInsight.marketSignal.projectedUpsideChance,
                        timestamp: enhancedInsight.timestamp
                    )
                    
                    // Debug logging to track potential range issues
                    print("AI Insight for \(stock.symbol):")
                    print("  Composite Score: \(enhancedInsight.marketSignal.compositeScore)")
                    print("  Profit Likelihood: \(enhancedInsight.marketSignal.todaysProfitLikelihood)")
                    print("  Gain Potential: \(enhancedInsight.marketSignal.forecastedGainPotential)")
                    print("  Confidence: \(enhancedInsight.marketSignal.profitConfidenceScore)")
                    print("  Upside Chance: \(enhancedInsight.marketSignal.projectedUpsideChance)")
                    print("  Computed AI Score: \(aiStockInsight.aiInsightScore)")
                    
                    newStockInsights[stock.symbol] = aiStockInsight
                }
            } catch {
                print("Failed to generate stock insight for \(stock.symbol): \(error)")
            }
        }
        stockInsights = newStockInsights
        
        // Generate real marketing briefing using portfolio stocks
        let deepSeekStocks = portfolioManager.items.map { stock in
            DeepSeekManager.Stock(
                symbol: stock.symbol,
                currentPrice: stock.currentPrice ?? 0.0,
                previousClose: stock.previousClose ?? stock.currentPrice ?? 0.0,
                quantity: stock.quantity
            )
        }
        
        // Create a settings manager instance to check API key validity
        let settingsManager = SettingsManager.shared
        
        await marketingBriefingManager.generateBriefing(for: deepSeekStocks, settingsManager: settingsManager)
        marketingBriefing = marketingBriefingManager.currentBriefing
        
        aiLastUpdate = Date()
    }
}

// MARK: - Supporting Views
struct PortfolioMetricCard: View {
    let title: String
    let value: String
    let change: Double
    let changePercent: Double
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                
                Spacer()
                
                Image(systemName: change >= 0 ? "arrow.up.right" : "arrow.down.right")
                    .font(.caption)
                    .foregroundStyle(change >= 0 ? .green : .red)
            }
            
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Text(value)
                .font(.headline)
                .fontWeight(.semibold)
            
            Text("\(change >= 0 ? "+" : "")\(changePercent.formatted(.percent.precision(.fractionLength(2))))")
                .font(.caption)
                .foregroundStyle(change >= 0 ? .green : .red)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct CustomStockRowView: View {
    let stock: StockItem
    let aiInsight: LocalAIStockInsight?
    let action: () -> Void
    
    private var gainLoss: Double {
        guard let currentPrice = stock.currentPrice,
              let purchasePrice = stock.purchasePrice else { return 0 }
        return (currentPrice - purchasePrice) * stock.quantity
    }
    
    private var gainLossPercentage: Double {
        guard let currentPrice = stock.currentPrice,
              let purchasePrice = stock.purchasePrice,
              purchasePrice > 0 else { return 0 }
        return ((currentPrice - purchasePrice) / purchasePrice) * 100
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(stock.symbol)
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        if aiInsight != nil {
                            Image(systemName: "brain.head.profile")
                                .font(.caption)
                                .foregroundStyle(.blue)
                        }
                    }
                    
                    Text("\(stock.quantity.formatted(.number.precision(.fractionLength(0)))) shares")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    if let insight = aiInsight {
                        Text("AI Score: \(insight.aiInsightScore.formatted(.percent.precision(.fractionLength(0))))")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.blue.opacity(0.1))
                            .cornerRadius(4)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text((stock.currentPrice ?? 0).formatted(.currency(code: "USD")))
                        .font(.headline)
                        .fontWeight(.medium)
                    
                    Text("\(gainLoss >= 0 ? "+" : "")\(gainLoss.formatted(.currency(code: "USD")))")
                        .font(.caption)
                        .foregroundStyle(gainLoss >= 0 ? .green : .red)
                    
                    Text("\(gainLossPercentage >= 0 ? "+" : "")\(gainLossPercentage.formatted(.percent.precision(.fractionLength(2))))")
                        .font(.caption2)
                        .foregroundStyle(gainLossPercentage >= 0 ? .green : .red)
                }
            }
        }
        .buttonStyle(.plain)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct AIInsightCard: View {
    let symbol: String
    let insight: LocalAIStockInsight
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(symbol)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Image(systemName: "brain.head.profile")
                    .foregroundStyle(.blue)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("AI Score")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(insight.aiInsightScore.formatted(.percent.precision(.fractionLength(0))))
                        .font(.caption2)
                        .fontWeight(.medium)
                }
                
                HStack {
                    Text("Profit Likelihood")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text((insight.validatedProfitLikelihood / 100.0).formatted(.percent.precision(.fractionLength(0))))
                        .font(.caption2)
                        .fontWeight(.medium)
                }
                
                HStack {
                    Text("Confidence")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text((insight.validatedConfidenceScore / 100.0).formatted(.percent.precision(.fractionLength(0))))
                        .font(.caption2)
                        .fontWeight(.medium)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

#Preview {
    IntegratedMyStocksTab()
        .environmentObject(UnifiedPortfolioManager.shared)
}
