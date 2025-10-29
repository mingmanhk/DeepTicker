import SwiftUI

@MainActor
struct AINewsTabView: View {
    @EnvironmentObject var portfolio: PortfolioStore
    @ObservedObject var provider: AINewsProvider
    @State private var symbolInsights: [String: (profitLikelihood: Double?, forecastedGain: Double?, confidence: Double?, upside: Double?, factors: [String])] = [:]
    @State private var isLoadingSymbols: Bool = false
    @State private var lastInsightsUpdate: Date?

    // A Codable struct is needed to store the tuple-like insight data in UserDefaults.
    private struct CodableSymbolInsight: Codable {
        let profitLikelihood: Double?
        let forecastedGain: Double?
        let confidence: Double?
        let upside: Double?
        let factors: [String]
    }

    private let insightsCacheKey = "AINewsTabView.insightsCache"
    private let insightsTimestampKey = "AINewsTabView.insightsTimestamp"

    private enum SortColumn: String, CaseIterable {
        case symbol
        case profitLikelihood
        case forecastedGain
        case confidence
        case upside

        var title: String {
            switch self {
            case .symbol: return "Symbol"
            case .profitLikelihood: return "Today’s Profit Likelihood (%)"
            case .forecastedGain: return "Forecasted Gain Potential (%)"
            case .confidence: return "AI Profit Confidence Score (%)"
            case .upside: return "Projected Upside Chance (%)"
            }
        }
    }

    @State private var sortColumn: SortColumn = .symbol
    @State private var sortAscending: Bool = true
    @State private var expandedSymbols: Set<String> = []

    private struct SymbolInsight: Identifiable {
        let id = UUID()
        let symbol: String
        let profitLikelihood: Double?
        let forecastedGain: Double?
        let confidence: Double?
        let upside: Double?
        let factors: [String]
    }
    
    private func pct(_ v: Double?) -> String {
        v.map { String(format: "%.2f%%", $0 * 100) } ?? "--"
    }
    
