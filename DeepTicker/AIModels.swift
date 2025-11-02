import Foundation

struct HistoricalDataPoint: Identifiable, Codable {
    let id: UUID
    let date: Date
    let close: Double
    let volume: Int

    enum CodingKeys: String, CodingKey {
        case date, close, volume
    }

    init(date: Date, close: Double, volume: Int) {
        self.id = UUID()
        self.date = date
        self.close = close
        self.volume = volume
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID()
        self.date = try container.decode(Date.self, forKey: .date)
        self.close = try container.decode(Double.self, forKey: .close)
        self.volume = try container.decode(Int.self, forKey: .volume)
    }
}

enum PredictionDirection: String, Codable, CaseIterable {
    case up, down, neutral
    
    var emoji: String {
        switch self {
        case .up: return "📈"
        case .down: return "📉"
        case .neutral: return "➡️"
        }
    }
}

struct StockPrediction: Identifiable, Codable {
    let id: UUID
    let stockSymbol: String
    let prediction: PredictionDirection
    let confidence: Double
    let predictedChange: Double
    let timestamp: Date
    let reasoning: String?

    enum CodingKeys: String, CodingKey {
        case stockSymbol, prediction, confidence, predictedChange, timestamp, reasoning
    }

    init(stockSymbol: String, prediction: PredictionDirection, confidence: Double, predictedChange: Double, timestamp: Date, reasoning: String?) {
        self.id = UUID()
        self.stockSymbol = stockSymbol
        self.prediction = prediction
        self.confidence = confidence
        self.predictedChange = predictedChange
        self.timestamp = timestamp
        self.reasoning = reasoning
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID()
        self.stockSymbol = try container.decode(String.self, forKey: .stockSymbol)
        self.prediction = try container.decode(PredictionDirection.self, forKey: .prediction)
        self.confidence = try container.decode(Double.self, forKey: .confidence)
        self.predictedChange = try container.decode(Double.self, forKey: .predictedChange)
        self.timestamp = try container.decode(Date.self, forKey: .timestamp)
        self.reasoning = try container.decodeIfPresent(String.self, forKey: .reasoning)
    }
}

struct Portfolio: Identifiable {
    let id = UUID()
    let confidenceScore: Double
    let riskLevel: String
}
