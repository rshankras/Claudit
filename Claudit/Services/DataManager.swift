import Foundation
import SwiftData
import os.log

/// Manages SwiftData persistence for cached usage data
@MainActor
final class DataManager {
    static let shared = DataManager()

    private static let logger = Logger(subsystem: "com.claudit", category: "data")

    let container: ModelContainer
    let context: ModelContext

    /// Database URL for cleanup purposes
    private static var databaseURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("Claudit", isDirectory: true)
        return appDir.appendingPathComponent("claudit-cache.store")
    }

    private init() {
        let schema = Schema([
            CachedDailyUsage.self,
            CachedProjectUsage.self,
            CachedSummary.self
        ])

        // Use app-specific directory
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("Claudit", isDirectory: true)

        // Create app directory if needed
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)

        let storeURL = appDir.appendingPathComponent("claudit-cache.store")
        let config = ModelConfiguration(url: storeURL)

        do {
            container = try ModelContainer(for: schema, configurations: config)
            context = ModelContext(container)
            context.autosaveEnabled = true
            Self.logger.info("SwiftData initialized at \(storeURL.path)")
        } catch {
            // Schema mismatch - delete old database and retry
            Self.logger.warning("SwiftData schema error, resetting database: \(error.localizedDescription)")
            Self.deleteDatabase()

            do {
                container = try ModelContainer(for: schema, configurations: config)
                context = ModelContext(container)
                context.autosaveEnabled = true
                Self.logger.info("SwiftData recreated successfully")
            } catch {
                fatalError("Failed to create ModelContainer after reset: \(error)")
            }
        }
    }

    /// Delete the database files (for schema migration recovery)
    private static func deleteDatabase() {
        let fm = FileManager.default
        let basePath = databaseURL.path

        // SwiftData creates multiple files with extensions
        let extensions = ["", "-shm", "-wal"]
        for ext in extensions {
            let path = basePath + ext
            if fm.fileExists(atPath: path) {
                try? fm.removeItem(atPath: path)
                logger.info("Deleted: \(path)")
            }
        }
    }

    // MARK: - Summary

    /// Get or create the cached summary
    func getSummary() -> CachedSummary {
        let descriptor = FetchDescriptor<CachedSummary>(
            predicate: #Predicate { $0.id == "summary" }
        )
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        let summary = CachedSummary()
        context.insert(summary)
        return summary
    }

    /// Update summary with current values
    func updateSummary(
        todayCost: Double,
        weekCost: Double,
        monthCost: Double,
        totalCost: Double,
        todayCacheHitPercent: Int,
        weekCacheHitPercent: Int,
        todayCacheSavings: Double,
        weekCacheSavings: Double
    ) {
        let summary = getSummary()
        summary.todayCost = todayCost
        summary.weekCost = weekCost
        summary.monthCost = monthCost
        summary.totalCost = totalCost
        summary.todayCacheHitPercent = todayCacheHitPercent
        summary.weekCacheHitPercent = weekCacheHitPercent
        summary.todayCacheSavings = todayCacheSavings
        summary.weekCacheSavings = weekCacheSavings
        summary.lastUpdated = Date()
    }

    // MARK: - Daily Usage

    /// Get daily usage for a date range
    func getDailyUsage(from startDate: Date, to endDate: Date) -> [CachedDailyUsage] {
        let descriptor = FetchDescriptor<CachedDailyUsage>(
            predicate: #Predicate { $0.date >= startDate && $0.date <= endDate },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    /// Update or insert daily usage
    func upsertDailyUsage(date: Date, usage: AggregatedUsage, pricing: [ClaudeModel: ModelPricing]) {
        let key = CachedDailyUsage.key(for: date)
        let descriptor = FetchDescriptor<CachedDailyUsage>(
            predicate: #Predicate { $0.dateKey == key }
        )

        let cost = usage.cost(using: pricing)
        let modelCosts = usage.costByModel(using: pricing)

        if let existing = try? context.fetch(descriptor).first {
            // Update existing
            existing.inputTokens = usage.inputTokens
            existing.outputTokens = usage.outputTokens
            existing.cacheReadTokens = usage.cacheReadTokens
            existing.cacheWriteTokens = usage.cacheWriteTokens
            existing.totalCost = cost
            let breakdown = modelCosts.reduce(into: [String: Double]()) { result, pair in
                result[pair.key.rawValue] = pair.value
            }
            existing.modelBreakdownJSON = try? JSONEncoder().encode(breakdown)
        } else {
            // Insert new
            let cached = CachedDailyUsage(date: date, usage: usage, cost: cost, modelCosts: modelCosts)
            context.insert(cached)
        }
    }

    /// Batch update daily usage from parsed data
    func batchUpdateDailyUsage(_ dailyUsage: [Date: AggregatedUsage], pricing: [ClaudeModel: ModelPricing]) {
        for (date, usage) in dailyUsage {
            upsertDailyUsage(date: date, usage: usage, pricing: pricing)
        }
        try? context.save()
    }

    // MARK: - Project Usage

    /// Get all project usage sorted by cost
    func getProjectUsage() -> [CachedProjectUsage] {
        let descriptor = FetchDescriptor<CachedProjectUsage>(
            sortBy: [SortDescriptor(\.totalCost, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    /// Clear and replace all project usage (weekly data)
    func replaceProjectUsage(_ projects: [String: AggregatedUsage], pricing: [ClaudeModel: ModelPricing]) {
        // Delete old data
        let descriptor = FetchDescriptor<CachedProjectUsage>()
        if let existing = try? context.fetch(descriptor) {
            for item in existing {
                context.delete(item)
            }
        }

        // Insert new
        for (path, usage) in projects {
            let cost = usage.cost(using: pricing)
            let cached = CachedProjectUsage(projectPath: path, usage: usage, cost: cost)
            context.insert(cached)
        }
        try? context.save()
    }

    // MARK: - Cleanup

    /// Delete data older than specified days
    func cleanupOldData(olderThanDays days: Int = 90) {
        guard let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) else { return }

        let descriptor = FetchDescriptor<CachedDailyUsage>(
            predicate: #Predicate { $0.date < cutoffDate }
        )
        if let old = try? context.fetch(descriptor) {
            for item in old {
                context.delete(item)
            }
        }
        try? context.save()
    }
}
