// AISettingsViewModel.swift
// DeepTicker
//
// Holds settings state for API key and custom prompt with simple persistence.

import Foundation

@MainActor
final class AISettingsViewModel: ObservableObject {
    private let keychain = KeychainStore()

    static let promptKey = "CustomAIAnalysisPrompt"
    static let apiKeyAccount = "AI_API_KEY"

    @Published var apiKey: String {
        didSet { saveAPIKey() }
    }
    @Published var customPrompt: String {
        didSet { UserDefaults.standard.set(customPrompt, forKey: Self.promptKey) }
    }

    init() {
        self.apiKey = (try? keychain.get(account: Self.apiKeyAccount)) ?? ""
        self.customPrompt = UserDefaults.standard.string(forKey: Self.promptKey) ?? ""
    }

    private func saveAPIKey() {
        if apiKey.isEmpty {
            // Remove from Keychain when cleared
            try? keychain.delete(account: Self.apiKeyAccount)
        } else {
            try? keychain.set(apiKey, account: Self.apiKeyAccount)
        }
    }
}
