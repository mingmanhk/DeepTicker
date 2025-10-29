import WidgetKit
import SwiftUI

// MARK: - Widget Provider
struct PortfolioWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> PortfolioWidgetEntry {
        PortfolioWidgetEntry(
            date: Date(),
            totalValue: 10000.0,
            dailyChange: 250.0,
            dailyChangePercent: 2.5,
            healthyCount: 3,
            warningCount: 1,
            dangerCount: 0
        )
    }
    
    func getSnapshot(in context: Context, completion: @escaping (PortfolioWidgetEntry) -> ()) {
        let entry = PortfolioWidgetEntry(
            date: Date(),
            totalValue: 10000.0,
            dailyChange: 250.0,
            dailyChangePercent: 2.5,
            healthyCount: 3,
            warningCount: 1,
            dangerCount: 0
        )
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let portfolioManager = PortfolioManager()
        let stats = portfolioManager.getPortfolioStats()
        
        let entry = PortfolioWidgetEntry(
            date: Date(),
            totalValue: stats.totalValue,
            dailyChange: stats.dailyChange,
            dailyChangePercent: stats.dailyChangePercent,
            healthyCount: stats.healthyCount,
            warningCount: stats.warningCount,
            dangerCount: stats.dangerCount
        )
        
        // Update every 15 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        
        completion(timeline)
    }
}

// MARK: - Widget Entry
struct PortfolioWidgetEntry: TimelineEntry {
    let date: Date
    let totalValue: Double
    let dailyChange: Double
    let dailyChangePercent: Double
    let healthyCount: Int
    let warningCount: Int
    let dangerCount: Int
    
    var overallHealth: HealthStatus {
        let total = healthyCount + warningCount + dangerCount
        if total == 0 { return .healthy }
        
        let dangerRatio = Double(dangerCount) / Double(total)
        let warningRatio = Double(warningCount) / Double(total)
        
        if dangerRatio > 0.3 {
            return .danger
        } else if warningRatio > 0.5 {
            return .warning
        } else {
            return .healthy
        }
    }
}

// MARK: - Widget Views
struct PortfolioWidgetEntryView : View {
    var entry: PortfolioWidgetProvider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
        case .systemMedium:
            MediumWidgetView(entry: entry)
        case .systemLarge:
            LargeWidgetView(entry: entry)
        default:
            SmallWidgetView(entry: entry)
        }
    }
}

struct SmallWidgetView: View {
    let entry: PortfolioWidgetEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(.blue)
                Text("Portfolio")
                    .font(.caption)
                    .fontWeight(.semibold)
                Spacer()
                Circle()
                    .fill(healthColor)
                    .frame(width: 8, height: 8)
            }
            
            Text("$\(entry.totalValue, specifier: "%.0f")")
                .font(.title3)
                .fontWeight(.bold)
            
            HStack {
                Text("\(entry.dailyChange >= 0 ? "+" : "")$\(entry.dailyChange, specifier: "%.0f")")
                    .font(.caption)
                    .foregroundColor(entry.dailyChange >= 0 ? .green : .red)
                Text("(\(entry.dailyChangePercent >= 0 ? "+" : "")\(entry.dailyChangePercent, specifier: "%.1f")%)")
                    .font(.caption)
                    .foregroundColor(entry.dailyChange >= 0 ? .green : .red)
            }
            
            Spacer()
        }
        .padding(.all, 12)
        .background(Color(.systemBackground))
    }
    
    private var healthColor: Color {
        switch entry.overallHealth {
        case .healthy: return .green
        case .warning: return .orange
        case .danger: return .red
        }
    }
}

