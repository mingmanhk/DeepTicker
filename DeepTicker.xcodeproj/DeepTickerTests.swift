import Testing
import Foundation
@testable import DeepTicker

@Suite("DeepTicker Core Tests")
struct DeepTickerTests {
    
    @Suite("Stock Model Tests")
    struct StockModelTests {
        
        @Test("Stock health status calculation for healthy stock")
        func testHealthyStockStatus() async throws {
            let stock = Stock(
                symbol: "AAPL",
                name: "Apple Inc.",
                currentPrice: 150.0,
                previousClose: 148.0,
                changePercent: 1.35,
                shares: 10.0
            )
            
            #expect(stock.healthStatus == .healthy, "Stock with +1.35% change should be healthy")
        }
        
        @Test("Stock health status calculation for warning stock")
        func testWarningStockStatus() async throws {
            let stock = Stock(
                symbol: "MSFT",
                name: "Microsoft Corporation",
                currentPrice: 300.0,
                previousClose: 315.0,
                changePercent: -4.76,
                shares: 5.0
            )
            
            #expect(stock.healthStatus == .warning, "Stock with -4.76% change should be in warning")
        }
        
        @Test("Stock health status calculation for danger stock")
        func testDangerStockStatus() async throws {
            let stock = Stock(
                symbol: "TSLA",
                name: "Tesla Inc.",
                currentPrice: 200.0,
                previousClose: 230.0,
                changePercent: -13.04,
                shares: 2.0
            )
            
            #expect(stock.healthStatus == .danger, "Stock with -13.04% change should be in danger")
        }
        
        @Test("Stock total value calculation")
        func testStockTotalValue() async throws {
            let stock = Stock(
                symbol: "GOOGL",
                name: "Alphabet Inc.",
                currentPrice: 120.0,
                previousClose: 118.0,
                changePercent: 1.69,
                shares: 8.5
            )
            
            let expectedTotalValue = 120.0 * 8.5
            #expect(stock.totalValue == expectedTotalValue, "Total value should be price × shares")
        }
        
        @Test("Stock daily change calculation")
        func testStockDailyChange() async throws {
            let stock = Stock(
                symbol: "NVDA",
                name: "NVIDIA Corporation",
                currentPrice: 400.0,
                previousClose: 390.0,
                changePercent: 2.56,
                shares: 3.0
            )
            
            let expectedDailyChange = (400.0 - 390.0) * 3.0
            #expect(stock.dailyChange == expectedDailyChange, "Daily change should be (current - previous) × shares")
        }
    }
    
    @Suite("Portfolio Stats Tests")
    struct PortfolioStatsTests {
        
        @Test("Portfolio overall health calculation - healthy majority")
        func testHealthyPortfolioStats() async throws {
            let stats = PortfolioStats(
                totalValue: 50000.0,
                dailyChange: 1250.0,
                dailyChangePercent: 2.56,
                healthyCount: 7,
                warningCount: 2,
                dangerCount: 1
            )
            
            #expect(stats.overallHealth == .healthy, "Portfolio with majority healthy stocks should be healthy")
        }
        
        @Test("Portfolio overall health calculation - warning majority")
        func testWarningPortfolioStats() async throws {
            let stats = PortfolioStats(
                totalValue: 30000.0,
                dailyChange: -750.0,
                dailyChangePercent: -2.43,
                healthyCount: 2,
                warningCount: 6,
                dangerCount: 2
            )
            
            #expect(stats.overallHealth == .warning, "Portfolio with majority warning stocks should be warning")
        }
        
        @Test("Portfolio overall health calculation - danger threshold")
        func testDangerPortfolioStats() async throws {
            let stats = PortfolioStats(
                totalValue: 25000.0,
                dailyChange: -2500.0,
                dailyChangePercent: -9.09,
                healthyCount: 1,
                warningCount: 2,
                dangerCount: 4
            )
            
            #expect(stats.overallHealth == .danger, "Portfolio with >30% danger stocks should be danger")
        }
        
