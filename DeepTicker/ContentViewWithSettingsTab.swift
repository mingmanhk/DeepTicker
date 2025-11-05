import SwiftUI

struct ContentViewWithSettingsTab: View {
    var body: some View {
        TabView {
            ContentView()
                .tabItem { Label("Home", systemImage: "house") }

            AISettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
    }
}

#Preview {
    ContentViewWithSettingsTab()
}
