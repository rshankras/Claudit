import Foundation

/// Processed daily cost data for views
struct DailyCost: Identifiable {
    let date: Date
    let totalCost: Double
    let costByModel: [ClaudeModel: Double]
    let tokensByModel: [ClaudeModel: Int]
    let activity: DailyActivity?

    var id: Date { date }

    var messageCount: Int {
        activity?.messageCount ?? 0
    }

    var sessionCount: Int {
        activity?.sessionCount ?? 0
    }

    var toolCallCount: Int {
        activity?.toolCallCount ?? 0
    }
}

/// Cumulative cost per model with breakdown
struct CumulativeCost: Identifiable {
    let model: ClaudeModel
    let totalCost: Double
    let breakdown: CostBreakdown
    let usage: ModelUsage

    var id: String { model.rawValue }

    var inputCost: Double { breakdown.input }
    var outputCost: Double { breakdown.output }
    var cacheReadCost: Double { breakdown.cacheRead }
    var cacheWriteCost: Double { breakdown.cacheWrite }
}

/// Summary statistics
struct UsageSummary {
    let todayCost: Double
    let weekCost: Double
    let monthCost: Double
    let totalCost: Double

    let todayTokens: Int
    let weekTokens: Int
    let monthTokens: Int
    let totalTokens: Int

    let totalSessions: Int
    let totalMessages: Int
}
