// DebugConsoleView.swift
// A simple console UI to view JSON payloads and logs with filters.

import SwiftUI

struct DebugConsoleView: View {
    @StateObject private var debugSettings = DebugSettings.load()
    @StateObject private var console = DebugConsoleManager.shared

    @State private var filterEndpoint: String = ""
    @State private var filterSymbol: String = ""

    var filteredLogs: [DebugLogEntry] {
        console.logs.filter { entry in
            (filterEndpoint.isEmpty || entry.endpoint.localizedCaseInsensitiveContains(filterEndpoint)) &&
            (filterSymbol.isEmpty || (entry.symbol?.localizedCaseInsensitiveContains(filterSymbol) ?? false))
        }
    }

    var body: some View {
        Form {
            Section(header: Text("Debug Console")) {
                Toggle("Enable Debug Console", isOn: $debugSettings.debugConsoleEnabled)
                    .onChange(of: debugSettings.debugConsoleEnabled) { debugSettings.save() }

                if debugSettings.debugConsoleEnabled {
                    HStack {
                        TextField("Filter by endpoint", text: $filterEndpoint)
                            .textFieldStyle(.roundedBorder)
                        TextField("Filter by symbol", text: $filterSymbol)
                            .textFieldStyle(.roundedBorder)
                    }

                    if filteredLogs.isEmpty {
                        Text("No logs match your filters.")
                            .foregroundStyle(.secondary)
                    } else {
                        List(filteredLogs) { entry in
                            NavigationLink {
                                DebugLogDetailView(entry: entry)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(entry.endpoint)
                                        if let sym = entry.symbol { Text("· \(sym)").foregroundStyle(.secondary) }
                                        Spacer()
                                        Text(entry.timestamp, style: .time)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    if let err = entry.errorMessage, !err.isEmpty {
                                        Text(err)
                                            .font(.caption)
                                            .foregroundStyle(.red)
                                            .lineLimit(1)
                                    }
                                }
                            }
                        }
                    }

                    Button("Clear Logs", role: .destructive) { console.clear() }
                } else {
                    Text("Enable the console to capture and view raw API payloads and errors.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Debug Console")
    }
}

#Preview {
    NavigationStack { DebugConsoleView() }
}

