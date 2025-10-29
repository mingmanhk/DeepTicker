import Foundation
import Combine

@MainActor
final class AIPromptManager: ObservableObject {
    static let shared = AIPromptManager()
    
    private enum Keys {
        static let analyzeProfitConfidence = "analyzeProfitConfidencePrompt"
        static let analyzeRisk = "analyzeRiskPrompt"
        static let analyzePrediction = "analyzePredictionPrompt"
        static let analyzePortfolio = "analyzePortfolioPrompt"
    }
    
    @Published var analyzeProfitConfidencePrompt: String {
        didSet { UserDefaults.standard.set(analyzeProfitConfidencePrompt, forKey: Keys.analyzeProfitConfidence) }
    }
    
    @Published var analyzeRiskPrompt: String {
        didSet { UserDefaults.standard.set(analyzeRiskPrompt, forKey: Keys.analyzeRisk) }
    }
    
    @Published var analyzePredictionPrompt: String {
        didSet { UserDefaults.standard.set(analyzePredictionPrompt, forKey: Keys.analyzePrediction) }
    }
    
    @Published var analyzePortfolioPrompt: String {
        didSet { UserDefaults.standard.set(analyzePortfolioPrompt, forKey: Keys.analyzePortfolio) }
    }
    
    private init() {
        self.analyzeProfitConfidencePrompt = UserDefaults.standard.string(forKey: Keys.analyzeProfitConfidence) ??
            "Analyze the following stock portfolio and provide a concise summary of its overall health, diversification, and risk profile. Offer actionable suggestions for improvement."
            
        self.analyzeRiskPrompt = UserDefaults.standard.string(forKey: Keys.analyzeRisk) ??
            "Analyze the following stock portfolio and provide a concise summary of its overall health, diversification, and risk profile. Offer actionable suggestions for improvement."
            
        self.analyzePredictionPrompt = UserDefaults.standard.string(forKey: Keys.analyzePrediction) ??
            "Recent Historical Data for Last 10 trading days. Please provide a prediction for tomorrow's movement with the following JSON format..."
            
        self.analyzePortfolioPrompt = UserDefaults.standard.string(forKey: Keys.analyzePortfolio) ??
            "You are an expert financial analyst AI. Your task is to provide a detailed daily market briefing and portfolio health assessment..."
    }
    
    func resetToDefaults() {
        analyzeProfitConfidencePrompt = "Analyze the following stock portfolio and provide a concise summary of its overall health, diversification, and risk profile. Offer actionable suggestions for improvement."
        analyzeRiskPrompt = "Analyze the following stock portfolio and provide a concise summary of its overall health, diversification, and risk profile. Offer actionable suggestions for improvement."
        analyzePredictionPrompt = "Recent Historical Data for Last 10 trading days. Please provide a prediction for tomorrow's movement with the following JSON format..."
        analyzePortfolioPrompt = "You are an expert financial analyst AI. Your task is to provide a detailed daily market briefing and portfolio health assessment..."
    }
}
