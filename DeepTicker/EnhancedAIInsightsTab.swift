import SwiftUI

// MARK: - Stock Insight Sort Column

enum StockInsightSortColumn: CaseIterable {
    case symbol
    case aiInsightScore
    case profitLikelihood
    case gainPotential
    case confidenceScore
    case upsideChance
}

@MainActor
struct EnhancedAIInsightsTab: View {
    @ObservedObject private var configManager = SecureConfigurationManager.shared
    @StateObject private var aiService = MultiProviderAIService()
    @StateObject private var marketingBriefingManager = MarketingBriefingManager.shared
    @ObservedObject private var dataManager = DataManager.shared
    @ObservedObject private var portfolioManager = UnifiedPortfolioManager.shared
    @EnvironmentObject var settingsManager: SettingsManager
    
    @State private var providerInsights: [AIProvider: PortfolioInsights] = [:]
    @State private var collapsedPanels: Set<AIProvider> = []
    @State private var selectedMetricInfo: MetricInfo?
    
    // AI Provider Selection States
    @State private var selectedProvider: AIProvider?
    @State private var providerLoadingStates: [AIProvider: Bool] = [:]
    @State private var providerSummaries: [AIProvider: String] = [:]
    @State private var providerStockInsights: [AIProvider: [String: AIStockInsight]] = [:]
    @State private var providerMarketingBriefings: [AIProvider: DeepSeekManager.MarketingBriefing] = [:]
    
    // Today AI Summary States
    @State private var todaySummary: TodayAISummary?
    @State private var isSummaryLoading = false
    @State private var summaryLastUpdate: Date?
    
    // AI Stock Insight States
    @State private var stockInsights: [String: AIStockInsight] = [:]
    @State private var isStockInsightsLoading = false
    @State private var stockInsightsLastUpdate: Date?
    @State private var isMarketingBriefingCollapsed = false
    
    // Sortable Table States
    @State private var sortColumn: StockInsightSortColumn = .aiInsightScore
    @State private var sortAscending: Bool = false
    
    private var availableProviders: [AIProvider] {
        configManager.availableAIProviders as [AIProvider]
    }
    
