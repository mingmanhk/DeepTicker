// AppSettingsView.swift

import SwiftUI

struct AppSettingsView: View {
    @AppStorage("YFINANCE_API_KEY") private var yfinanceKey: String = ""
    @AppStorage("ALPHA_VANTAGE_API_KEY") private var alphaVantageKey: String = ""
    @AppStorage("MODEL_API_KEY") private var modelKey: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("API Keys") {
                    TextField("YFINANCE_API_KEY", text: $yfinanceKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("ALPHA_VANTAGE_API_KEY", text: $alphaVantageKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("MODEL_API_KEY", text: $modelKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                Section(footer: Text("Keys are stored securely with AppStorage for demo purposes; consider Keychain for production.")) {
                    EmptyView()
                }
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    AppSettingsView()
}
