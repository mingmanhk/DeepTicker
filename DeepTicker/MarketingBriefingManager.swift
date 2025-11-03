import Foundation
import SwiftUI
import Combine

@MainActor
class MarketingBriefingManager: ObservableObject {
    static let shared = MarketingBriefingManager()
    
    @Published var currentBriefing: DeepSeekManager.MarketingBriefing?
    @Published var isLoading = false
    @Published var lastError: Error?
    
    private let deepSeekManager = DeepSeekManager.shared
    private let cacheKey = "MarketingBriefing.cache"
    private let retryAttempts = 2
    private let cacheExpiryTime: TimeInterval = 3600 // 1 hour
    
    private init() {
        loadFromCache()
    }
    
    func generateBriefing(for stockSymbols: [String], settingsManager: SettingsManager) async {
        guard !stockSymbols.isEmpty else { 
            print("❌ MarketingBriefingManager: No stock symbols provided")
            return 
        }
        
        let customPrompt = AIPromptManager.shared.analyzePortfolioPrompt
        
        print("📊 MarketingBriefingManager: Starting briefing generation for \(stockSymbols.count) symbols")
        print("🔑 API Key valid: \(settingsManager.isDeepSeekKeyValid)")
        print("📝 Custom prompt length: \(customPrompt.count) characters")
        
        isLoading = true
        lastError = nil
        
        do {
            let briefing = try await attemptBriefingGeneration(
                for: stockSymbols, 
                customPrompt: customPrompt
            )
            
            print("✅ MarketingBriefingManager: Briefing generated successfully")
            currentBriefing = briefing
            saveToCache(briefing)
            
        } catch {
            print("❌ MarketingBriefingManager: Generation failed - \(error.localizedDescription)")
            lastError = error
            
            // If we have cached data and the error is pessimistic response, use cache
            if case DeepSeekError.pessimisticResponse = error,
               let cachedBriefing = currentBriefing,
               !isCacheExpired(cachedBriefing) {
                print("📄 Using cached briefing due to pessimistic AI response")
            } else {
                print("💾 No valid cached briefing available")
            }
        }
        
        isLoading = false
    }
    
    private func attemptBriefingGeneration(for stockSymbols: [String], customPrompt: String) async throws -> DeepSeekManager.MarketingBriefing {
        var lastError: Error?
        
        for attempt in 1...retryAttempts {
            do {
                let briefing = try await deepSeekManager.generateMarketingBriefing(
                    for: stockSymbols, 
                    customPrompt: customPrompt
                )
                return briefing
                
            } catch DeepSeekError.pessimisticResponse {
                lastError = DeepSeekError.pessimisticResponse
                
                if attempt < retryAttempts {
                    // Wait before retry with slightly different temperature
                    try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                    continue
                } else {
                    throw DeepSeekError.pessimisticResponse
                }
                
            } catch {
                lastError = error
                
                if attempt < retryAttempts {
                    // Wait before retry
                    try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                    continue
                } else {
                    break
                }
            }
        }
        
        throw lastError ?? DeepSeekError.invalidResponse
    }
    
    private func loadFromCache() {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let briefing = try? JSONDecoder().decode(DeepSeekManager.MarketingBriefing.self, from: data) else {
            return
        }
        
        currentBriefing = briefing
    }
    
    private func saveToCache(_ briefing: DeepSeekManager.MarketingBriefing) {
        guard let data = try? JSONEncoder().encode(briefing) else { return }
        UserDefaults.standard.set(data, forKey: cacheKey)
    }
    
    private func isCacheExpired(_ briefing: DeepSeekManager.MarketingBriefing) -> Bool {
        Date().timeIntervalSince(briefing.timestamp) > cacheExpiryTime
    }
    
    func clearCache() {
        UserDefaults.standard.removeObject(forKey: cacheKey)
        currentBriefing = nil
    }
    
    func clearCurrentBriefing() {
        currentBriefing = nil
        lastError = nil
    }
}