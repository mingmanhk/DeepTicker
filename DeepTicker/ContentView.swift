import SwiftUI
import SwiftData
import BackgroundTasks

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [TimestampItem]
    @StateObject private var dataManager = DataManager.shared
    @StateObject private var portfolioManager = UnifiedPortfolioManager.shared
    @State private var hasAppeared = false
    
    init() {
        BackgroundTaskManager.shared.register()
    }

    var body: some View {
        TabView {
            // My Stocks Tab (Enhanced with live valuation)
            ModernMyInvestmentTab()
                .environmentObject(portfolioManager)
                .tabItem {
                    Label("My Stocks", systemImage: "briefcase")
                }
            
            // Alerts & Notifications Tab
            NotificationsTabView()
                .environmentObject(SettingsManager.shared)
                .tabItem {
                    Label("Alerts", systemImage: "bell")
                }

            // Comprehensive Settings Tab
            ComprehensiveSettingsView()
                .environmentObject(SecureConfigurationManager.shared)
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
        .task {
            if !hasAppeared {
                hasAppeared = true
                // Auto-refresh on app launch (as per your scope requirements)
                await dataManager.refreshAll()
            }
        }
        .onAppear { 
            BackgroundTaskManager.shared.scheduleNext() 
        }
        .overlay(alignment: .top) {
            // Show refresh indicator when data is loading
            if dataManager.isRefreshing || portfolioManager.isRefreshing {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Refreshing data...")
                        .font(.caption)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.regularMaterial)
                .cornerRadius(20)
                .padding(.top, 8)
                .animation(.easeInOut, value: dataManager.isRefreshing)
            }
        }
    }

    private func addItem() {
        withAnimation {
            let newItem = TimestampItem(timestamp: Date())
            modelContext.insert(newItem)
        }
    }

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(items[index])
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: TimestampItem.self, inMemory: true)
}
