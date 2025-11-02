// BackgroundTaskManager.swift
// Schedules and handles background threshold evaluations using BGTaskScheduler.

import Foundation
import SwiftUI
import BackgroundTasks

final class BackgroundTaskManager {
    static let shared = BackgroundTaskManager()
    private init() {}
    // NOTE: This type is not main-actor isolated. Constrain main-only work to specific methods.

    // Use your own identifier, also add it to Info.plist under Permitted background task scheduler identifiers
    static let taskIdentifier = "com.example.app.alertsEvaluation"

    func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.taskIdentifier, using: nil) { task in
            Task { @MainActor in
                self.handleAppRefresh(task: task as! BGAppRefreshTask)
            }
        }
    }

    @MainActor
    func scheduleNext(using settings: NotificationSettings) {
        let request = BGAppRefreshTaskRequest(identifier: Self.taskIdentifier)
        // Earliest allowed start date based on selected frequency
        request.earliestBeginDate = Date(timeIntervalSinceNow: settings.frequency.interval)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            // Handle scheduling failure if needed
        }
    }

    @MainActor
    func scheduleNext() {
        scheduleNext(using: .shared)
    }

    @MainActor
    private func handleAppRefresh(task: BGAppRefreshTask) {
        // Schedule the next refresh right away to maintain cadence.
        scheduleNext()

        // Create a Task to perform the evaluation.
        let evaluationTask = Task {
            await performEvaluation()
        }

        // The expiration handler is called when the system needs to terminate the task.
        task.expirationHandler = {
            evaluationTask.cancel()
        }

        // Await the task's completion and notify the system.
        Task {
            // await the result of the evaluation
            _ = await evaluationTask.result
            
            // Inform the system that the task is complete.
            // The success parameter indicates whether there's more work to do.
            task.setTaskCompleted(success: !evaluationTask.isCancelled)
        }
    }
    
    // MARK: - Threshold Evaluation
    
    private func fetchMetrics() async -> (confidence: Double, risk: Double, profit: Double) {
        // Obtain live metrics from providers.
        _ = getPortfolioStore()
        _ = getAIService()
        
        // TODO: Replace with real API calls that compute the changes you care about.
        // To implement this, you would typically:
        // 1. Fetch the latest data:
        //    await portfolioStore.refreshAllPrices()
        //    await aiService.generateMultiProviderInsights(for: portfolioStore.items)
        //
        // 2. Compare the new data with previously stored values to calculate deltas.
        //
        // 3. Return the calculated deltas.
        // Example placeholder methods (these do not exist):
        // let confidence = await aiService.latestConfidenceChange(for: portfolioStore)
        // let risk = await portfolioStore.latestRiskChange()
        // let profit = await aiService.latestProfitLikelihoodDelta(for: portfolioStore)
        // return (confidence, risk, profit)
        
        // Fallback placeholders.
        return (confidence: 12, risk: 5, profit: 18)
    }

    @MainActor
    private func performEvaluation() async {
        let settings = NotificationSettings.shared
        let metrics = await fetchMetrics()

        if settings.enableConfidenceAlerts && metrics.confidence >= settings.confidenceChangeThreshold {
            await NotificationManager.shared.postAlert(
                title: "Confidence Alert",
                body: "AI confidence changed by \(Int(metrics.confidence))%, exceeding your \(Int(settings.confidenceChangeThreshold))% threshold.")
        }
        if settings.enableRiskAlerts && metrics.risk >= settings.riskLevelChangeThreshold {
            await NotificationManager.shared.postAlert(
                title: "Risk Alert",
                body: "Risk level changed by \(Int(metrics.risk)), exceeding your \(Int(settings.riskLevelChangeThreshold)) threshold.")
        }
        if settings.enableProfitAlerts && metrics.profit >= settings.profitLikelihoodChangeThreshold {
            await NotificationManager.shared.postAlert(
                title: "Profit Alert",
                body: "Profit likelihood changed by \(Int(metrics.profit))%, exceeding your \(Int(settings.profitLikelihoodChangeThreshold))% threshold.")
        }
    }

    // MARK: - Provider Adapters
    private func getPortfolioStore() -> UnifiedPortfolioManager {
        // Use the shared instance since it has private initialization
        return UnifiedPortfolioManager.shared
    }

    private func getAIService() -> MultiProviderAIService {
        // Create a new MultiProviderAIService instance for the background task.
        return MultiProviderAIService()
    }
}

