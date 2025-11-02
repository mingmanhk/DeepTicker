import SwiftUI

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
    
    // Today AI Summary States
    @State private var todaySummary: TodayAISummary?
    @State private var isSummaryLoading = false
    @State private var summaryLastUpdate: Date?
    
    // AI Stock Insight States
    @State private var stockInsights: [String: AIStockInsight] = [:]
    @State private var isStockInsightsLoading = false
    @State private var stockInsightsLastUpdate: Date?
    @State private var isMarketingBriefingCollapsed = false
    
    private var availableProviders: [AIProvider] {
        configManager.availableAIProviders as [AIProvider]
    }
    
    var body: some View {
        NavigationStack {
            content
                .navigationTitle("AI Insights")
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        ToolbarAppIconView(showAppName: true) {
                            // Optional: Add action when app icon is tapped
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        masterRefreshButton
                    }
                }
                .sheet(item: $selectedMetricInfo) { metricInfo in
                    MetricExplanationSheet(metricInfo: metricInfo)
                }
                .task(id: [dataManager.portfolio.count, portfolioManager.items.count, availableProviders.count]) {
                    await refreshAllAIData()
                }
                .refreshable {
                    await refreshAllAIData()
                }
        }
    }
    
    private var content: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                headerSection
                
                // Today AI Summary
                todayAISummaryPanel
                
                // AI Stock Insight Table
                aiStockInsightPanel
                
                // AI Marketing Briefing
                marketingBriefingPanel
            }
            .padding()
        }
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Spacer()
                
                if aiService.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            
            if let lastUpdate = aiService.lastUpdateTime {
                HStack {
                    Image(systemName: "clock")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text("Updated \(lastUpdate, style: .relative)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            if !availableProviders.isEmpty {
                HStack(spacing: 8) {
                    Text("Active AI Models:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    ForEach(availableProviders, id: \.self) { provider in
                        HStack(spacing: 4) {
                            Image(systemName: provider.iconName)
                                .font(.caption2)
                                .foregroundStyle(provider.primaryColor)
                            Text(provider.displayName)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.regularMaterial)
                        .cornerRadius(8)
                    }
                }
            }
        }
    }
    
    private var noProvidersView: some View {
        VStack(spacing: 16) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            
            Text("No AI Providers Available")
                .font(.headline)
                .foregroundStyle(.primary)
            
            Text("Configure your API keys in Settings to enable AI-powered market analysis.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            NavigationLink("Open Settings") {
                ComprehensiveSettingsView()
                    .environmentObject(settingsManager)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.vertical, 40)
        .frame(maxWidth: .infinity)
    }
    
    private func aiProviderPanel(for provider: AIProvider) -> some View {
        let insights = providerInsights[provider]
        let isCollapsed = collapsedPanels.contains(provider)
        
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: provider.iconName)
                        .foregroundStyle(provider.primaryColor)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(provider.displayName)
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        if let insights = insights {
                            Text("Updated \(insights.timestamp, style: .relative)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        if isCollapsed {
                            collapsedPanels.remove(provider)
                        } else {
                            collapsedPanels.insert(provider)
                        }
                    }
                } label: {
                    Image(systemName: "chevron.up")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isCollapsed ? 180 : 0))
                }
                .buttonStyle(.plain)
            }
            
            if !isCollapsed {
                Group {
                    if let insights = insights {
                        providerPanelContent(insights: insights, provider: provider)
                    } else if aiService.isLoading {
                        loadingPanelContent
                    } else {
                        errorPanelContent
                    }
                }
            }
        }
        .padding()
        .background(.regularMaterial)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(provider.primaryColor.opacity(0.3), lineWidth: 1)
        )
    }
    
    private func providerPanelContent(insights: PortfolioInsights, provider: AIProvider) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            insightMetricsGrid(for: insights)
            if !insights.summary.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Analysis")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text(insights.summary)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            if !insights.keyInsights.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Key Insights")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    ForEach(insights.keyInsights, id: \.self) { insight in
                        HStack(alignment: .top, spacing: 8) {
                            Circle()
                                .fill(provider.primaryColor)
                                .frame(width: 4, height: 4)
                                .padding(.top, 6)
                            Text(insight)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
    
    private var loadingPanelContent: some View {
        HStack {
            ProgressView()
                .scaleEffect(0.8)
            Text("Analyzing portfolio...")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
    }
    
    private var errorPanelContent: some View {
        Text("Unable to load insights")
            .font(.callout)
            .foregroundStyle(.red)
            .padding(.vertical, 8)
    }
    
    private func insightMetricsGrid(for insights: PortfolioInsights) -> some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 8),
            GridItem(.flexible(), spacing: 8)
        ], spacing: 12) {
            metricCard(
                title: "Confidence",
                value: "\(Int(insights.confidenceScore))%",
                color: confidenceColor(insights.confidenceScore),
                info: MetricInfo.confidence,
                shouldAnimate: insights.confidenceScore > 90
            )
            
            metricCard(
                title: "Risk Level",
                value: insights.riskLevel,
                color: riskColor(insights.riskLevel),
                info: MetricInfo.risk,
                shouldAnimate: false
            )
        }
    }
    
    private func metricCard(title: String, value: String, color: Color, info: MetricInfo, shouldAnimate: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Button {
                    selectedMetricInfo = info
                } label: {
                    Image(systemName: "info.circle")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(color)
                .scaleEffect(shouldAnimate ? 1.05 : 1.0)
                .opacity(shouldAnimate ? 0.9 : 1.0)
                .animation(
                    shouldAnimate ?
                    Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true) :
                    nil,
                    value: shouldAnimate
                )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.ultraThinMaterial)
        .cornerRadius(8)
    }
    
    private var compositeSignalPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Market Signal Consensus")
                .font(.headline)
                .fontWeight(.semibold)
            
            let avgConfidence = providerInsights.values.map(\.confidenceScore).reduce(0, +) / Double(providerInsights.count)
            
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Consensus Score")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text("\(Int(avgConfidence))%")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(confidenceColor(avgConfidence))
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Provider Agreement")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    let agreement = calculateProviderAgreement()
                    Text(agreement.description)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(agreement.color)
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
    
    // MARK: - Today AI Summary Panel
    
    private var todayAISummaryPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "brain.head.profile")
                        .foregroundStyle(.blue)
                        .font(.title2)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Today AI Summary")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        if let lastUpdate = summaryLastUpdate {
                            Text("Updated \(lastUpdate, style: .relative)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                // Show loading indicator if this component is refreshing
                if isSummaryLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            
            if let summary = todaySummary {
                todaySummaryContent(summary: summary)
            } else if isSummaryLoading {
                summaryLoadingContent
            } else {
                emptySummaryContent
            }
        }
        .padding()
        .background(.regularMaterial)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
        )
        .task {
            if todaySummary == nil && !isSummaryLoading {
                await refreshTodaySummary()
            }
        }
    }
    
    private func todaySummaryContent(summary: TodayAISummary) -> some View {
        HStack(spacing: 20) {
            // Confidence Profit Score
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Text("Confidence Profit Score")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Image(systemName: summary.confidenceTrend.icon)
                        .font(.caption2)
                        .foregroundStyle(summary.confidenceTrend.color)
                }
                
                HStack(spacing: 8) {
                    Text("\(Int(summary.confidenceProfitScore))%")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(confidenceColor(summary.confidenceProfitScore))
                        .scaleEffect(summary.confidenceProfitScore > 90 ? 1.05 : 1.0)
                        .opacity(summary.confidenceProfitScore > 90 ? 0.9 : 1.0)
                        .animation(
                            summary.confidenceProfitScore > 90 ?
                            Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true) :
                            nil,
                            value: summary.confidenceProfitScore > 90
                        )
                    
                    Button {
                        selectedMetricInfo = .profitLikelihood
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            Divider()
                .frame(height: 60)
            
            // Market Risk
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Text("Market Risk")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Image(systemName: summary.riskTrend.icon)
                        .font(.caption2)
                        .foregroundStyle(summary.riskTrend.color)
                }
                
                HStack(spacing: 8) {
                    Text("\(Int(summary.marketRisk))%")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(riskColorForPercentage(summary.marketRisk))
                    
                    Button {
                        selectedMetricInfo = .risk
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var summaryLoadingContent: some View {
        HStack {
            ProgressView()
                .scaleEffect(0.8)
            Text("Analyzing portfolio...")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 20)
    }
    
    private var emptySummaryContent: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.title2)
                .foregroundStyle(.secondary)
            
            Text("Portfolio AI Summary")
                .font(.headline)
                .foregroundStyle(.primary)
            
            if portfolioManager.items.isEmpty && dataManager.portfolio.isEmpty {
                Text("Add stocks to your portfolio to generate AI summary")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                Text("Use the refresh button above to generate today's AI summary")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
    }
    
    private var marketingBriefingPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .foregroundStyle(.purple)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("AI Marketing Briefing")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        if let briefing = marketingBriefingManager.currentBriefing {
                            Text("Updated \(briefing.timestamp, style: .relative)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Ready to generate")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                HStack(spacing: 12) {
                    // Show loading indicator if this component is refreshing
                    if marketingBriefingManager.isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                    
                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isMarketingBriefingCollapsed.toggle()
                        }
                    } label: {
                        Image(systemName: "chevron.up")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .rotationEffect(.degrees(isMarketingBriefingCollapsed ? 180 : 0))
                    }
                    .buttonStyle(.plain)
                }
            }
            
            if !isMarketingBriefingCollapsed {
                Group {
                    if let briefing = marketingBriefingManager.currentBriefing {
                        marketingBriefingContent(briefing: briefing)
                    } else if marketingBriefingManager.isLoading {
                        loadingPanelContent
                    } else if let error = marketingBriefingManager.lastError {
                        errorPanelContent(error: error)
                    } else {
                        emptyBriefingContent
                    }
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
        .task(id: [dataManager.portfolio.count, portfolioManager.items.count]) {
            await refreshMarketingBriefing()
        }
        .onAppear {
            Task {
                // Force initial generation if no briefing exists
                if marketingBriefingManager.currentBriefing == nil && !marketingBriefingManager.isLoading {
                    await refreshMarketingBriefing()
                }
            }
        }
    }
    
    private func marketingBriefingContent(briefing: DeepSeekManager.MarketingBriefing) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            briefingSection(title: "Market Overview", content: briefing.overview, icon: "chart.bar")
            briefingSection(title: "Key Drivers", content: briefing.keyDrivers, icon: "arrow.up.circle")
            briefingSection(title: "Activity & Highlights", content: briefing.highlightsAndActivity, icon: "star.circle")
            briefingSection(title: "Risk Factors", content: briefing.riskFactors, icon: "exclamationmark.triangle")
        }
    }
    
    private func briefingSection(title: String, content: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(.purple)
                
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            
            Text(content)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 4)
    }
    
    private var emptyBriefingContent: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text")
                .font(.title2)
                .foregroundStyle(.secondary)
            
            Text("AI Marketing Briefing")
                .font(.headline)
                .foregroundStyle(.primary)
            
            if portfolioManager.items.isEmpty && dataManager.portfolio.isEmpty {
                Text("Add stocks to your portfolio to generate AI marketing briefings")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            } else if !SettingsManager.shared.isDeepSeekKeyValid {
                VStack(spacing: 8) {
                    Text("DeepSeek API key required")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Text("Configure your API key in Settings")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
            } else {
                VStack(spacing: 8) {
                    Text("Use the refresh button above to generate a marketing briefing for your portfolio")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Text("Portfolio: \(portfolioManager.items.map { $0.symbol }.joined(separator: ", "))")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
    }
    
    private func errorPanelContent(error: Error) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title2)
                .foregroundStyle(.orange)
            
            Text("Unable to generate briefing")
                .font(.callout)
                .foregroundStyle(.primary)
            
            if case DeepSeekError.pessimisticResponse = error {
                Text("Using cached data due to pessimistic AI response")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                Text(error.localizedDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
    }
    
    private var masterRefreshButton: some View {
        Button {
            Task {
                await refreshAllAIData()
            }
        } label: {
            Group {
                if isAnyRefreshing {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "arrow.clockwise")
                        .font(.title3)
                }
            }
            .foregroundStyle(.primary)
            .frame(width: 32, height: 32)
            .glassEffect(.regular.interactive(), in: .circle)
        }
        .buttonStyle(.plain)
        .disabled(isAnyRefreshing)
        .accessibilityLabel("Refresh All AI Data")
        .accessibilityHint("Refreshes all AI insights, stock analysis, and marketing briefings")
    }
    
    /// Indicates if any AI component is currently refreshing
    private var isAnyRefreshing: Bool {
        aiService.isLoading || 
        isSummaryLoading || 
        isStockInsightsLoading || 
        marketingBriefingManager.isLoading
    }
    
    /// Master refresh function that updates all AI data
    private func refreshAllAIData() async {
        let totalStocks = dataManager.portfolio.count + portfolioManager.items.count
        print("🔄 AI Insights: Refreshing all data. Total stocks: \(totalStocks)")
        
        // Refresh all AI components in parallel for better performance
        await withTaskGroup(of: Void.self) { group in
            // Refresh main AI insights
            group.addTask {
                await self.refreshInsights()
            }
            
            // Refresh today's AI summary
            group.addTask {
                await self.refreshTodaySummary()
            }
            
            // Refresh individual stock insights
            group.addTask {
                await self.refreshStockInsights()
            }
            
            // Refresh marketing briefing
            group.addTask {
                await self.refreshMarketingBriefing()
            }
        }
        
        print("✅ AI Insights: Refresh completed. Portfolio empty: \(totalStocks == 0)")
    }
    

    
    // MARK: - AI Stock Insight Panel
    
    private var aiStockInsightPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "tablecells")
                        .foregroundStyle(.purple)
                        .font(.title2)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("AI Stock Insight")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        if let lastUpdate = stockInsightsLastUpdate {
                            Text("Updated \(lastUpdate, style: .relative)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                // Show loading indicator if this component is refreshing
                if isStockInsightsLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            
            if !stockInsights.isEmpty {
                stockInsightsTable
            } else if isStockInsightsLoading {
                stockInsightsLoadingContent
            } else {
                emptyStockInsightsContent
            }
        }
        .padding()
        .background(.regularMaterial)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.purple.opacity(0.3), lineWidth: 1)
        )
        .task {
            if stockInsights.isEmpty && !isStockInsightsLoading {
                await refreshStockInsights()
            }
        }
    }
    
    private var stockInsightsTable: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 12) {
                // Table Header
                HStack(spacing: 0) {
                    Text("Stock")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .frame(width: 60, alignment: .leading)
                    
                    Text("AI Signal")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .frame(width: 80, alignment: .center)
                    
                    Text("Profit %")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .frame(width: 70, alignment: .center)
                    
                    Text("Gain %")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .frame(width: 70, alignment: .center)
                    
                    Text("Confidence")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .frame(width: 80, alignment: .center)
                    
                    Text("Upside %")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .frame(width: 70, alignment: .center)
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                
                Divider()
                
                // Table Rows
                ForEach(getPortfolioSymbols(), id: \.self) { symbol in
                    if let insight = stockInsights[symbol] {
                        stockInsightRow(insight: insight)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func stockInsightRow(insight: AIStockInsight) -> some View {
        HStack(spacing: 0) {
            // Stock Symbol
            VStack(alignment: .leading, spacing: 2) {
                Text(insight.symbol)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .frame(width: 60, alignment: .leading)
            }
            
            // AI Market Signal Score
            VStack(spacing: 2) {
                Text("\(Int(insight.aiMarketSignalScore))")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(signalScoreColor(insight.aiMarketSignalScore))
                    .scaleEffect(insight.aiMarketSignalScore > 90 ? 1.1 : 1.0)
                    .animation(
                        insight.aiMarketSignalScore > 90 ?
                        Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true) :
                        nil,
                        value: insight.aiMarketSignalScore > 90
                    )
            }
            .frame(width: 80)
            
            // Profit Likelihood
            VStack(spacing: 2) {
                Text("\(Int(insight.profitLikelihood))")
                    .font(.caption)
                    .foregroundStyle(profitLikelihoodColor(insight.profitLikelihood))
            }
            .frame(width: 70)
            
            // Gain Potential
            VStack(spacing: 2) {
                Text("\(String(format: "%.1f", insight.gainPotential))")
                    .font(.caption)
                    .foregroundStyle(gainPotentialColor(insight.gainPotential))
            }
            .frame(width: 70)
            
            // Confidence Score
            VStack(spacing: 2) {
                Text("\(Int(insight.confidenceScore))")
                    .font(.caption)
                    .foregroundStyle(confidenceColor(insight.confidenceScore))
            }
            .frame(width: 80)
            
            // Upside Chance
            VStack(spacing: 2) {
                Text("\(Int(insight.upsideChance))")
                    .font(.caption)
                    .foregroundStyle(upsideChanceColor(insight.upsideChance))
            }
            .frame(width: 70)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(.ultraThinMaterial)
        .cornerRadius(8)
    }
    
    private var stockInsightsLoadingContent: some View {
        HStack {
            ProgressView()
                .scaleEffect(0.8)
            Text("Analyzing individual stocks...")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 20)
    }
    
    private var emptyStockInsightsContent: some View {
        VStack(spacing: 12) {
            Image(systemName: "tablecells")
                .font(.title2)
                .foregroundStyle(.secondary)
            
            Text("Stock Insights Table")
                .font(.headline)
                .foregroundStyle(.primary)
            
            if portfolioManager.items.isEmpty && dataManager.portfolio.isEmpty {
                Text("Add stocks to your portfolio to see individual AI insights")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                Text("Use the refresh button above to generate AI insights for each stock")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
    }
    
    private func refreshInsights() async {
        // Check both portfolio sources
        let hasDataManagerPortfolio = !dataManager.portfolio.isEmpty
        let hasUnifiedPortfolio = !portfolioManager.items.isEmpty
        
        guard hasDataManagerPortfolio || hasUnifiedPortfolio else { 
            // Clear insights when no portfolio data exists
            await MainActor.run {
                providerInsights = [:]
            }
            return 
        }
        
        // If we have DataManager portfolio, use that for AI insights
        if hasDataManagerPortfolio,
           let aiPortfolio = dataManager.portfolio as? [AIStock] {
            let newInsights = await aiService.generateMultiProviderInsights(for: aiPortfolio)
            await MainActor.run {
                providerInsights = newInsights
            }
        }
    }
    
    // MARK: - AI Summary & Stock Insights Functions
    
    private func refreshTodaySummary() async {
        await MainActor.run {
            isSummaryLoading = true
        }
        
        let symbols = getPortfolioSymbols()
        guard !symbols.isEmpty else {
            print("🧹 AI Summary: Clearing summary data - no stocks in portfolio")
            // Clear the summary when portfolio is empty
            await MainActor.run {
                todaySummary = nil
                summaryLastUpdate = nil
                isSummaryLoading = false
            }
            return
        }
        
        print("📊 AI Summary: Generating summary for \(symbols.count) stocks: \(symbols.joined(separator: ", "))")
        
        // Simulate AI analysis for now - replace with actual AI service calls
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        let mockSummary = TodayAISummary(
            confidenceProfitScore: Double.random(in: 40...95),
            marketRisk: Double.random(in: 10...70),
            timestamp: Date()
        )
        
        await MainActor.run {
            todaySummary = mockSummary
            summaryLastUpdate = Date()
            isSummaryLoading = false
        }
    }
    
    private func refreshStockInsights() async {
        await MainActor.run {
            isStockInsightsLoading = true
        }
        
        let symbols = getPortfolioSymbols()
        guard !symbols.isEmpty else {
            // Clear the insights when portfolio is empty
            await MainActor.run {
                stockInsights = [:]
                stockInsightsLastUpdate = nil
                isStockInsightsLoading = false
            }
            return
        }
        
        // Simulate AI analysis for now - replace with actual AI service calls
        try? await Task.sleep(nanoseconds: 2_500_000_000) // 2.5 seconds
        
        var newInsights: [String: AIStockInsight] = [:]
        
        for symbol in symbols {
            let profitLikelihood = Double.random(in: 20...95)
            let gainPotential = Double.random(in: 0.5...8.0)
            let confidenceScore = Double.random(in: 45...95)
            let upsideChance = Double.random(in: 25...90)
            
            // Calculate composite AI Market Signal Score using defined weights
            let aiMarketSignalScore = (profitLikelihood * 0.35) +
                                     (min(gainPotential * 10, 100) * 0.25) +
                                     (confidenceScore * 0.25) +
                                     (upsideChance * 0.15)
            
            let insight = AIStockInsight(
                symbol: symbol,
                aiMarketSignalScore: aiMarketSignalScore,
                profitLikelihood: profitLikelihood,
                gainPotential: gainPotential,
                confidenceScore: confidenceScore,
                upsideChance: upsideChance,
                timestamp: Date()
            )
            
            newInsights[symbol] = insight
        }
        
        await MainActor.run {
            stockInsights = newInsights
            stockInsightsLastUpdate = Date()
            isStockInsightsLoading = false
        }
    }
    
    private func getPortfolioSymbols() -> [String] {
        var symbols: [String] = []
        
        // Add symbols from DataManager portfolio
        symbols.append(contentsOf: dataManager.portfolio.map { $0.symbol })
        
        // Add symbols from UnifiedPortfolioManager (avoiding duplicates)
        let unifiedSymbols = portfolioManager.items.map { $0.symbol }
        for symbol in unifiedSymbols {
            if !symbols.contains(symbol) {
                symbols.append(symbol)
            }
        }
        
        return symbols
    }
    
    private func refreshMarketingBriefing() async {
        // Collect stock symbols from both portfolio sources
        var stockSymbols: [String] = []
        
        // Add symbols from DataManager portfolio
        if !dataManager.portfolio.isEmpty {
            stockSymbols.append(contentsOf: dataManager.portfolio.map { $0.symbol })
        }
        
        // Add symbols from UnifiedPortfolioManager (avoiding duplicates)
        if !portfolioManager.items.isEmpty {
            let unifiedSymbols = portfolioManager.items.map { $0.symbol }
            for symbol in unifiedSymbols {
                if !stockSymbols.contains(symbol) {
                    stockSymbols.append(symbol)
                }
            }
        }
        
        guard !stockSymbols.isEmpty else { 
            print("🧹 Marketing Briefing: Clearing briefing data - no stocks in portfolio")
            // Clear the marketing briefing when portfolio is empty
            marketingBriefingManager.clearCurrentBriefing()
            return 
        }
        
        print("📰 Marketing Briefing: Generating briefing for \(stockSymbols.count) stocks: \(stockSymbols.joined(separator: ", "))")
        await marketingBriefingManager.generateBriefing(for: stockSymbols, settingsManager: settingsManager)
    }
    
    private func confidenceColor(_ score: Double) -> Color {
        switch score {
        case 0...40: return .red
        case 41...70: return .orange
        case 71...100: return .green
        default: return .primary
        }
    }
    
    private func riskColor(_ level: String) -> Color {
        switch level.lowercased() {
        case "low": return .green
        case "medium": return .orange
        case "high": return .red
        default: return .primary
        }
    }
    
    // MARK: - New Color Functions for AI Insights
    
    private func riskColorForPercentage(_ risk: Double) -> Color {
        switch risk {
        case 0...40: return .green   // Low risk
        case 41...70: return .orange // Medium risk  
        case 71...100: return .red   // High risk
        default: return .primary
        }
    }
    
    private func signalScoreColor(_ score: Double) -> Color {
        switch score {
        case 0...40: return .red
        case 41...70: return .orange
        case 71...100: return .green
        default: return .primary
        }
    }
    
    private func profitLikelihoodColor(_ likelihood: Double) -> Color {
        switch likelihood {
        case 0...40: return .red     // Low chance
        case 41...70: return .orange // Moderate chance
        case 71...100: return .green // High chance
        default: return .primary
        }
    }
    
    private func gainPotentialColor(_ gain: Double) -> Color {
        switch gain {
        case 0...1: return .gray     // Minimal upside
        case 1.1...3: return .orange // Moderate upside
        case 3.1...100: return .green // Strong upside
        default: return .primary
        }
    }
    
    private func upsideChanceColor(_ chance: Double) -> Color {
        switch chance {
        case 0...40: return .red     // Unlikely to rise
        case 41...70: return .orange // Possible upside
        case 71...100: return .green // Likely to rise
        default: return .primary
        }
    }
    
    private func calculateProviderAgreement() -> (description: String, color: Color) {
        let confidenceScores = providerInsights.values.map(\.confidenceScore)
        guard confidenceScores.count > 1 else { return ("Single Source", .gray) }
        
        let standardDeviation = calculateStandardDeviation(confidenceScores)
        
        switch standardDeviation {
        case 0...10: return ("High Agreement", .green)
        case 11...20: return ("Moderate Agreement", .orange)
        default: return ("Low Agreement", .red)
        }
    }
    
    private func calculateStandardDeviation(_ values: [Double]) -> Double {
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.map { pow($0 - mean, 2) }.reduce(0, +) / Double(values.count)
        return sqrt(variance)
    }
}

// MARK: - Metric Info Types

enum MetricInfo: Identifiable {
    case confidence
    case risk
    case profitLikelihood
    case gainPotential
    
    var id: String {
        switch self {
        case .confidence: return "confidence"
        case .risk: return "risk"
        case .profitLikelihood: return "profitLikelihood"
        case .gainPotential: return "gainPotential"
        }
    }
    
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
        case .confidence:
            return "Measures how confident the AI model is in its analysis. Higher scores indicate stronger conviction in the predictions."
        case .risk:
            return "Assesses the overall risk exposure of your portfolio based on market volatility, sector concentration, and historical performance."
        case .profitLikelihood:
            return "The probability that your portfolio will show positive returns in the next trading session."
        case .gainPotential:
            return "Estimated maximum upside potential based on current market conditions and technical analysis."
        }
    }
}

// MARK: - Metric Explanation Sheet

struct MetricExplanationSheet: View {
    let metricInfo: MetricInfo
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(metricInfo.title)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text(metricInfo.description)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Metric Info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    EnhancedAIInsightsTab()
        .environmentObject(SecureConfigurationManager.shared)
        .environmentObject(SettingsManager.shared)
}

// MARK: - Today AI Summary Data Models

struct TodayAISummary {
    let confidenceProfitScore: Double // 0-100
    let marketRisk: Double // 0-100
    let timestamp: Date
    
    var confidenceTrend: TrendDirection = .neutral
    var riskTrend: TrendDirection = .neutral
}

// MARK: - AI Stock Insight Data Models

struct AIStockInsight {
    let symbol: String
    let aiMarketSignalScore: Double // 0-100 (composite)
    let profitLikelihood: Double // 0-100 (35% weight)
    let gainPotential: Double // 0-100 (25% weight) 
    let confidenceScore: Double // 0-100 (25% weight)
    let upsideChance: Double // 0-100 (15% weight)
    let timestamp: Date
    
    var trends: AIStockTrends = AIStockTrends()
}

struct AIStockTrends {
    var signalTrend: TrendDirection = .neutral
    var profitTrend: TrendDirection = .neutral
    var gainTrend: TrendDirection = .neutral
    var confidenceTrend: TrendDirection = .neutral
    var upsideTrend: TrendDirection = .neutral
}

enum TrendDirection: CaseIterable {
    case up, neutral, down
    
    var icon: String {
        switch self {
        case .up: return "arrow.up"
        case .neutral: return "arrow.right"
        case .down: return "arrow.down"
        }
    }
    
    var color: Color {
        switch self {
        case .up: return .green
        case .neutral: return .gray
        case .down: return .red
        }
    }
}