        @Test("Empty portfolio health")
        func testEmptyPortfolioStats() async throws {
            let stats = PortfolioStats(
                totalValue: 0.0,
                dailyChange: 0.0,
                dailyChangePercent: 0.0,
                healthyCount: 0,
                warningCount: 0,
                dangerCount: 0
            )
            
            #expect(stats.overallHealth == .healthy, "Empty portfolio should default to healthy")
        }
    }
    
    @Suite("Prediction Model Tests")
    struct PredictionModelTests {
        
        @Test("Prediction direction enum values")
        func testPredictionDirectionValues() async throws {
            #expect(PredictionDirection.up.rawValue == "up")
            #expect(PredictionDirection.down.rawValue == "down")
            #expect(PredictionDirection.neutral.rawValue == "neutral")
        }
        
        @Test("Stock prediction model creation")
        func testStockPredictionCreation() async throws {
            let prediction = StockPrediction(
                symbol: "AAPL",
                predictedDirection: .up,
                confidence: 0.85,
                predictedChange: 3.2,
                timestamp: Date(),
                reasoning: "Strong earnings report and positive market sentiment"
            )
            
            #expect(prediction.symbol == "AAPL")
            #expect(prediction.predictedDirection == .up)
            #expect(prediction.confidence == 0.85)
            #expect(prediction.predictedChange == 3.2)
            #expect(!prediction.reasoning.isEmpty)
        }
    }
    
    @Suite("Alert Configuration Tests")
    struct AlertConfigTests {
        
        @Test("Default alert configuration")
        func testDefaultAlertConfig() async throws {
            let config = AlertConfig()
            
            #expect(config.enabledGlobal == true)
            #expect(config.changeThreshold == 5.0)
            #expect(config.confidenceThreshold == 0.7)
            #expect(config.alertStyle == .banner)
        }
        
        @Test("Alert style display names")
        func testAlertStyleDisplayNames() async throws {
            #expect(AlertStyle.push.displayName == "Push Notification")
            #expect(AlertStyle.banner.displayName == "Banner")
            #expect(AlertStyle.silent.displayName == "Silent")
        }
    }
    
    @Suite("Alpha Vantage Data Model Tests")
    struct AlphaVantageTests {
        
        @Test("StockQuote model creation")
        func testStockQuoteCreation() async throws {
            let quote = StockQuote(
                symbol: "AAPL",
                price: 150.25,
                change: 2.15,
                changePercent: 1.45,
                previousClose: 148.10,
                open: 149.50,
                high: 151.00,
                low: 148.75,
                volume: 45_230_100
            )
            
            #expect(quote.symbol == "AAPL")
            #expect(quote.price == 150.25)
            #expect(quote.change == 2.15)
            #expect(quote.changePercent == 1.45)
            #expect(quote.volume == 45_230_100)
        }
        
        @Test("HistoricalDataPoint model creation")
        func testHistoricalDataPointCreation() async throws {
            let dataPoint = HistoricalDataPoint(
                date: Date(),
                open: 148.50,
                high: 152.00,
                low: 147.25,
                close: 150.75,
                volume: 42_150_300
            )
            
            #expect(dataPoint.open == 148.50)
            #expect(dataPoint.high == 152.00)
            #expect(dataPoint.low == 147.25)
            #expect(dataPoint.close == 150.75)
            #expect(dataPoint.volume == 42_150_300)
        }
    }
    
    @Suite("Date Formatting Tests")
    struct DateFormattingTests {
        
        @Test("Date formatter for API responses")
        func testDateFormatteryyyyMMdd() async throws {
            let formatter = DateFormatter.yyyyMMdd
            let dateString = "2024-10-24"
            
            let date = try #require(formatter.date(from: dateString))
            let formattedBack = formatter.string(from: date)
            
            #expect(formattedBack == dateString, "Date formatting should be reversible")
        }
        
        @Test("Short date formatter")
        func testShortDateFormatter() async throws {
            let formatter = DateFormatter.shortDate
            let date = Date()
            let formattedDate = formatter.string(from: date)
            
            // Should be in format "Oct 24"
            #expect(formattedDate.count >= 5, "Short date format should contain month and day")
            #expect(formattedDate.contains(" "), "Short date should contain space between month and day")
        }
    }
}