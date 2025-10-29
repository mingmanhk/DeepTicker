// DebugConsoleManager.swift
// Captures and exposes API logs for debugging.

import Foundation
import Combine

struct DebugLogEntry: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let endpoint: String
    let level: LogLevel?
    let message: String?
    let symbol: String?
    let requestPayload: String? // raw JSON
    let responsePayload: String? // raw JSON
    let errorMessage: String?

    init(id: UUID = UUID(), timestamp: Date = Date(), endpoint: String, level: LogLevel? = nil, message: String? = nil, symbol: String? = nil, requestPayload: String? = nil, responsePayload: String? = nil, errorMessage: String? = nil) {
        self.id = id
        self.timestamp = timestamp
        self.endpoint = endpoint
        self.level = level
        self.message = message
        self.symbol = symbol
        self.requestPayload = requestPayload
        self.responsePayload = responsePayload
        self.errorMessage = errorMessage
    }
}

enum LogLevel: String, Codable, CaseIterable, Identifiable {
    case info
    case warning
    case error
    var id: String { rawValue }
}

@MainActor
final class DebugConsoleManager: ObservableObject {
    static let shared = DebugConsoleManager()

    @Published private(set) var logs: [DebugLogEntry] = []
    private let maxLogCount = 500
    private let debugSettings = DebugSettings.load()
    private var cancellable: AnyCancellable?

    private let storageKey = "DebugConsoleManager.Logs"

    private init() {
        load()
        // Clear logs automatically when the debug console is disabled
        cancellable = debugSettings.$debugConsoleEnabled
            .removeDuplicates()
            .sink { [weak self] enabled in
                guard let self else { return }
                if !enabled {
                    self.clear()
                }
            }
    }

    func log(endpoint: String, symbol: String? = nil, requestJSON: String? = nil, responseJSON: String? = nil, error: String? = nil) {
        #if DEBUG
        guard debugSettings.debugConsoleEnabled else { return }
        #else
        return
        #endif
        let entry = DebugLogEntry(endpoint: endpoint, symbol: symbol, requestPayload: requestJSON, responsePayload: responseJSON, errorMessage: error)
        logs.insert(entry, at: 0)
        if logs.count > maxLogCount { logs.removeLast(logs.count - maxLogCount) }
        persist()
    }

    func log(level: LogLevel = .info, endpoint: String, symbol: String? = nil, message: String) {
        #if DEBUG
        guard debugSettings.debugConsoleEnabled else { return }
        #else
        return
        #endif
        let entry = DebugLogEntry(endpoint: endpoint, level: level, message: message, symbol: symbol, requestPayload: nil, responsePayload: nil, errorMessage: nil)
        logs.insert(entry, at: 0)
        if logs.count > maxLogCount { logs.removeLast(logs.count - maxLogCount) }
        persist()
    }

    func clear() {
        logs.removeAll()
        persist()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(logs) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([DebugLogEntry].self, from: data) {
            logs = decoded
        }
    }

    func filtered(bySymbol symbol: String?) -> [DebugLogEntry] {
        guard let symbol = symbol, !symbol.isEmpty else { return logs }
        return logs.filter { $0.symbol == symbol }
    }

    func filtered(byEndpoint endpoint: String?) -> [DebugLogEntry] {
        guard let endpoint = endpoint, !endpoint.isEmpty else { return logs }
        return logs.filter { $0.endpoint == endpoint }
    }

    func filtered(level: LogLevel?) -> [DebugLogEntry] {
        guard let level = level else { return logs }
        return logs.filter { $0.level == level }
    }
}

