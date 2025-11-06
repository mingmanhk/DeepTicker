import SwiftUI

// MARK: - Stock Insight Sort Column

enum StockInsightSortColumn: CaseIterable {
    case symbol
    case aiInsightScore
    case profitLikelihood
    case gainPotential
    case confidenceScore
    case upsideChance
    
    var displayName: String {
        switch self {
        case .symbol: return "Stock"
        case .aiInsightScore: return "AI Insight"
        case .profitLikelihood: return "Profit %"
        case .gainPotential: return "Gain %"
        case .confidenceScore: return "Confidence"
        case .upsideChance: return "Upside %"
        }
    }
}

@MainActor
struct EnhancedAIInsightsTab: View {
    @ObservedObject private var configManager = SecureConfigurationManager.shared
    @StateObject private var aiService = MultiProviderAIService()
    @StateObject private var marketingBriefingManager = MarketingBriefingManager.shared
    @ObservedObject private var dataManager = DataManager.shared
    @ObservedObject private var portfolioManager = UnifiedPortfolioManager.shared
    @EnvironmentObject var settingsManager: SettingsManager
    
    @State private var selectedMetricInfo: MetricInfo?
    
    // AI Provider Selection States
    @State private var selectedProvider: AIProvider?
    @State private var providerLoadingStates: [AIProvider: Bool] = [:]
    @State private var providerSummaries: [AIProvider: String] = [:]
    @State private var providerTodaySummaries: [AIProvider: TodayAISummary] = [:]
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
                .onAppear {
                    Task { @MainActor in
                        // Auto-select DeepSeek by default if available and no provider selected
                        if selectedProvider == nil, settingsManager.isDeepSeekKeyValid,
                           let deepSeekProvider = availableProviders.first(where: { $0.displayName.lowercased().contains("deepseek") }) {
                            selectedProvider = deepSeekProvider
                            await generateAIInsights(for: deepSeekProvider)
                        } else {
                            await refreshAllAIData(force: true)
                        }
                    }
                }
        }
    }
    
    private var content: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: AppDesignSystem.Spacing.xl) {
                headerSection
                disclaimerView
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
        .padding(AppDesignSystem.Spacing.md)
        .background(.regularMaterial)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: AppDesignSystem.CornerRadius.md))
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Today AI Summary Panel
    
    private var todayAISummaryPanel: some View {
        ModernPanel {
            PanelHeader(
                title: "Today AI Summary",
                subtitle: (selectedProvider != nil && providerTodaySummaries[selectedProvider!] != nil) ? "Powered by \(selectedProvider!.displayName)" : nil,
                icon: selectedProvider?.iconName ?? "brain.head.profile",
                iconColor: selectedProvider?.primaryColor ?? .blue,
                lastUpdate: summaryLastUpdate,
                isLoading: isSummaryLoading || (selectedProvider.map { providerLoadingStates[$0] ?? false } ?? false)
            )
            
            if let selectedProvider = selectedProvider, let providerSummary = providerTodaySummaries[selectedProvider] {
                VStack(alignment: .leading, spacing: AppDesignSystem.Spacing.md) {
                    todaySummaryContent(summary: providerSummary)
                    if let text = providerSummaries[selectedProvider] {
                        Text(.init(text))
                            .font(AppDesignSystem.Typography.callout)
                            .foregroundStyle(.secondary)
                    }
                }
            } else if let summary = todaySummary {
                todaySummaryContent(summary: summary)
            } else if isSummaryLoading || (selectedProvider.map { providerLoadingStates[$0] ?? false } ?? false) {
                LoadingView(message: "Analyzing portfolio...")
                    .padding(AppDesignSystem.Spacing.md)
                    .background(.regularMaterial)
                    .cornerRadius(AppDesignSystem.CornerRadius.md)
            } else {
                EmptyStateView(
                    icon: "chart.bar.doc.horizontal",
                    title: "Portfolio AI Summary",
                    message: portfolioManager.items.isEmpty && dataManager.portfolio.isEmpty ?
                             "Add stocks to your portfolio to generate an AI summary." :
                             "Tap the refresh button to generate today's AI summary."
                )
                .padding(AppDesignSystem.Spacing.md)
                .background(.regularMaterial)
                .cornerRadius(AppDesignSystem.CornerRadius.md)
            }
        }
    }
    
    private func todaySummaryContent(summary: TodayAISummary) -> some View {
        HStack(spacing: AppDesignSystem.Spacing.xl) {
            enhancedSummaryMetric(
                title: "Confidence Profit Score",
                value: summary.confidenceProfitScore,
                trend: summary.confidenceTrend,
                color: confidenceColor(summary.confidenceProfitScore),
                metricInfo: .profitLikelihood
            )
            
            Divider().frame(height: 80)
            
            enhancedSummaryMetric(
                title: "Market Risk",
                value: summary.marketRisk,
                trend: summary.riskTrend,
                color: riskColorForPercentage(summary.marketRisk),
                metricInfo: .risk
            )
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
    
    private func enhancedSummaryMetric(title: String, value: Double, trend: TrendDirection, color: Color, metricInfo: MetricInfo) -> some View {
        VStack(spacing: AppDesignSystem.Spacing.sm) {
            HStack(spacing: AppDesignSystem.Spacing.xs) {
                Text(title)
                    .font(AppDesignSystem.Typography.subheadline)
                    .fontWeight(.medium)
                Button {
                    selectedMetricInfo = metricInfo
                } label: {
                    Image(systemName: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            Gauge(value: value, in: 0...100) {
                Image(systemName: trend.icon)
            } currentValueLabel: {
                Text("\(Int(value))")
                    .font(.caption)
            }
            .gaugeStyle(.accessoryCircularCapacity)
            .tint(color)
            .scaleEffect(1.2)
        }
    }
    
    // MARK: - AI Stock Insight Panel
    
    private var sortedInsights: [AIStockInsight] {
        let insightsSource = selectedProvider.flatMap { providerStockInsights[$0]?.values } ?? stockInsights.values
        let insights = Array(insightsSource)
        
        return insights.sorted { lhs, rhs in
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
    }
    
    private var aiStockInsightPanel: some View {
        ModernPanel {
            VStack(alignment: .leading, spacing: AppDesignSystem.Spacing.lg) {
                PanelHeader(
                    title: "AI Stock Insights",
                    subtitle: (selectedProvider != nil && providerStockInsights[selectedProvider!] != nil) ? "Powered by \(selectedProvider!.displayName)" : nil,
                    icon: "tablecells",
                    iconColor: selectedProvider?.primaryColor ?? .purple,
                    lastUpdate: stockInsightsLastUpdate,
                    isLoading: isStockInsightsLoading || (selectedProvider.map { providerLoadingStates[$0] ?? false } ?? false)
                )
                
                let insights = selectedProvider.flatMap { providerStockInsights[$0] } ?? stockInsights
                
                if !insights.isEmpty {
                    VStack(spacing: AppDesignSystem.Spacing.md) {
                        sortingControlsView
                        ForEach(sortedInsights, id: \.symbol) { insight in
                            AIStockInsightCardView(
                                insight: insight,
                                signalScoreColor: { score in signalScoreColor(score) },
                                profitLikelihoodColor: { value in profitLikelihoodColor(value) },
                                gainPotentialColor: { value in gainPotentialColor(value) },
                                confidenceColor: { value in confidenceColor(value) },
                                upsideChanceColor: { value in upsideChanceColor(value) }
                            )
                        }
                    }
                } else if isStockInsightsLoading || (selectedProvider.map { providerLoadingStates[$0] ?? false } ?? false) {
                    LoadingView(message: "Analyzing individual stocks...")
                        .padding(AppDesignSystem.Spacing.md)
                        .background(.regularMaterial)
                        .cornerRadius(AppDesignSystem.CornerRadius.md)
                } else {
                    EmptyStateView(
                        icon: "tablecells",
                        title: "Stock Insights Table",
                        message: portfolioManager.items.isEmpty && dataManager.portfolio.isEmpty ?
                                 "Add stocks to your portfolio for individual AI insights." :
                                 "Tap the refresh button to generate AI insights for each stock."
                    )
                    .padding(AppDesignSystem.Spacing.md)
                    .background(.regularMaterial)
                    .cornerRadius(AppDesignSystem.CornerRadius.md)
                }
            }
        }
    }
    
    private var disclaimerView: some View {
        Label {
            Text("Experimental AI signals. Not investment advice.")
        } icon: {
            Image(systemName: "info.circle.fill")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.vertical, AppDesignSystem.Spacing.sm)
        .padding(.horizontal, AppDesignSystem.Spacing.md)
        .background(.regularMaterial)
        .cornerRadius(AppDesignSystem.CornerRadius.sm)
        .glassEffect(.regular, in: .rect(cornerRadius: AppDesignSystem.CornerRadius.sm))
    }
    
    private var sortingControlsView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach(StockInsightSortColumn.allCases, id: \.self) { column in
                    Button {
                        withAnimation(.spring()) {
                            if sortColumn == column {
                                sortAscending.toggle()
                            } else {
                                sortColumn = column
                                sortAscending = column != .symbol
                            }
                        }
                    } label: {
                        HStack(spacing: AppDesignSystem.Spacing.xs) {
                            Text(column.displayName)
                            if sortColumn == column {
                                Image(systemName: sortAscending ? "arrow.up" : "arrow.down")
                            }
                        }
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, AppDesignSystem.Spacing.md)
                        .padding(.vertical, AppDesignSystem.Spacing.sm)
                        .background(sortColumn == column ? Color.accentColor.opacity(0.15) : .clear)
                        .overlay(RoundedRectangle(cornerRadius: AppDesignSystem.CornerRadius.sm).stroke(sortColumn == column ? Color.accentColor.opacity(0.35) : .secondary.opacity(0.15), lineWidth: 1))
                        .contentShape(Rectangle())
                        .cornerRadius(AppDesignSystem.CornerRadius.sm)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(sortColumn == column ? .blue : .secondary)
                }
            }
        }
    }
    
    private struct AIStockInsightCardView: View {
        let insight: AIStockInsight
        
        // Accessing outer view's methods requires passing them or making them static.
        // For simplicity, re-defining them here or passing closures.
        let signalScoreColor: (Double) -> Color
        let profitLikelihoodColor: (Double) -> Color
        let gainPotentialColor: (Double) -> Color
        let confidenceColor: (Double) -> Color
        let upsideChanceColor: (Double) -> Color
        
        var body: some View {
            VStack(alignment: .leading, spacing: AppDesignSystem.Spacing.md) {
                HStack(alignment: .top) {
                    Text(insight.symbol)
                        .font(AppDesignSystem.Typography.headline)
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: AppDesignSystem.Spacing.xs) {
                        Text("AI Insight Score")
                            .font(AppDesignSystem.Typography.caption1)
                            .foregroundStyle(.secondary)
                        Text("\(Int(insight.aiMarketSignalScore))")
                            .font(AppDesignSystem.Typography.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(signalScoreColor(insight.aiMarketSignalScore))
                    }
                }
                
                Divider()
                
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppDesignSystem.Spacing.lg) {
                    metricDetailView(title: "Profit Likelihood", value: "\(Int(insight.profitLikelihood))%", color: profitLikelihoodColor(insight.profitLikelihood))
                    metricDetailView(title: "Gain Potential", value: String(format: "%.1f%%", insight.gainPotential), color: gainPotentialColor(insight.gainPotential))
                    metricDetailView(title: "Confidence Score", value: "\(Int(insight.confidenceScore))%", color: confidenceColor(insight.confidenceScore))
                    metricDetailView(title: "Upside Chance", value: "\(Int(insight.upsideChance))%", color: upsideChanceColor(insight.upsideChance))
                }
            }
            .padding(AppDesignSystem.Spacing.md)
            .glassEffect(.regular, in: .rect(cornerRadius: AppDesignSystem.CornerRadius.md))
        }
        
        private func metricDetailView(title: String, value: String, color: Color) -> some View {
            VStack(alignment: .leading) {
                Text(title)
                    .font(AppDesignSystem.Typography.caption1)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(AppDesignSystem.Typography.subheadline.weight(.semibold))
                    .foregroundStyle(color)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    // MARK: - Marketing Briefing Panel
    
    private var marketingBriefingPanel: some View {
        ModernPanel {
            CollapsiblePanelHeader(
                title: "AI Marketing Briefing",
                subtitle: (selectedProvider != nil && providerMarketingBriefings[selectedProvider!] != nil) ? "Powered by \(selectedProvider!.displayName)" : nil,
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
                        .padding(AppDesignSystem.Spacing.md)
                        .background(.regularMaterial)
                        .cornerRadius(AppDesignSystem.CornerRadius.md)
                } else if let error = marketingBriefingManager.lastError {
                    ErrorStateView(error: error)
                } else {
                    EmptyStateView(
                        icon: "doc.text",
                        title: "AI Marketing Briefing",
                        message: marketingBriefingEmptyMessage
                    )
                    .padding(AppDesignSystem.Spacing.md)
                    .background(.regularMaterial)
                    .cornerRadius(AppDesignSystem.CornerRadius.md)
                }
            }
        }
    }
    
    private func marketingBriefingContent(briefing: DeepSeekManager.MarketingBriefing) -> some View {
        VStack(alignment: .leading, spacing: AppDesignSystem.Spacing.sm) {
            briefingDisclosureGroup(title: "Market Overview", content: briefing.overview, icon: "chart.bar")
            briefingDisclosureGroup(title: "Key Drivers", content: briefing.keyDrivers, icon: "arrow.up.circle")
            briefingDisclosureGroup(title: "Activity & Highlights", content: briefing.highlightsAndActivity, icon: "star.circle")
            briefingDisclosureGroup(title: "Risk Factors", content: briefing.riskFactors, icon: "exclamationmark.triangle")
        }
    }
    
    private func briefingDisclosureGroup(title: String, content: String, icon: String) -> some View {
        DisclosureGroup {
            Text(content)
                .font(AppDesignSystem.Typography.callout)
                .foregroundStyle(.secondary)
                .padding(.top, AppDesignSystem.Spacing.sm)
        } label: {
            HStack(spacing: AppDesignSystem.Spacing.sm) {
                Image(systemName: icon)
                    .font(.callout)
                    .foregroundStyle(.purple)
                    .frame(width: 20)
                Text(title)
                    .font(AppDesignSystem.Typography.subheadline)
                    .fontWeight(.medium)
            }
            .contentShape(Rectangle())
        }
        .tint(.primary)
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
            .background(.regularMaterial)
            .clipShape(Circle())
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
    
    private func refreshAllAIData(force: Bool = false) async {
        if force {
            // Clear cached provider-specific state
            providerSummaries.removeAll()
            providerTodaySummaries.removeAll()
            providerStockInsights.removeAll()
            providerMarketingBriefings.removeAll()
            // Clear default caches
            todaySummary = nil
            stockInsights.removeAll()
            marketingBriefingManager.clearCurrentBriefing()
            // Reset timestamps
            summaryLastUpdate = nil
            stockInsightsLastUpdate = nil
        }
        
        // If no provider is selected, do not generate default data; leave panels empty
        guard selectedProvider != nil else { return }
        
        await withTaskGroup(of: Void.self) { group in
            if let provider = selectedProvider {
                group.addTask { await generateAIInsights(for: provider) }
            }
        }
    }
    
    private func generateAIInsights(for provider: AIProvider) async {
        let symbols = getPortfolioSymbols()
        guard !symbols.isEmpty else {
            providerSummaries[provider] = "Add stocks to your portfolio to generate AI insights."
            providerTodaySummaries[provider] = nil
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
            
            let confidencePercent = analysis.confidenceScore * 100
            let riskPercent: Double
            switch analysis.riskLevel.lowercased() {
            case "low": riskPercent = 20
            case "medium": riskPercent = 50
            case "high": riskPercent = 80
            default: riskPercent = 50
            }
            let providerSummary = TodayAISummary(
                confidenceProfitScore: confidencePercent,
                marketRisk: riskPercent,
                timestamp: Date()
            )
            providerTodaySummaries[provider] = providerSummary
            
            let summaryText = """
            **AI Analysis**
            **Confidence Score:** \(Int(confidencePercent))%
            **Risk Level:** \(analysis.riskLevel)
            
            Analysis considers current market conditions, diversification, and risk factors.
            """
            providerSummaries[provider] = summaryText
        } catch {
            providerTodaySummaries[provider] = nil
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