    private func formattedDate(_ date: Date?) -> String {
        guard let date = date else { return "" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func riskColor(for level: String) -> Color {
        switch level.lowercased() {
        case "high": return .red
        case "medium": return .yellow
        case "low": return .green
        default: return .primary
        }
    }
    
    private var portfolioSymbols: [String] {
        portfolio.items.map { $0.symbol }
    }
    
    private func makeInsights(from symbols: [String]) -> [SymbolInsight] {
        symbols.map { sym in
            let data = symbolInsights[sym]
            return SymbolInsight(
                symbol: sym,
                profitLikelihood: data?.profitLikelihood,
                forecastedGain: data?.forecastedGain,
                confidence: data?.confidence,
                upside: data?.upside,
                factors: data?.factors ?? ["No data available"]
            )
        }
    }
    
    private func sortInsights(_ rows: [SymbolInsight], by column: SortColumn, ascending: Bool) -> [SymbolInsight] {
        switch column {
        case .symbol:
            return rows.sorted { ascending ? $0.symbol < $1.symbol : $0.symbol > $1.symbol }
        case .profitLikelihood:
            return rows.sorted { (a, b) in
                let lhs = a.profitLikelihood ?? -Double.infinity
                let rhs = b.profitLikelihood ?? -Double.infinity
                return ascending ? lhs < rhs : lhs > rhs
            }
        case .forecastedGain:
            return rows.sorted { (a, b) in
                let lhs = a.forecastedGain ?? -Double.infinity
                let rhs = b.forecastedGain ?? -Double.infinity
                return ascending ? lhs < rhs : lhs > rhs
            }
        case .confidence:
            return rows.sorted { (a, b) in
                let lhs = a.confidence ?? -Double.infinity
                let rhs = b.confidence ?? -Double.infinity
                return ascending ? lhs < rhs : lhs > rhs
            }
        case .upside:
            return rows.sorted { (a, b) in
                let lhs = a.upside ?? -Double.infinity
                let rhs = b.upside ?? -Double.infinity
                return ascending ? lhs < rhs : lhs > rhs
            }
        }
    }
    
    // MARK: - Data Loading & Caching

    private func loadPerSymbolInsights() async {
        let symbols = portfolioSymbols
        guard !symbols.isEmpty else {
            symbolInsights = [:]
            lastInsightsUpdate = nil
            clearSymbolInsightsCache()
            isLoadingSymbols = false
            return
        }
        isLoadingSymbols = true
        
        let newInsights = await withTaskGroup(
            of: (String, (profitLikelihood: Double?, forecastedGain: Double?, confidence: Double?, upside: Double?, factors: [String])).self,
            returning: [String: (profitLikelihood: Double?, forecastedGain: Double?, confidence: Double?, upside: Double?, factors: [String])].self
        ) { group in
            for symbol in symbols {
                group.addTask {
                    do {
                        if let insight = try await provider.prediction(for: symbol) {
                            return (symbol, (profitLikelihood: insight.profitLikelihood, forecastedGain: insight.forecastedGain, confidence: insight.confidence, upside: insight.upside, factors: insight.factors))
                        } else {
                            return (symbol, (profitLikelihood: nil, forecastedGain: nil, confidence: nil, upside: nil, factors: ["No data available"]))
                        }
                    } catch {
                        return (symbol, (profitLikelihood: nil, forecastedGain: nil, confidence: nil, upside: nil, factors: ["Error: \(error.localizedDescription)"]))
                    }
                }
            }
            
            var results: [String: (profitLikelihood: Double?, forecastedGain: Double?, confidence: Double?, upside: Double?, factors: [String])] = [:]
            for await (symbol, data) in group {
                results[symbol] = data
            }
            return results
        }

        // Only update data and cache if the fetch returned at least one valid result.
        let hasValidNewData = newInsights.values.contains { $0.profitLikelihood != nil || $0.forecastedGain != nil }
        if hasValidNewData {
            symbolInsights = newInsights
            lastInsightsUpdate = Date()
            saveSymbolInsightsToCache()
        }
        
        isLoadingSymbols = false
    }

    private func saveSymbolInsightsToCache() {
        let codableInsights = symbolInsights.mapValues { insight in
            CodableSymbolInsight(
                profitLikelihood: insight.profitLikelihood,
                forecastedGain: insight.forecastedGain,
                confidence: insight.confidence,
                upside: insight.upside,
                factors: insight.factors
            )
        }

        do {
            let data = try JSONEncoder().encode(codableInsights)
            UserDefaults.standard.set(data, forKey: insightsCacheKey)
            UserDefaults.standard.set(Date(), forKey: insightsTimestampKey)
        } catch {
            print("Failed to save symbol insights to cache: \(error)")
        }
    }

    private func loadSymbolInsightsFromCache() {
        guard let data = UserDefaults.standard.data(forKey: insightsCacheKey),
              let codableInsights = try? JSONDecoder().decode([String: CodableSymbolInsight].self, from: data) else {
            return
        }

        symbolInsights = codableInsights.mapValues { insight in
            (
                profitLikelihood: insight.profitLikelihood,
                forecastedGain: insight.forecastedGain,
                confidence: insight.confidence,
                upside: insight.upside,
                factors: insight.factors
            )
        }
        lastInsightsUpdate = UserDefaults.standard.object(forKey: insightsTimestampKey) as? Date
    }

    private func clearSymbolInsightsCache() {
        UserDefaults.standard.removeObject(forKey: insightsCacheKey)
        UserDefaults.standard.removeObject(forKey: insightsTimestampKey)
    }
    
    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                if provider.isLoading && provider.aiSummary == nil {
                    ProgressView("Fetching AI insights…")
                        .padding(.top, 20)
                } else if let errorMessage = provider.errorMessage, !errorMessage.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Error")
                            .font(.headline)
                            .foregroundStyle(.red)
                        Text(errorMessage)
                            .foregroundStyle(.secondary)
                        if provider.aiSummary != nil || !symbolInsights.isEmpty {
                            Text("Showing last available data.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    contentView // Show content even if there's an error
                } else {
                    contentView
                }
                Spacer()
            }
            .padding()
            .navigationTitle("AI News & Alerts")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task {
                            await provider.refreshInsights(for: portfolio)
                            await loadPerSymbolInsights()
                        }
                    } label: {
                        if provider.isLoading {
                            ProgressView()
                        } else {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }
                    }
                    .disabled(provider.isLoading)
                }
            }
            .task {
                loadSymbolInsightsFromCache() // Load cached symbol data on first appearance
                await provider.refreshInsights(for: portfolio)
                await loadPerSymbolInsights()
            }
            .onChange(of: portfolio.items) {
                Task {
                    await provider.refreshInsights(for: portfolio)
                    await loadPerSymbolInsights()
                }
            }
        }
    }

    // MARK: - View Components

    @ViewBuilder
    private var contentView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("AI Prediction")
                    .font(.headline)
                    .bold()
                Spacer()
                if let date = provider.lastSummaryUpdate {
                    Text("Updated \(formattedDate(date))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .fixedSize(horizontal: false, vertical: true)

            summaryPanels

            symbolInsightsTable

            if provider.aiSummary == nil && portfolioSymbols.isEmpty {
                Text("No insights available yet. Your stock portfolio is currently empty. Add stocks to your portfolio, then tap Refresh to fetch AI-powered news and alerts.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
            }
        }
    }

    @ViewBuilder
    private var summaryPanels: some View {
        Grid(alignment: .top, horizontalSpacing: 12) {
            GridRow {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top) {
                        Label {
                            Text("AI Profit Confidence Score")
                                .font(.subheadline).bold().fixedSize(horizontal: false, vertical: true)
                        } icon: {
                            Circle().fill(Color.secondary).frame(width: 8, height: 8).padding(.top, 2)
                        }.foregroundStyle(.secondary)
                        Spacer()
                        Menu {
                            Label("Positive", systemImage: "circle.fill").foregroundStyle(.green)
                            Label("Negative", systemImage: "circle.fill").foregroundStyle(.red)
                        } label: { Image(systemName: "info.circle").foregroundStyle(.secondary) }
                    }
                    Text(pct(provider.aiSummary?.confidenceScore))
                        .font(.title3.bold())
                        .foregroundColor((provider.aiSummary?.confidenceScore ?? 0) >= 0 ? .green : .red)
                        .lineLimit(1).minimumScaleFactor(0.7)
                    Spacer(minLength: 0)
                }.padding(12).background(.ultraThinMaterial).cornerRadius(12)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top) {
                        Label {
                            Text("Today's Risk").font(.subheadline).bold()
                        } icon: {
                            Circle().fill(Color.secondary).frame(width: 8, height: 8).padding(.top, 4)
                        }.foregroundStyle(.secondary)
                        Spacer()
                        Menu {
                            Label("High", systemImage: "circle.fill").foregroundStyle(.red)
                            Label("Medium", systemImage: "circle.fill").foregroundStyle(.yellow)
                            Label("Low", systemImage: "circle.fill").foregroundStyle(.green)
                        } label: { Image(systemName: "info.circle").foregroundStyle(.secondary) }
                    }
                    Text(provider.aiSummary?.riskLevel ?? "--")
                        .font(.title3.bold())
                        .foregroundColor(riskColor(for: provider.aiSummary?.riskLevel ?? ""))
                        .lineLimit(1).minimumScaleFactor(0.7)
                    Spacer(minLength: 0)
                }.padding(12).background(.ultraThinMaterial).cornerRadius(12)
            }
        }.frame(minHeight: 80)
    }

    @ViewBuilder
    private var symbolInsightsTable: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("AI Stock analysis")
                    .font(.headline)
                    .bold()
                Spacer()
                if let date = lastInsightsUpdate {
                    Text("Updated \(formattedDate(date))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            let symbols = portfolioSymbols
            let rows = makeInsights(from: symbols)
            let sortedRows = sortInsights(rows, by: sortColumn, ascending: sortAscending)

            if isLoadingSymbols && sortedRows.isEmpty {
                ProgressView("Loading symbol insights…")
            } else if sortedRows.isEmpty && !portfolioSymbols.isEmpty {
                Text("Could not load insights for portfolio symbols.")
                    .foregroundStyle(.secondary)
            } else if sortedRows.isEmpty {
                Text("No symbols in your portfolio.")
                    .foregroundStyle(.secondary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                VStack(spacing: 0) {
                    tableHeader
                    tableRows(for: sortedRows)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }

    @ViewBuilder
    private var tableHeader: some View {
        HStack(spacing: 12) {
            ForEach(SortColumn.allCases, id: \.self) { col in
                Button {
                    if sortColumn == col { sortAscending.toggle() } else { sortColumn = col; sortAscending = true }
                } label: {
                    HStack(spacing: 4) {
                        Text(col.title).font(.caption.bold()).foregroundStyle(.secondary)
                        if sortColumn == col {
                            Image(systemName: sortAscending ? "arrow.up" : "arrow.down")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                    }.frame(minWidth: 160, alignment: .leading)
                }.buttonStyle(.plain)
            }
        }.padding(.vertical, 8).padding(.horizontal, 12).background(.thinMaterial)
    }

    @ViewBuilder
    private func tableRows(for sortedRows: [SymbolInsight]) -> some View {
        VStack(spacing: 0) {
            ForEach(sortedRows) { row in
                symbolInsightRow(for: row)
            }
        }
    }

    @ViewBuilder
    private func symbolInsightRow(for row: SymbolInsight) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                Text(row.symbol)
                    .frame(minWidth: 160, alignment: .leading)
                    .font(.subheadline.monospaced())
                Text(pct(row.profitLikelihood)).frame(minWidth: 160, alignment: .leading)
                Text(pct(row.forecastedGain)).frame(minWidth: 160, alignment: .leading)
                Text(pct(row.confidence)).frame(minWidth: 160, alignment: .leading)
                Text(pct(row.upside)).frame(minWidth: 160, alignment: .leading)
                Spacer(minLength: 0)
                Button {
                    if expandedSymbols.contains(row.symbol) {
                        expandedSymbols.remove(row.symbol)
                    } else {
                        expandedSymbols.insert(row.symbol)
                    }
                } label: {
                    Image(systemName: expandedSymbols.contains(row.symbol) ? "chevron.up" : "chevron.down")
                        .font(.caption).foregroundStyle(.secondary)
                }.buttonStyle(.plain)
            }
            .padding(.vertical, 10).padding(.horizontal, 12)

            if expandedSymbols.contains(row.symbol) {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(row.factors, id: \.self) { f in
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "circle.fill").font(.system(size: 4)).foregroundStyle(.secondary)
                            Text(f).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }.padding(.bottom, 10).padding(.horizontal, 12)
            }
            Divider()
        }.background(.ultraThinMaterial)
    }
}

#Preview {
    let portfolio = PortfolioStore.preview
    let provider = AINewsProvider()
    return AINewsTabView(provider: provider)
        .environmentObject(portfolio)
}
