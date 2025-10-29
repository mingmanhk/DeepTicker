// Detailed view for a single debug log entry.

import SwiftUI

struct DebugLogDetailView: View {
    let entry: DebugLogEntry
    @State private var showRequest = true
    @State private var showResponse = true
    @State private var showError = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                if let message = entry.message, !message.isEmpty {
                    section(title: "Message") {
                        selectableText(message)
                    }
                }
                if let request = entry.requestPayload, !request.isEmpty {
                    section(title: "Request JSON", collapsible: $showRequest) {
                        codeBlock(request)
                    }
                }
                if let response = entry.responsePayload, !response.isEmpty {
                    section(title: "Response JSON", collapsible: $showResponse) {
                        codeBlock(response)
                    }
                }
                if let error = entry.errorMessage, !error.isEmpty {
                    section(title: "Error", collapsible: $showError) {
                        selectableText(error)
                            .foregroundStyle(.red)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Log Details")
        .toolbarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(entry.timestamp, style: .date)
                Text(entry.timestamp, style: .time)
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                if let level = entry.level {
                    Text(level.rawValue.capitalized)
                        .font(.footnote)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(capsuleColor(for: level))
                        .clipShape(Capsule())
                }
                if let symbol = entry.symbol { Text(symbol).font(.footnote).foregroundStyle(.secondary) }
            }

            Text(entry.endpoint)
                .font(.headline)
                .textSelection(.enabled)
        }
    }

    private func section<T: View>(title: String, collapsible: Binding<Bool>? = nil, @ViewBuilder content: () -> T) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title).font(.subheadline).fontWeight(.semibold)
                Spacer()
                if let collapsible = collapsible {
                    Button(collapsible.wrappedValue ? "Hide" : "Show") { collapsible.wrappedValue.toggle() }
                        .font(.caption)
                }
            }
            if collapsible?.wrappedValue ?? true {
                content()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(Color(UIColor.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private func selectableText(_ text: String) -> some View {
        Text(text)
            .font(.callout)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func codeBlock(_ text: String) -> some View {
        ScrollView(.horizontal) {
            Text(text)
                .font(.system(.footnote, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func capsuleColor(for level: LogLevel) -> Color {
        switch level {
        case .info: return .blue.opacity(0.2)
        case .warning: return .orange.opacity(0.2)
        case .error: return .red.opacity(0.2)
        }
    }
}

#Preview {
    let sample = DebugLogEntry(
        endpoint: "/v1/sample",
        level: .warning,
        message: "This is a sample warning message.",
        symbol: "AAPL",
        requestPayload: "{\"q\":\"AAPL\"}",
        responsePayload: "{\"price\":123.45}",
        errorMessage: nil
    )
    return NavigationStack { DebugLogDetailView(entry: sample) }
}
