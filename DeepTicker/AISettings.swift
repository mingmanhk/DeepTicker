import Foundation
import Combine

/// Represents the available AI data sources.
enum AISource: String, CaseIterable, Identifiable {
    case deepseek = "DeepSeek"
    case openAI = "OpenAI"
    case qwen = "Qwen"

    var id: String { self.rawValue }
}

/// Manages AI-related settings, including the selected source and API keys.
@MainActor
final class AISettings: ObservableObject {
    static let shared = AISettings()

    /// The user's currently selected AI data source.
    @Published var selectedSource: AISource {
        didSet {
            UserDefaults.standard.set(selectedSource.rawValue, forKey: selectedSourceKey)
        }
    }

    /// The API key for the OpenAI service.
    @Published var openAIAPIKey: String {
        didSet {
            saveAPIKey(openAIAPIKey, for: .openAI)
        }
    }

    /// The API key for the Qwen service.
    @Published var qwenAPIKey: String {
        didSet {
            saveAPIKey(qwenAPIKey, for: .qwen)
        }
    }

    private let selectedSourceKey = "AISettings.selectedSource"
    private let keychainService = "com.yourapp.aiservice.apikeys"

    private init() {
        // Load the selected source from UserDefaults
        let storedSource = UserDefaults.standard.string(forKey: selectedSourceKey)
        self.selectedSource = AISource(rawValue: storedSource ?? "") ?? .deepseek

        // Load API keys from the Keychain
        self.openAIAPIKey = Self.loadAPIKey(for: .openAI, service: keychainService) ?? ""
        self.qwenAPIKey = Self.loadAPIKey(for: .qwen, service: keychainService) ?? ""
    }

    /// Returns a list of sources that have a configured API key.
    /// DeepSeek is assumed to always be available.
    var availableSources: [AISource] {
        var sources: [AISource] = [.deepseek]
        if !openAIAPIKey.isEmpty {
            sources.append(.openAI)
        }
        if !qwenAPIKey.isEmpty {
            sources.append(.qwen)
        }
        return sources
    }

    // MARK: - Keychain Management

    private func saveAPIKey(_ key: String, for source: AISource) {
        KeychainHelper.standard.save(
            key,
            service: keychainService,
            account: source.rawValue
        )
    }

    private static func loadAPIKey(for source: AISource, service: String) -> String? {
        KeychainHelper.standard.read(
            service: service,
            account: source.rawValue
        )
    }
}
