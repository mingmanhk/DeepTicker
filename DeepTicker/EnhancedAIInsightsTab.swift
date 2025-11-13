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
    
    // State to track if initial load has completed
    @State private var hasInitiallyLoaded = false
    @State private var isViewVisible = false
    
    // AI Provider Selection States
    @State private var selectedProvider: AIProvider?
    @State private var providerLoadingStates: [AIProvider: Bool] = [:]
    @State private var providerSummaries: [AIProvider: String] = [:]
    @State private var providerTodaySummaries: [AIProvider: TodayAISummary] = [:]
    @State private var providerStockInsights: [AIProvider: [String: AIStockInsight]] = [:]
    @State private var providerMarketingBriefings: [AIProvider: DeepSeekManager.MarketingBriefing] = [:]
    @State private var providerLastRefreshTimes: [AIProvider: Date] = [:]
    
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
    
    // Direct check for DeepSeek without relying on availableProviders array timing
    private var deepSeekProvider: AIProvider? {
        guard settingsManager.isDeepSeekKeyValid || configManager.isAPIKeyValid(for: .deepSeek) else {
            return nil
        }
        return .deepSeek
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
                .task {
                    // Auto-select provider on first launch
                    await autoSelectProviderIfNeeded()
                }
                .task(id: selectedProvider) {
                    // Smart auto-refresh when provider changes
                    await handleProviderChange()
                }
                .task(id: [dataManager.portfolio.count, portfolioManager.items.count].description) {
                    // Refresh when portfolio changes (only if view is visible and initialized)
                    if hasInitiallyLoaded && isViewVisible {
                        print("🔄 [Portfolio Changed] Triggering refresh")
                        await refreshCurrentProvider()
                    }
                }
                .refreshable {
                    await refreshCurrentProvider(force: true)
                }
                .onAppear {
                    print("👁️ [OnAppear] View appeared")
                    isViewVisible = true
                    
                    // Auto-select provider if needed
                    if selectedProvider == nil, let deepSeek = deepSeekProvider {
                        print("🔵 [OnAppear] Auto-selecting DeepSeek: \(deepSeek.displayName)")
                        selectedProvider = deepSeek
                    }
                }
                .onDisappear {
                    print("👁️ [OnDisappear] View disappeared")
                    isViewVisible = false
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
                } else if let provider = selectedProvider, let lastRefresh = providerLastRefreshTimes[provider] {
                    StatusIndicator(
                        icon: "clock.fill",
                        text: "\(provider.displayName) updated \(lastRefresh.formatted(.relative(presentation: .named)))"
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
                                    handleProviderSelection(provider)
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
    
    // MARK: - Smart Auto-Refresh Logic
    
    /// Auto-select default provider (DeepSeek) if none is selected
    private func autoSelectProviderIfNeeded() async {
        guard selectedProvider == nil else { return }
        
        // Try to select DeepSeek first (default)
        if let deepSeek = availableProviders.first(where: { $0 == .deepSeek }) {
            print("🤖 [Auto-Select] Selecting default provider: \(deepSeek.displayName)")
            selectedProvider = deepSeek
        } else if let deepSeek = deepSeekProvider {
            // Fallback to deepSeekProvider check if not in availableProviders yet
            print("🤖 [Auto-Select] Selecting default provider: \(deepSeek.displayName)")
            selectedProvider = deepSeek
        } else if let firstProvider = availableProviders.first {
            // Final fallback to first available provider
            print("🤖 [Auto-Select] Selecting first available provider: \(firstProvider.displayName)")
            selectedProvider = firstProvider
        }
    }
    
    /// Handle provider changes and trigger smart refresh
    private func handleProviderChange() async {
        guard let provider = selectedProvider else {
            print("⚠️ [Provider Change] No provider selected")
            return
        }
        
        print("🔄 [Provider Change] Provider changed to: \(provider.displayName)")
        
        // Check if we need to refresh data for this provider
        let needsRefresh = shouldRefreshProvider(provider)
        
        if needsRefresh {
            print("✅ [Provider Change] Data is stale or missing, triggering refresh")
            await generateAIInsights(for: provider)
            hasInitiallyLoaded = true
        } else {
            print("✅ [Provider Change] Using cached data (still fresh)")
            hasInitiallyLoaded = true
        }
    }
    
    /// Manual provider selection handler
    private func handleProviderSelection(_ provider: AIProvider) {
        withAnimation(.spring()) {
            // Only allow selection, not deselection
            // A provider must always be selected
            if selectedProvider != provider {
                selectedProvider = provider
                // The .task(id: selectedProvider) will handle the refresh automatically
            }
        }
    }
    
    /// Refresh the currently selected provider
    private func refreshCurrentProvider(force: Bool = false) async {
        guard let provider = selectedProvider else {
            print("⚠️ [Refresh] No provider selected")
            return
        }
        
        if force {
            print("🔄 [Refresh] Force refreshing provider: \(provider.displayName)")
            // Clear cached data for this provider
            providerSummaries.removeValue(forKey: provider)
            providerTodaySummaries.removeValue(forKey: provider)
            providerStockInsights.removeValue(forKey: provider)
            providerMarketingBriefings.removeValue(forKey: provider)
            providerLastRefreshTimes.removeValue(forKey: provider)
        }
        
        await generateAIInsights(for: provider)
    }
    
    /// Check if provider data should be refreshed
    private func shouldRefreshProvider(_ provider: AIProvider) -> Bool {
        // Always refresh if no data exists
        guard let lastRefresh = providerLastRefreshTimes[provider],
              providerTodaySummaries[provider] != nil else {
            print("📊 [Should Refresh] No data exists for \(provider.displayName)")
            return true
        }
        
        // Refresh if data is older than 5 minutes
        let cacheExpirationInterval: TimeInterval = 5 * 60 // 5 minutes
        let isStale = Date().timeIntervalSince(lastRefresh) > cacheExpirationInterval
        
        if isStale {
            print("📊 [Should Refresh] Data is stale (last refresh: \(lastRefresh.formatted(.relative(presentation: .named))))")
        }
        
        return isStale
    }
    
    private var masterRefreshButton: some View {
        Button {
            Task { await refreshCurrentProvider(force: true) }
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
        .accessibilityLabel("Refresh AI Data")
    }
    
    private var isAnyRefreshing: Bool {
        let selectedProviderLoading = selectedProvider.map { providerLoadingStates[$0] ?? false } ?? false
        return aiService.isLoading || isSummaryLoading || isStockInsightsLoading || marketingBriefingManager.isLoading || selectedProviderLoading
    }
    
    // MARK: - AI Insight Generation
    
    private func generateAIInsights(for provider: AIProvider) async {
        let symbols = getPortfolioSymbols()
        guard !symbols.isEmpty else {
            providerSummaries[provider] = "Add stocks to your portfolio to generate AI insights."
            providerTodaySummaries[provider] = nil
            providerStockInsights[provider] = [:]
            providerMarketingBriefings[provider] = nil
            return
        }
        
        print("🚀 [Generating Insights] Starting for \(provider.displayName) with \(symbols.count) stocks")
        providerLoadingStates[provider] = true
        
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.generateAISummary(for: provider, symbols: symbols) }
            group.addTask { await self.generateStockInsights(for: provider, symbols: symbols) }
            group.addTask { await self.generateMarketingBriefing(for: provider, symbols: symbols) }
        }
        
        providerLoadingStates[provider] = false
        providerLastRefreshTimes[provider] = Date()
        summaryLastUpdate = Date()
        stockInsightsLastUpdate = Date()
        
        print("✅ [Generating Insights] Completed for \(provider.displayName)")
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
            **AI Analysis considers current market conditions, diversification, and risk factors.
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
                        
                        print("🔍 [\(symbol)] Raw AI prediction values:")
                        print("   - confidence: \(prediction.confidence)")
                        print("   - profitLikelihood: \(prediction.profitLikelihood ?? -1)")
                        print("   - gainPotential: \(prediction.gainPotential ?? -1)")
                        print("   - upsideChance: \(prediction.upsideChance ?? -1)")
                        
                        // Helper function to normalize values to 0-100 range
                        func normalizeToPercentage(_ value: Double) -> Double {
                            // If value is already in percentage range (0-100), use it
                            if value >= 0 && value <= 100 {
                                return value
                            }
                            // If value is in decimal range (0-1), convert to percentage
                            else if value >= 0 && value <= 1 {
                                return value * 100
                            }
                            // If value is out of range, clamp it
                            else {
                                return min(max(value, 0), 100)
                            }
                        }
                        
                        // Confidence typically comes as 0-1 from AI models
                        let confidenceScore = normalizeToPercentage(prediction.confidence)
                        
                        // Profit likelihood - normalize it
                        let profitLikelihood: Double
                        if let pl = prediction.profitLikelihood {
                            profitLikelihood = normalizeToPercentage(pl)
                        } else {
                            profitLikelihood = confidenceScore
                        }
                        
                        // Gain potential - this might be a raw percentage change
                        let gainPotential: Double
                        if let gp = prediction.gainPotential {
                            gainPotential = normalizeToPercentage(gp)
                        } else {
                            // predictedChange is usually a small decimal like 0.025 (2.5%)
                            let rawChange = abs(prediction.predictedChange)
                            gainPotential = rawChange > 1 ? min(rawChange, 100) : (rawChange * 100)
                        }
                        
                        // Upside chance - normalize it
                        let upsideChance: Double
                        if let uc = prediction.upsideChance {
                            upsideChance = normalizeToPercentage(uc)
                        } else {
                            upsideChance = prediction.prediction == .up ? confidenceScore : 50.0
                        }
                        
                        print("🔍 [\(symbol)] Normalized values:")
                        print("   - confidenceScore: \(confidenceScore)")
                        print("   - profitLikelihood: \(profitLikelihood)")
                        print("   - gainPotential: \(gainPotential)")
                        print("   - upsideChance: \(upsideChance)")
                        
                        // Calculate AI Market Signal Score (weighted average, result should be 0-100)
                        let aiMarketSignalScore = (profitLikelihood * 0.35) + (gainPotential * 0.25) + (confidenceScore * 0.25) + (upsideChance * 0.15)
                        
                        print("🔍 [\(symbol)] AI Market Signal Score: \(aiMarketSignalScore)")
                        
                        let finalInsight = AIStockInsight(
                            symbol: symbol,
                            aiMarketSignalScore: aiMarketSignalScore,
                            profitLikelihood: profitLikelihood,
                            gainPotential: gainPotential,
                            confidenceScore: confidenceScore,
                            upsideChance: upsideChance,
                            timestamp: Date()
                        )
                        
                        return (symbol, finalInsight)
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
