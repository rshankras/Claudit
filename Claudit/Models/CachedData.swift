import Foundation
import SwiftData

/// Cached daily usage data (persisted in SwiftData)
@Model
final class CachedDailyUsage {
    @Attribute(.unique) var dateKey: String  // "2024-01-15"
    var date: Date
    var inputTokens: Int
    var outputTokens: Int
    var cacheReadTokens: Int
    var cacheWriteTokens: Int
    var totalCost: Double

    // Per-model breakdown stored as JSON
    var modelBreakdownJSON: Data?

    init(date: Date, usage: AggregatedUsage, cost: Double, modelCosts: [ClaudeModel: Double]) {
        self.dateKey = Self.key(for: date)
        self.date = date
        self.inputTokens = usage.inputTokens
        self.outputTokens = usage.outputTokens
        self.cacheReadTokens = usage.cacheReadTokens
        self.cacheWriteTokens = usage.cacheWriteTokens
        self.totalCost = cost

        // Encode model breakdown
        let breakdown = modelCosts.reduce(into: [String: Double]()) { result, pair in
            result[pair.key.rawValue] = pair.value
        }
        self.modelBreakdownJSON = try? JSONEncoder().encode(breakdown)
    }

    static func key(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    var costByModel: [ClaudeModel: Double] {
        guard let data = modelBreakdownJSON,
              let decoded = try? JSONDecoder().decode([String: Double].self, from: data) else {
            return [:]
        }
        return decoded.reduce(into: [:]) { result, pair in
            if let model = ClaudeModel(rawValue: pair.key) {
                result[model] = pair.value
            }
        }
    }
}

/// Cached project usage (persisted in SwiftData)
@Model
final class CachedProjectUsage {
    @Attribute(.unique) var projectPath: String
    var projectName: String
    var totalCost: Double
    var inputTokens: Int
    var outputTokens: Int
    var lastUpdated: Date

    init(projectPath: String, usage: AggregatedUsage, cost: Double) {
        self.projectPath = projectPath

        // Use same logic as ProjectUsage.projectName for consistency
        let lastComponent = (projectPath as NSString).lastPathComponent
        if projectPath.contains("/var/folders/") && lastComponent == "T" {
            self.projectName = "Temp Directory"
        } else if lastComponent.count == 1 && projectPath.contains("/private/") {
            self.projectName = "System: \(lastComponent)"
        } else {
            self.projectName = lastComponent
        }

        self.totalCost = cost
        self.inputTokens = usage.inputTokens
        self.outputTokens = usage.outputTokens
        self.lastUpdated = Date()
    }
}

/// Cached usage summary (single row, updated frequently)
@Model
final class CachedSummary {
    @Attribute(.unique) var id: String = "summary"
    var todayCost: Double
    var weekCost: Double
    var monthCost: Double
    var totalCost: Double
    var todayCacheHitPercent: Int
    var weekCacheHitPercent: Int
    var todayCacheSavings: Double
    var weekCacheSavings: Double
    var lastUpdated: Date

    init() {
        self.todayCost = 0
        self.weekCost = 0
        self.monthCost = 0
        self.totalCost = 0
        self.todayCacheHitPercent = 0
        self.weekCacheHitPercent = 0
        self.todayCacheSavings = 0
        self.weekCacheSavings = 0
        self.lastUpdated = Date()
    }
}
