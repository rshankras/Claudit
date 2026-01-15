import Foundation

/// Represents a single entry in a Claude Code JSONL session file
struct SessionEntry: Codable, Sendable {
    let type: String
    let timestamp: String
    let message: SessionMessage?
    let sessionId: String?
    let cwd: String?

    var parsedTimestamp: Date? {
        ISO8601DateFormatter().date(from: timestamp)
    }

    var isAssistantMessage: Bool {
        type == "assistant" && message?.usage != nil
    }
}

struct SessionMessage: Codable, Sendable {
    let model: String?
    let role: String?
    let usage: SessionUsage?
}

struct SessionUsage: Codable, Sendable {
    let inputTokens: Int
    let outputTokens: Int
    let cacheCreationInputTokens: Int?
    let cacheReadInputTokens: Int?
    let cacheCreation: CacheCreation?

    enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
        case cacheCreationInputTokens = "cache_creation_input_tokens"
        case cacheReadInputTokens = "cache_read_input_tokens"
        case cacheCreation = "cache_creation"
    }

    var totalCacheWrite: Int {
        let base = cacheCreationInputTokens ?? 0
        let ephemeral5m = cacheCreation?.ephemeral5mInputTokens ?? 0
        let ephemeral1h = cacheCreation?.ephemeral1hInputTokens ?? 0
        return base + ephemeral5m + ephemeral1h
    }

    var totalCacheRead: Int {
        cacheReadInputTokens ?? 0
    }
}

struct CacheCreation: Codable, Sendable {
    let ephemeral5mInputTokens: Int?
    let ephemeral1hInputTokens: Int?

    enum CodingKeys: String, CodingKey {
        case ephemeral5mInputTokens = "ephemeral_5m_input_tokens"
        case ephemeral1hInputTokens = "ephemeral_1h_input_tokens"
    }
}

/// Aggregated usage for a time period
struct AggregatedUsage: Sendable {
    var inputTokens: Int = 0
    var outputTokens: Int = 0
    var cacheReadTokens: Int = 0
    var cacheWriteTokens: Int = 0

    var byModel: [ClaudeModel: ModelTokens] = [:]

    mutating func add(entry: SessionEntry) {
        guard let usage = entry.message?.usage,
              let modelId = entry.message?.model,
              let model = ClaudeModel(modelId: modelId) else { return }

        inputTokens += usage.inputTokens
        outputTokens += usage.outputTokens
        cacheReadTokens += usage.totalCacheRead
        cacheWriteTokens += usage.totalCacheWrite

        var modelTokens = byModel[model] ?? ModelTokens()
        modelTokens.inputTokens += usage.inputTokens
        modelTokens.outputTokens += usage.outputTokens
        modelTokens.cacheReadTokens += usage.totalCacheRead
        modelTokens.cacheWriteTokens += usage.totalCacheWrite
        byModel[model] = modelTokens
    }

    func cost(using pricing: [ClaudeModel: ModelPricing]) -> Double {
        var total = 0.0
        for (model, tokens) in byModel {
            guard let price = pricing[model] else { continue }
            total += Double(tokens.inputTokens) / 1000.0 * price.inputPer1K
            total += Double(tokens.outputTokens) / 1000.0 * price.outputPer1K
            total += Double(tokens.cacheReadTokens) / 1000.0 * price.cacheReadPer1K
            total += Double(tokens.cacheWriteTokens) / 1000.0 * price.cacheWritePer1K
        }
        return total
    }

    func costByModel(using pricing: [ClaudeModel: ModelPricing]) -> [ClaudeModel: Double] {
        var result: [ClaudeModel: Double] = [:]
        for (model, tokens) in byModel {
            guard let price = pricing[model] else { continue }
            var cost = 0.0
            cost += Double(tokens.inputTokens) / 1000.0 * price.inputPer1K
            cost += Double(tokens.outputTokens) / 1000.0 * price.outputPer1K
            cost += Double(tokens.cacheReadTokens) / 1000.0 * price.cacheReadPer1K
            cost += Double(tokens.cacheWriteTokens) / 1000.0 * price.cacheWritePer1K
            result[model] = cost
        }
        return result
    }

    /// Total input tokens (uncached + cache read + cache write)
    var totalInputTokens: Int {
        inputTokens + cacheReadTokens + cacheWriteTokens
    }

    /// Cache hit rate (0.0 - 1.0)
    /// Represents the portion of input tokens served from cache
    var cacheHitRate: Double {
        guard totalInputTokens > 0 else { return 0 }
        return Double(cacheReadTokens) / Double(totalInputTokens)
    }

    /// Cache hit rate as a percentage (0 - 100)
    var cacheHitPercent: Int {
        Int(cacheHitRate * 100)
    }

    /// Calculate money saved by using cache instead of regular input
    /// Savings = cache_read_tokens * (input_price - cache_read_price)
    func cacheSavings(using pricing: [ClaudeModel: ModelPricing]) -> Double {
        var savings = 0.0
        for (model, tokens) in byModel {
            guard let price = pricing[model], tokens.cacheReadTokens > 0 else { continue }
            // What we would have paid at full input price minus what we actually paid
            let fullInputCost = Double(tokens.cacheReadTokens) / 1000.0 * price.inputPer1K
            let actualCacheCost = Double(tokens.cacheReadTokens) / 1000.0 * price.cacheReadPer1K
            savings += fullInputCost - actualCacheCost
        }
        return savings
    }
}

struct ModelTokens: Sendable {
    var inputTokens: Int = 0
    var outputTokens: Int = 0
    var cacheReadTokens: Int = 0
    var cacheWriteTokens: Int = 0
}
