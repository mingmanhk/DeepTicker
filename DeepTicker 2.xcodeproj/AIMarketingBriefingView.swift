import SwiftUI

struct AIMarketingBriefingPanel: View {
    @State private var jsonString: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    struct Briefing: Decodable {
        let summary: String
        let risk_level: String
        let sentiment: String
        let bullet_points: [String]
    }

    private func loadBriefing() {
        isLoading = true
        errorMessage = nil
        let stocks = PortfolioStore.shared.stocks
        DeepSeekManager.shared.generateMarketingBriefing(for: stocks) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let json):
                    jsonString = json
                case .failure(let error):
                    jsonString = ""
                    errorMessage = error.localizedDescription
                }
                isLoading = false
            }
        }
    }

    private var parsedBriefing: Briefing? {
        guard let data = jsonString.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(Briefing.self, from: data)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("AI Marketing Briefing")
                .font(.title2)
                .bold()

            if isLoading {
                HStack {
                    ProgressView()
                    Text("Loading briefing...")
                }
                .frame(maxWidth: .infinity, alignment: .center)
            } else if let errorMessage = errorMessage {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Failed to load briefing:")
                        .bold()
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .fixedSize(horizontal: false, vertical: true)
                    Button(action: loadBriefing) {
                        Text("Retry")
                    }
                }
            } else if let briefing = parsedBriefing {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(briefing.summary)
                            .fixedSize(horizontal: false, vertical: true)
                        HStack {
                            Text("Risk Level:")
                                .bold()
                            Text(briefing.risk_level)
                        }
                        HStack {
                            Text("Sentiment:")
                                .bold()
                            Text(briefing.sentiment)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Highlights:")
                                .bold()
                            ForEach(briefing.bullet_points, id: \.self) { point in
                                HStack(alignment: .top) {
                                    Text("•")
                                    Text(point)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            } else if !jsonString.isEmpty {
                ScrollView {
                    Text(jsonString)
                        .font(.system(.body, design: .monospaced))
                        .padding()
                }
            } else {
                Text("No briefing available.")
                    .foregroundColor(.secondary)
            }

            Spacer()

            HStack {
                Spacer()
                Button(action: loadBriefing) {
                    Text("Refresh")
                }
                .disabled(isLoading)
            }
        }
        .padding()
        .onAppear(perform: loadBriefing)
    }
}

struct AIMarketingBriefingPanel_Previews: PreviewProvider {
    static var previews: some View {
        AIMarketingBriefingPanel()
    }
}
