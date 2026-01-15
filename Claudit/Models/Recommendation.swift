import Foundation

/// A model usage recommendation
struct ModelRecommendation: Identifiable, Sendable {
    let id: UUID
    let suggestion: String
    let detail: String
    let potentialSavings: Double
    let taskCount: Int

    init(suggestion: String, detail: String, potentialSavings: Double, taskCount: Int) {
        self.id = UUID()
        self.suggestion = suggestion
        self.detail = detail
        self.potentialSavings = potentialSavings
        self.taskCount = taskCount
    }
}

/// Analyzes model usage patterns to generate recommendations
struct RecommendationEngine: Sendable {
    // Threshold: tasks with output < 500 tokens are considered "small"
    private static let smallTaskThreshold = 500

    /// Analyze usage and generate recommendations
    nonisolated static func analyze(entries: [SessionEntry], pricing: [ClaudeModel: ModelPricing]) -> [ModelRecommendation] {
        var recommendations: [ModelRecommendation] = []

        // Track small tasks by model
        var smallTasksByModel: [ClaudeModel: [(outputTokens: Int, inputTokens: Int, cost: Double)]] = [:]

        for entry in entries {
            guard entry.isAssistantMessage,
                  let usage = entry.message?.usage,
                  let modelId = entry.message?.model,
                  let model = ClaudeModel(modelId: modelId) else { continue }

            let outputTokens = usage.outputTokens

            // Track small tasks for expensive models
            if outputTokens < smallTaskThreshold && (model == .opus || model == .sonnet) {
                guard let price = pricing[model] else { continue }

                let inputTokens = usage.inputTokens + usage.totalCacheRead + usage.totalCacheWrite
                let taskCost = Double(inputTokens) / 1000.0 * price.inputPer1K +
                               Double(outputTokens) / 1000.0 * price.outputPer1K

                var tasks = smallTasksByModel[model] ?? []
                tasks.append((outputTokens, inputTokens, taskCost))
                smallTasksByModel[model] = tasks
            }
        }

        // Generate recommendation for Opus -> Haiku
        if let opusTasks = smallTasksByModel[.opus], opusTasks.count >= 3 {
            let totalOpusCost = opusTasks.reduce(0) { $0 + $1.cost }

            // Calculate what it would cost with Haiku
            guard let haikuPrice = pricing[.haiku] else { return recommendations }
            let haikuCost = opusTasks.reduce(0.0) { total, task in
                total + Double(task.inputTokens) / 1000.0 * haikuPrice.inputPer1K +
                       Double(task.outputTokens) / 1000.0 * haikuPrice.outputPer1K
            }

            let savings = totalOpusCost - haikuCost
            if savings > 0.10 {  // Only recommend if savings > $0.10
                recommendations.append(ModelRecommendation(
                    suggestion: "Use Haiku for small tasks",
                    detail: "\(opusTasks.count) small tasks used Opus",
                    potentialSavings: savings,
                    taskCount: opusTasks.count
                ))
            }
        }

        // Generate recommendation for Sonnet -> Haiku
        if let sonnetTasks = smallTasksByModel[.sonnet], sonnetTasks.count >= 5 {
            let totalSonnetCost = sonnetTasks.reduce(0) { $0 + $1.cost }

            guard let haikuPrice = pricing[.haiku] else { return recommendations }
            let haikuCost = sonnetTasks.reduce(0.0) { total, task in
                total + Double(task.inputTokens) / 1000.0 * haikuPrice.inputPer1K +
                       Double(task.outputTokens) / 1000.0 * haikuPrice.outputPer1K
            }

            let savings = totalSonnetCost - haikuCost
            if savings > 0.10 {
                recommendations.append(ModelRecommendation(
                    suggestion: "Use Haiku for small tasks",
                    detail: "\(sonnetTasks.count) small tasks used Sonnet",
                    potentialSavings: savings,
                    taskCount: sonnetTasks.count
                ))
            }
        }

        return recommendations
    }
}