struct MediumWidgetView: View {
    let entry: PortfolioWidgetEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading) {
                    HStack {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .foregroundColor(.blue)
                        Text("DeepTicker Portfolio")
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                    
                    Text("$\(entry.totalValue, specifier: "%.2f")")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    HStack {
                        Text("\(entry.dailyChange >= 0 ? "+" : "")$\(entry.dailyChange, specifier: "%.2f")")
                        Text("(\(entry.dailyChangePercent >= 0 ? "+" : "")\(entry.dailyChangePercent, specifier: "%.2f")%)")
                    }
                    .font(.subheadline)
                    .foregroundColor(entry.dailyChange >= 0 ? .green : .red)
                }
                
                Spacer()
                
                // Mini Mascot
                ZStack {
                    Circle()
                        .fill(healthColor.opacity(0.2))
                        .frame(width: 50, height: 50)
                    
                    Text(healthEmoji)
                        .font(.title2)
                }
            }
            
            // Health indicators
            HStack {
                healthIndicator(count: entry.healthyCount, color: .green, label: "Healthy")
                Spacer()
                healthIndicator(count: entry.warningCount, color: .orange, label: "Warning")
                Spacer()
                healthIndicator(count: entry.dangerCount, color: .red, label: "Danger")
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }
    
    private var healthColor: Color {
        switch entry.overallHealth {
        case .healthy: return .green
        case .warning: return .orange
        case .danger: return .red
        }
    }
    
    private var healthEmoji: String {
        switch entry.overallHealth {
        case .healthy: return "😊"
        case .warning: return "😐" 
        case .danger: return "😰"
        }
    }
    
    private func healthIndicator(count: Int, color: Color, label: String) -> some View {
        VStack(spacing: 2) {
            HStack(spacing: 2) {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                Text("\(count)")
                    .font(.caption)
                    .fontWeight(.semibold)
            }
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

struct LargeWidgetView: View {
    let entry: PortfolioWidgetEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with mascot
            HStack {
                VStack(alignment: .leading) {
                    HStack {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .foregroundColor(.blue)
                        Text("DeepTicker Portfolio")
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                    
                    Text("Last updated \(entry.date, style: .time)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Larger mascot representation
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(healthColor.opacity(0.2))
                        .frame(width: 60, height: 60)
                    
                    Text(healthEmoji)
                        .font(.largeTitle)
                }
            }
            
            // Portfolio value
            VStack(alignment: .leading, spacing: 4) {
                Text("Total Portfolio Value")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("$\(entry.totalValue, specifier: "%.2f")")
                    .font(.title)
                    .fontWeight(.bold)
                
                HStack {
                    Text("Today: \(entry.dailyChange >= 0 ? "+" : "")$\(entry.dailyChange, specifier: "%.2f")")
                    Text("(\(entry.dailyChangePercent >= 0 ? "+" : "")\(entry.dailyChangePercent, specifier: "%.2f")%)")
                }
                .font(.subheadline)
                .foregroundColor(entry.dailyChange >= 0 ? .green : .red)
            }
            
            Divider()
            
            // Detailed health breakdown
            HStack {
                healthDetailCard(
                    count: entry.healthyCount,
                    color: .green,
                    icon: "checkmark.circle.fill",
                    label: "Healthy"
                )
                
                Spacer()
                
                healthDetailCard(
                    count: entry.warningCount,
                    color: .orange,
                    icon: "exclamationmark.triangle.fill",
                    label: "Warning"
                )
                
                Spacer()
                
                healthDetailCard(
                    count: entry.dangerCount,
                    color: .red,
                    icon: "xmark.circle.fill",
                    label: "Danger"
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }
    
    private var healthColor: Color {
        switch entry.overallHealth {
        case .healthy: return .green
        case .warning: return .orange
        case .danger: return .red
        }
    }
    
    private var healthEmoji: String {
        switch entry.overallHealth {
        case .healthy: return "😊"
        case .warning: return "😐"
        case .danger: return "😰"
        }
    }
    
    private func healthDetailCard(count: Int, color: Color, icon: String, label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title3)
            
            Text("\(count)")
                .font(.headline)
                .fontWeight(.bold)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Widget Configuration
struct PortfolioWidget: Widget {
    let kind: String = "PortfolioWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PortfolioWidgetProvider()) { entry in
            PortfolioWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Portfolio Status")
        .description("Keep track of your stock portfolio health and performance.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

#Preview(as: .systemSmall) {
    PortfolioWidget()
} timeline: {
    PortfolioWidgetEntry(
        date: .now,
        totalValue: 10000.0,
        dailyChange: 250.0,
        dailyChangePercent: 2.5,
        healthyCount: 3,
        warningCount: 1,
        dangerCount: 0
    )
}