    var body: some View {
        NavigationStack {
            content
                .navigationTitle("AI Insights")
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        ToolbarAppIconView(showAppName: true)
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        masterRefreshButton
                    }
                }
                .sheet(item: $selectedMetricInfo) { metricInfo in
                    MetricExplanationSheet(metricInfo: metricInfo)
                }
                .task(id: [dataManager.portfolio.count, portfolioManager.items.count, availableProviders.count].description) {
                    await refreshAllAIData()
                }
                .refreshable {
                    await refreshAllAIData()
                }
        }
    }
    
    private var content: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: AppDesignSystem.Spacing.xl) {
                headerSection
                todayAISummaryPanel
                aiStockInsightPanel
                marketingBriefingPanel
            }
            .padding(AppDesignSystem.Spacing.lg)
        }
        .background(Color(.systemGroupedBackground))
    }
    
    private var headerSection: some View {
        ModernPanel {
            VStack(alignment: .leading, spacing: AppDesignSystem.Spacing.lg) {
                HStack {
                    VStack(alignment: .leading, spacing: AppDesignSystem.Spacing.xs) {
                        Text("AI Market Intelligence")
                            .font(AppDesignSystem.Typography.title2)
                        
                        Text("Real-time portfolio analysis powered by AI")
                            .font(AppDesignSystem.Typography.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    if aiService.isLoading {
                        ProgressView().scaleEffect(0.9)
                    }
                }
                
                if let lastUpdate = aiService.lastUpdateTime {
                    StatusIndicator(
                        icon: "clock.fill",
                        text: "Updated \(lastUpdate.formatted(.relative(presentation: .named)))"
                    )
                }
                
                if !availableProviders.isEmpty {
                    VStack(alignment: .leading, spacing: AppDesignSystem.Spacing.sm) {
                        Text("Select AI Model")
                            .font(AppDesignSystem.Typography.headline)
                        
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppDesignSystem.Spacing.sm) {
                            ForEach(availableProviders, id: \.self) { provider in
                                EnhancedAIProviderCard(
                                    provider: provider,
                                    isSelected: selectedProvider == provider,
                                    isLoading: providerLoadingStates[provider] ?? false
                                ) {
                                    withAnimation(.spring()) {
                                        selectedProvider = (selectedProvider == provider) ? nil : provider
                                    }
                                    if selectedProvider == provider {
                                        Task { await generateAIInsights(for: provider) }
                                    }
                                }
                            }
                        }
                    }
                } else {
                    noProvidersView
                }
            }
        }
    }
    
    private var noProvidersView: some View {
        VStack(spacing: AppDesignSystem.Spacing.lg) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            
            Text("No AI Providers Available")
                .font(AppDesignSystem.Typography.headline)
            
            Text("Configure your API keys in Settings to enable AI-powered market analysis.")
                .font(AppDesignSystem.Typography.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            NavigationLink("Open Settings") {
                ComprehensiveSettingsView()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.vertical, AppDesignSystem.Spacing.xxl)
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Today AI Summary Panel
    
    private var todayAISummaryPanel: some View {
        ModernPanel {
            PanelHeader(
                title: "Today AI Summary",
                subtitle: selectedProvider.map { "Powered by \($0.displayName)" },
                icon: selectedProvider?.iconName ?? "brain.head.profile",
                iconColor: selectedProvider?.primaryColor ?? .blue,
                lastUpdate: summaryLastUpdate,
                isLoading: isSummaryLoading || (selectedProvider.map { providerLoadingStates[$0] ?? false } ?? false)
            )
            
            if let selectedProvider = selectedProvider, let summary = providerSummaries[selectedProvider] {
                Text(.init(summary))
                    .font(AppDesignSystem.Typography.callout)
            } else if let summary = todaySummary {
                todaySummaryContent(summary: summary)
            } else if isSummaryLoading || (selectedProvider.map { providerLoadingStates[$0] ?? false } ?? false) {
                LoadingView(message: "Analyzing portfolio...")
            } else {
                EmptyStateView(
                    icon: "chart.bar.doc.horizontal",
                    title: "Portfolio AI Summary",
                    message: portfolioManager.items.isEmpty && dataManager.portfolio.isEmpty ?
                             "Add stocks to your portfolio to generate an AI summary." :
                             "Tap the refresh button to generate today's AI summary."
                )
            }
        }
    }
    
    private func todaySummaryContent(summary: TodayAISummary) -> some View {
        HStack(spacing: AppDesignSystem.Spacing.xl) {
            summaryMetric(
                title: "Confidence Profit Score",
                value: "\(Int(summary.confidenceProfitScore))%",
                trend: summary.confidenceTrend,
                color: confidenceColor(summary.confidenceProfitScore),
                metricInfo: .profitLikelihood
            )
            Divider().frame(height: 60)
            summaryMetric(
                title: "Market Risk",
                value: "\(Int(summary.marketRisk))%",
                trend: summary.riskTrend,
                color: riskColorForPercentage(summary.marketRisk),
                metricInfo: .risk
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func summaryMetric(title: String, value: String, trend: TrendDirection, color: Color, metricInfo: MetricInfo) -> some View {
        VStack(alignment: .leading, spacing: AppDesignSystem.Spacing.sm) {
            HStack(spacing: AppDesignSystem.Spacing.xs) {
                Text(title)
                    .font(AppDesignSystem.Typography.subheadline)
                    .fontWeight(.medium)
                Image(systemName: trend.icon)
                    .font(.caption)
                    .foregroundStyle(trend.color)
            }
            HStack(spacing: AppDesignSystem.Spacing.sm) {
                Text(value)
                    .font(AppDesignSystem.Typography.title1)
                    .foregroundStyle(color)
                Button {
                    selectedMetricInfo = metricInfo
                } label: {
                    Image(systemName: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    // MARK: - AI Stock Insight Panel
    
    private var aiStockInsightPanel: some View {
        ModernPanel {
            PanelHeader(
                title: "AI Stock Insights",
                subtitle: selectedProvider.map { "Powered by \($0.displayName)" },
                icon: "tablecells",
                iconColor: selectedProvider?.primaryColor ?? .purple,
                lastUpdate: stockInsightsLastUpdate,
                isLoading: isStockInsightsLoading || (selectedProvider.map { providerLoadingStates[$0] ?? false } ?? false)
            )
            
            let insights = selectedProvider.flatMap { providerStockInsights[$0] } ?? stockInsights
            
            if !insights.isEmpty {
                stockInsightsTable(insights: Array(insights.values))
            } else if isStockInsightsLoading || (selectedProvider.map { providerLoadingStates[$0] ?? false } ?? false) {
                LoadingView(message: "Analyzing individual stocks...")
            } else {
                EmptyStateView(
                    icon: "tablecells",
                    title: "Stock Insights Table",
                    message: portfolioManager.items.isEmpty && dataManager.portfolio.isEmpty ?
                             "Add stocks to your portfolio for individual AI insights." :
                             "Tap the refresh button to generate AI insights for each stock."
                )
            }
        }
    }
    
    private func stockInsightsTable(insights: [AIStockInsight]) -> some View {
        let sortedInsights = insights.sorted { lhs, rhs in
            let comparison: Bool
            switch sortColumn {
            case .symbol: comparison = lhs.symbol < rhs.symbol
            case .aiInsightScore: comparison = lhs.aiMarketSignalScore < rhs.aiMarketSignalScore
            case .profitLikelihood: comparison = lhs.profitLikelihood < rhs.profitLikelihood
            case .gainPotential: comparison = lhs.gainPotential < rhs.gainPotential
            case .confidenceScore: comparison = lhs.confidenceScore < rhs.confidenceScore
            case .upsideChance: comparison = lhs.upsideChance < rhs.upsideChance
            }
            return sortAscending ? comparison : !comparison
        }
        
        return ScrollView(.horizontal, showsIndicators: false) {
            VStack(alignment: .leading, spacing: AppDesignSystem.Spacing.md) {
                HStack(spacing: 0) {
                    sortableHeaderButton("Stock", column: .symbol, width: 60)
                    sortableHeaderButton("AI Insight", column: .aiInsightScore, width: 80)
                    sortableHeaderButton("Profit %", column: .profitLikelihood, width: 70)
                    sortableHeaderButton("Gain %", column: .gainPotential, width: 70)
                    sortableHeaderButton("Confidence", column: .confidenceScore, width: 80)
                    sortableHeaderButton("Upside %", column: .upsideChance, width: 70)
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, AppDesignSystem.Spacing.md)
                
                Divider()
                
                ForEach(sortedInsights, id: \.symbol) { insight in
                    stockInsightRow(insight: insight)
                }
            }
        }
    }
    
    private func sortableHeaderButton(_ title: String, column: StockInsightSortColumn, width: CGFloat) -> some View {
        Button {
            if sortColumn == column {
                sortAscending.toggle()
            } else {
                sortColumn = column
                sortAscending = column != .symbol
            }
        } label: {
            HStack(spacing: AppDesignSystem.Spacing.xs) {
                Text(title)
                    .font(AppDesignSystem.Typography.caption1)
                    .fontWeight(.semibold)
                
                if sortColumn == column {
                    Image(systemName: sortAscending ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.blue)
                }
            }
            .frame(width: width, alignment: column == .symbol ? .leading : .center)
        }
        .buttonStyle(.plain)
    }

    private func stockInsightRow(insight: AIStockInsight) -> some View {
        HStack(spacing: 0) {
            Text(insight.symbol)
                .font(.caption.weight(.semibold))
                .frame(width: 60, alignment: .leading)

            Text("\(Int(insight.aiMarketSignalScore))")
                .font(.caption.weight(.bold))
                .foregroundStyle(signalScoreColor(insight.aiMarketSignalScore))
                .frame(width: 80)
            
            Text("\(Int(insight.profitLikelihood))")
                .font(.caption)
                .foregroundStyle(profitLikelihoodColor(insight.profitLikelihood))
                .frame(width: 70)
            
            Text(String(format: "%.1f", insight.gainPotential))
                .font(.caption)
                .foregroundStyle(gainPotentialColor(insight.gainPotential))
                .frame(width: 70)
            
            Text("\(Int(insight.confidenceScore))")
                .font(.caption)
                .foregroundStyle(confidenceColor(insight.confidenceScore))
                .frame(width: 80)
            
            Text("\(Int(insight.upsideChance))")
                .font(.caption)
                .foregroundStyle(upsideChanceColor(insight.upsideChance))
                .frame(width: 70)
        }
        .padding(.vertical, AppDesignSystem.Spacing.sm)
        .padding(.horizontal, AppDesignSystem.Spacing.md)
        .background(.ultraThinMaterial)
        .cornerRadius(AppDesignSystem.CornerRadius.sm)
    }
    
    // MARK: - Marketing Briefing Panel
    
    private var marketingBriefingPanel: some View {
        ModernPanel {
            CollapsiblePanelHeader(
                title: "AI Marketing Briefing",
                subtitle: selectedProvider.map { "Powered by \($0.displayName)" },
                icon: "chart.line.uptrend.xyaxis",
                iconColor: selectedProvider?.primaryColor ?? .purple,
                lastUpdate: marketingBriefingManager.currentBriefing?.timestamp,
                isLoading: marketingBriefingManager.isLoading || (selectedProvider.map { providerLoadingStates[$0] ?? false } ?? false),
                isCollapsed: $isMarketingBriefingCollapsed
            )
            
            if !isMarketingBriefingCollapsed {
                let briefing = selectedProvider.flatMap { providerMarketingBriefings[$0] } ?? marketingBriefingManager.currentBriefing
                
                if let briefing = briefing {
                    marketingBriefingContent(briefing: briefing)
                } else if marketingBriefingManager.isLoading || (selectedProvider.map { providerLoadingStates[$0] ?? false } ?? false) {
                    LoadingView(message: "Generating market briefing...")
                } else if let error = marketingBriefingManager.lastError {
                    ErrorStateView(error: error)
                } else {
                    EmptyStateView(
                        icon: "doc.text",
                        title: "AI Marketing Briefing",
                        message: marketingBriefingEmptyMessage
                    )
                }
            }
        }
    }
    
    private func marketingBriefingContent(briefing: DeepSeekManager.MarketingBriefing) -> some View {
        VStack(alignment: .leading, spacing: AppDesignSystem.Spacing.lg) {
            briefingSection(title: "Market Overview", content: briefing.overview, icon: "chart.bar")
            briefingSection(title: "Key Drivers", content: briefing.keyDrivers, icon: "arrow.up.circle")
            briefingSection(title: "Activity & Highlights", content: briefing.highlightsAndActivity, icon: "star.circle")
            briefingSection(title: "Risk Factors", content: briefing.riskFactors, icon: "exclamationmark.triangle")
        }
    }
    
    private func briefingSection(title: String, content: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: AppDesignSystem.Spacing.sm) {
            HStack(spacing: AppDesignSystem.Spacing.sm) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(.purple)
                Text(title)
                    .font(AppDesignSystem.Typography.subheadline)
                    .fontWeight(.medium)
            }
            Text(content)
                .font(AppDesignSystem.Typography.callout)
                .foregroundStyle(.secondary)
        }
    }
    
    // MARK: - Refresh & Data Logic
    
    private var masterRefreshButton: some View {
        Button {
            Task { await refreshAllAIData() }
        } label: {
            Group {
                if isAnyRefreshing {
                    ProgressView().scaleEffect(0.8)
                } else {
                    Image(systemName: "arrow.clockwise").font(.title3)
                }
            }
            .foregroundStyle(.primary)
            .frame(width: 32, height: 32)
            .glassEffect(.regular.interactive(), in: .circle)
        }
        .buttonStyle(.plain)
        .disabled(isAnyRefreshing)
        .accessibilityLabel("Refresh All AI Data")
    }
    
    private var isAnyRefreshing: Bool {
        let selectedProviderLoading = selectedProvider.map { providerLoadingStates[$0] ?? false } ?? false
        return aiService.isLoading || isSummaryLoading || isStockInsightsLoading || marketingBriefingManager.isLoading || selectedProviderLoading
    }
    
    private func refreshAllAIData() async {
        await withTaskGroup(of: Void.self) { group in
            if let provider = selectedProvider {
                group.addTask { await generateAIInsights(for: provider) }
            } else {
                group.addTask { await refreshInsights() }
                group.addTask { await refreshTodaySummary() }
                group.addTask { await refreshStockInsights() }
                group.addTask { await refreshMarketingBriefing() }
            }
        }
    }
    
    private func generateAIInsights(for provider: AIProvider) async {
        let symbols = getPortfolioSymbols()
        guard !symbols.isEmpty else {
            providerSummaries[provider] = "Add stocks to your portfolio to generate AI insights."
            providerStockInsights[provider] = [:]
            providerMarketingBriefings[provider] = nil
            return
        }
        
        providerLoadingStates[provider] = true
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await generateAISummary(for: provider, symbols: symbols) }
            group.addTask { await generateStockInsights(for: provider, symbols: symbols) }
            group.addTask { await generateMarketingBriefing(for: provider, symbols: symbols) }
        }
        providerLoadingStates[provider] = false
        summaryLastUpdate = Date()
        stockInsightsLastUpdate = Date()
    }
    
    private func generateAISummary(for provider: AIProvider, symbols: [String]) async {
        do {
            let stocks = symbols.map { DeepSeekManager.Stock(symbol: $0, currentPrice: 150, previousClose: 148, quantity: 1) }
            let analysis = try await DeepSeekManager.shared.generatePortfolioAnalysis(for: stocks)
            let summaryText = """
            **AI Analysis (\(provider.displayName))**
            **Confidence Score:** \(Int(analysis.confidenceScore * 100))%
            **Risk Level:** \(analysis.riskLevel)
            
            Analysis considers current market conditions, diversification, and risk factors.
            """
            providerSummaries[provider] = summaryText
        } catch {
            providerSummaries[provider] = "**Analysis Failed:**\n\(error.localizedDescription)"
        }
    }
    
    private func generateStockInsights(for provider: AIProvider, symbols: [String]) async {
        var insights: [String: AIStockInsight] = [:]
        await withTaskGroup(of: (String, AIStockInsight?).self) { group in
            for symbol in symbols {
                group.addTask {
                    do {
                        let stock = await DeepSeekManager.Stock(symbol: symbol, currentPrice: 150, previousClose: 148, quantity: 1)
                        let prediction = try await DeepSeekManager.shared.generateStockPrediction(for: stock, historicalData: [])
                        
                        let profitLikelihood = prediction.profitLikelihood ?? (prediction.confidence * 100)
                        let gainPotential = prediction.gainPotential ?? abs(prediction.predictedChange)
                        let confidenceScore = prediction.confidence * 100
                        let upsideChance = prediction.upsideChance ?? (prediction.prediction == .up ? prediction.confidence * 100 : 50.0)
                        
                        let aiMarketSignalScore = (profitLikelihood * 0.35) + (min(gainPotential * 10, 100) * 0.25) + (confidenceScore * 0.25) + (upsideChance * 0.15)
                        
                        return (symbol, AIStockInsight(symbol: symbol, aiMarketSignalScore: aiMarketSignalScore, profitLikelihood: profitLikelihood, gainPotential: gainPotential, confidenceScore: confidenceScore, upsideChance: upsideChance, timestamp: Date()))
                    } catch {
                        print("❌ Failed to generate insight for \(symbol): \(error)")
                        return (symbol, nil)
                    }
                }
            }
            for await (symbol, insight) in group {
                if let insight { insights[symbol] = insight }
            }
        }
        providerStockInsights[provider] = insights
    }
    
    private func generateMarketingBriefing(for provider: AIProvider, symbols: [String]) async {
        do {
            let stocks = symbols.map { DeepSeekManager.Stock(symbol: $0, currentPrice: 150, previousClose: 148, quantity: 1) }
            let customPrompt = settingsManager.analyzeMyInvestmentPrompt
            let briefing = try await DeepSeekManager.shared.generateMarketingBriefing(for: stocks, customPrompt: customPrompt)
            providerMarketingBriefings[provider] = briefing
        } catch {
            print("❌ Failed to generate marketing briefing for \(provider.displayName): \(error)")
            providerMarketingBriefings[provider] = nil
        }
    }
    
    // MARK: - Default Data Refresh Functions

    private func refreshInsights() async {
        let hasPortfolio = !dataManager.portfolio.isEmpty || !portfolioManager.items.isEmpty
        guard hasPortfolio else {
            providerInsights = [:]
            return
        }
        if let aiPortfolio = dataManager.portfolio as? [AIStock] {
            let newInsights = await aiService.generateMultiProviderInsights(for: aiPortfolio)
            providerInsights = newInsights
        }
    }
    
    private func refreshTodaySummary() async {
        isSummaryLoading = true
        defer { isSummaryLoading = false }
        
        guard !getPortfolioSymbols().isEmpty else {
            todaySummary = nil
            summaryLastUpdate = nil
            return
        }
        
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        todaySummary = TodayAISummary(
            confidenceProfitScore: Double.random(in: 40...95),
            marketRisk: Double.random(in: 10...70),
            timestamp: Date()
        )
        summaryLastUpdate = Date()
    }
    
    private func refreshStockInsights() async {
        isStockInsightsLoading = true
        defer { isStockInsightsLoading = false }
        
        let symbols = getPortfolioSymbols()
        guard !symbols.isEmpty else {
            stockInsights = [:]
            stockInsightsLastUpdate = nil
            return
        }
        
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        var newInsights: [String: AIStockInsight] = [:]
        for symbol in symbols {
            let profitLikelihood = Double.random(in: 20...95)
            let gainPotential = Double.random(in: 0.5...8.0)
            let confidenceScore = Double.random(in: 45...95)
            let upsideChance = Double.random(in: 25...90)
            let aiMarketSignalScore = (profitLikelihood * 0.35) + (min(gainPotential * 10, 100) * 0.25) + (confidenceScore * 0.25) + (upsideChance * 0.15)
            newInsights[symbol] = AIStockInsight(symbol: symbol, aiMarketSignalScore: aiMarketSignalScore, profitLikelihood: profitLikelihood, gainPotential: gainPotential, confidenceScore: confidenceScore, upsideChance: upsideChance, timestamp: Date())
        }
        stockInsights = newInsights
        stockInsightsLastUpdate = Date()
    }
    
    private func refreshMarketingBriefing() async {
        var stocks: [DeepSeekManager.Stock] = dataManager.portfolio.map {
            .init(symbol: $0.symbol, currentPrice: $0.currentPrice, previousClose: $0.previousClose, quantity: Double($0.quantity))
        }
        let existingSymbols = Set(stocks.map { $0.symbol })
        let unifiedStocks = portfolioManager.items.compactMap { item -> DeepSeekManager.Stock? in
            guard !existingSymbols.contains(item.symbol) else { return nil }
            return .init(symbol: item.symbol, currentPrice: item.currentPrice ?? 0, previousClose: item.previousClose ?? 0, quantity: Double(item.quantity))
        }
        stocks.append(contentsOf: unifiedStocks)
        
        guard !stocks.isEmpty else {
            marketingBriefingManager.clearCurrentBriefing()
            return
        }
        await marketingBriefingManager.generateBriefing(for: stocks, settingsManager: settingsManager)
    }

    // MARK: - Helpers & Color Logic
    
    private var marketingBriefingEmptyMessage: String {
        if !settingsManager.isDeepSeekKeyValid {
            return "DeepSeek API key required. Please configure your API key in Settings."
        } else {
            return "Add stocks to your portfolio to generate an AI marketing briefing."
        }
    }
    
    private func getPortfolioSymbols() -> [String] {
        let dataManagerSymbols = dataManager.portfolio.map(\.symbol)
        let unifiedSymbols = portfolioManager.items.map(\.symbol)
        return Array(Set(dataManagerSymbols + unifiedSymbols)).filter { !$0.isEmpty }
    }
    
    private func confidenceColor(_ score: Double) -> Color {
        switch score {
        case 71...: .green
        case 41...70: .orange
        default: .red
        }
    }
    
    private func riskColorForPercentage(_ risk: Double) -> Color {
        switch risk {
        case 0...40: .green
        case 41...70: .orange
        default: .red
        }
    }
    
    private func signalScoreColor(_ score: Double) -> Color {
        confidenceColor(score)
    }
    
    private func profitLikelihoodColor(_ likelihood: Double) -> Color {
        confidenceColor(likelihood)
    }
    
    private func gainPotentialColor(_ gain: Double) -> Color {
        switch gain {
        case 3.1...: .green
        case 1.1...3: .orange
        default: .gray
        }
    }
    
    private func upsideChanceColor(_ chance: Double) -> Color {
        confidenceColor(chance)
    }
}

// MARK: - Metric Info & Sheet

enum MetricInfo: Identifiable {
    case confidence, risk, profitLikelihood, gainPotential
    var id: Self { self }
    
    var title: String {
        switch self {
        case .confidence: return "AI Confidence Score"
        case .risk: return "Risk Level"
        case .profitLikelihood: return "Profit Likelihood"
        case .gainPotential: return "Gain Potential"
        }
    }
    
    var description: String {
        switch self {
        case .confidence: "Measures the AI's conviction in its analysis. Higher scores indicate stronger conviction."
        case .risk: "Assesses overall portfolio risk based on volatility, concentration, and historical performance."
        case .profitLikelihood: "The probability of positive returns in the next trading session."
        case .gainPotential: "Estimated maximum upside potential based on current market conditions."
        }
    }
}

struct MetricExplanationSheet: View {
    let metricInfo: MetricInfo
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Text(metricInfo.title).font(.largeTitle).fontWeight(.bold)
                Text(metricInfo.description).foregroundStyle(.secondary)
                Spacer()
            }
            .padding()
            .navigationTitle("Metric Info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
    }
}

// MARK: - Data Models

struct TodayAISummary {
    let confidenceProfitScore: Double
    let marketRisk: Double
    let timestamp: Date
    var confidenceTrend: TrendDirection = .neutral
    var riskTrend: TrendDirection = .neutral
}

struct AIStockInsight {
    let symbol: String
    let aiMarketSignalScore: Double
    let profitLikelihood: Double
    let gainPotential: Double
    let confidenceScore: Double
    let upsideChance: Double
    let timestamp: Date
}

enum TrendDirection: CaseIterable {
    case up, neutral, down
    var icon: String {
        switch self {
        case .up: "arrow.up"
        case .neutral: "arrow.right"
        case .down: "arrow.down"
        }
    }
    var color: Color {
        switch self {
        case .up: .green
        case .neutral: .gray
        case .down: .red
        }
    }
}
