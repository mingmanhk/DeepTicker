import Foundation

struct AIService {
    /// This is a placeholder for a real AI service.
    /// In a real app, you would make a network request to an LLM endpoint
    /// with the symbols and a detailed prompt.
    func fetchDailySummary(for symbols: [String]) async throws -> String {
        // Simulate network delay to mimic a real API call
        try await Task.sleep(for: .seconds(2))

        // This is a great place to check for specific error conditions.
        // For this example, if a symbol "FAIL" is in the portfolio, we'll throw an error.
        if symbols.contains("FAIL") {
            throw NSError(domain: "AIService", code: 500, userInfo: [NSLocalizedDescriptionKey: "The AI model failed to generate a response for the given symbols."])
        }

        // Generate a detailed, mock response that uses Markdown for formatting.
        let symbolsString = symbols.joined(separator: ", ")

        return """
        Here is your AI-powered daily briefing for **\(symbolsString)**:

        ### 📰 Company-Specific News
        - **\(symbols.first ?? "AAPL"):** Reports suggest a new product announcement is imminent, causing a pre-market buzz. Analysts are optimistic about its potential impact on Q4 earnings.
        - **General:** No other major breaking news for the other symbols in your portfolio today.

        ### 🌍 Macroeconomic Indicators
        The latest CPI data was released this morning, showing a slight increase in inflation. This may lead the Fed to reconsider its stance on interest rates, potentially impacting growth stocks.

        ### 💬 Analyst Ratings & Forecasts
        Morgan Stanley has reiterated its 'Overweight' rating for **\(symbols.last ?? "TSLA")**, citing strong delivery numbers and new factory efficiencies. Price target was slightly increased.

        ### 🌐 Geopolitical & Global Events
        Ongoing trade talks with Asia could affect supply chains for tech companies. No immediate impact, but it remains a key factor to watch.

        ### 💡 Sector Trends & Peer Movement
        The semiconductor sector is showing strength today after a positive earnings report from a major competitor, which could create a positive sentiment ripple for related stocks in your portfolio.

        ### 🧠 Social Sentiment & Unusual Activity
        There is increased chatter on Reddit's WallStreetBets about potential short-term volatility in the tech sector. Trading volume appears normal for your holdings.

        ---

        ### Risk & Profit Prediction
        Based on the factors above, the model predicts a moderately positive outlook for your portfolio today.
        - **Prob. of Profit:** 65%
        """
    }
}
