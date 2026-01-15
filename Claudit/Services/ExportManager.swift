import Foundation
import AppKit
import UniformTypeIdentifiers

/// Handles CSV export of usage data
enum ExportManager {

    // MARK: - Daily Usage Export

    static func exportDailyUsage(_ costs: [DailyCost], pricing: [ClaudeModel: ModelPricing]) throws -> String {
        var csv = "Date,Total Cost,Total Tokens,Messages,Sessions"

        // Add model columns
        for model in ClaudeModel.allCases {
            csv += ",\(model.shortName) Cost"
        }
        csv += "\n"

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        for cost in costs.sorted(by: { $0.date > $1.date }) {
            let totalTokens = cost.tokensByModel.values.reduce(0, +)
            let row = [
                dateFormatter.string(from: cost.date),
                String(format: "%.2f", cost.totalCost),
                "\(totalTokens)",
                "\(cost.messageCount)",
                "\(cost.sessionCount)"
            ]

            csv += row.joined(separator: ",")

            // Add per-model costs
            for model in ClaudeModel.allCases {
                let modelCost = cost.costByModel[model] ?? 0
                csv += ",\(String(format: "%.2f", modelCost))"
            }
            csv += "\n"
        }

        return csv
    }

    // MARK: - Project Usage Export

    static func exportProjectUsage(_ projects: [ProjectUsage], pricing: [ClaudeModel: ModelPricing]) throws -> String {
        var csv = "Project,Path,Total Cost,Input Tokens,Output Tokens,Cache Read,Cache Write\n"

        for project in projects.sorted(by: { $0.cost(using: pricing) > $1.cost(using: pricing) }) {
            let cost = project.cost(using: pricing)
            let row = [
                escapeCSV(project.projectName),
                escapeCSV(project.projectPath),
                String(format: "%.2f", cost),
                "\(project.usage.inputTokens)",
                "\(project.usage.outputTokens)",
                "\(project.usage.cacheReadTokens)",
                "\(project.usage.cacheWriteTokens)"
            ]
            csv += row.joined(separator: ",") + "\n"
        }

        return csv
    }

    // MARK: - Summary Export

    static func exportSummary(_ stats: StatsManager, pricing: [ClaudeModel: ModelPricing]) throws -> String {
        var csv = "Metric,Value\n"

        let rows: [(String, String)] = [
            ("Today Cost", String(format: "$%.2f", stats.todayCost)),
            ("Week Cost", String(format: "$%.2f", stats.weekCost)),
            ("Month Cost", String(format: "$%.2f", stats.monthCost)),
            ("All Time Cost", String(format: "$%.2f", stats.totalCost)),
            ("Today Tokens", "\(stats.todayTokens)"),
            ("Week Tokens", "\(stats.weekTokens)"),
            ("Today Cache Hit %", "\(stats.todayCacheHitPercent)%"),
            ("Week Cache Hit %", "\(stats.weekCacheHitPercent)%"),
            ("Today Cache Savings", String(format: "$%.2f", stats.todayCacheSavings)),
            ("Week Cache Savings", String(format: "$%.2f", stats.weekCacheSavings)),
            ("Total Sessions", "\(stats.stats?.totalSessions ?? 0)"),
            ("Total Messages", "\(stats.stats?.totalMessages ?? 0)"),
            ("Export Date", DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .short))
        ]

        for (metric, value) in rows {
            csv += "\(metric),\(value)\n"
        }

        // Add per-model breakdown
        csv += "\nModel Breakdown\n"
        csv += "Model,Cost,Input Tokens,Output Tokens\n"

        for cost in stats.cumulativeCosts {
            let row = [
                cost.model.displayName,
                String(format: "%.2f", cost.totalCost),
                "\(cost.usage.inputTokens)",
                "\(cost.usage.outputTokens)"
            ]
            csv += row.joined(separator: ",") + "\n"
        }

        return csv
    }

    // MARK: - Save Dialog

    @MainActor
    static func saveCSV(content: String, suggestedName: String) async -> Bool {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = suggestedName
        panel.message = "Choose where to save the CSV file"

        let response = await panel.begin()

        guard response == .OK, let url = panel.url else {
            return false
        }

        do {
            try content.write(to: url, atomically: true, encoding: .utf8)
            return true
        } catch {
            return false
        }
    }

    // MARK: - Helpers

    private static func escapeCSV(_ string: String) -> String {
        // If string contains comma, quote, or newline, wrap in quotes and escape quotes
        if string.contains(",") || string.contains("\"") || string.contains("\n") {
            let escaped = string.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return string
    }
}
