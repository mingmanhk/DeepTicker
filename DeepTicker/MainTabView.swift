import SwiftUI

struct MainTabView: View {
    @StateObject private var aiNewsProvider = AINewsProvider()
    
    var body: some View {
        TabView {
            StocksTabView(aiNewsProvider: aiNewsProvider)
                .tabItem {
                    Label("My Stock", systemImage: "chart.pie.fill")
                }

            AINewsTabView(provider: aiNewsProvider)
                .tabItem {
                    Label("AI News", systemImage: "sparkles")
                }
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(PortfolioStore.preview)
}
