// DebugSettings.swift
// Stores debug console preferences.

import Foundation
import Combine

@MainActor
final class DebugSettings: ObservableObject, Codable {
    @Published var debugConsoleEnabled: Bool

    init(debugConsoleEnabled: Bool = false) {
        self.debugConsoleEnabled = debugConsoleEnabled
    }

    private static let storageKey = "DebugSettings.Storage"

    static func load() -> DebugSettings {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode(DebugSettings.self, from: data) {
            return decoded
        }
        return DebugSettings()
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }

    enum CodingKeys: String, CodingKey { case debugConsoleEnabled }

    required convenience init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let enabled = try c.decode(Bool.self, forKey: .debugConsoleEnabled)
        self.init(debugConsoleEnabled: enabled)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(debugConsoleEnabled, forKey: .debugConsoleEnabled)
    }
}
