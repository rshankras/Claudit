import Foundation

struct CostCalculator {
    let pricing: [ClaudeModel: ModelPricing]

    /// Calculate cost from detailed ModelUsage (cumulative totals)
    func calculateCost(for usage: ModelUsage, model: ClaudeModel) -> Double {
        guard let price = pricing[model] else { return 0 }

        let inputCost = Double(usage.inputTokens) / 1000.0 * price.inputPer1K
        let outputCost = Double(usage.outputTokens) / 1000.0 * price.outputPer1K
        let cacheReadCost = Double(usage.cacheReadInputTokens) / 1000.0 * price.cacheReadPer1K
        let cacheWriteCost = Double(usage.cacheCreationInputTokens) / 1000.0 * price.cacheWritePer1K

        return inputCost + outputCost + cacheReadCost + cacheWriteCost
    }

    /// Calculate cost breakdown from ModelUsage
    func calculateCostBreakdown(for usage: ModelUsage, model: ClaudeModel) -> CostBreakdown {
        guard let price = pricing[model] else {
            return CostBreakdown(input: 0, output: 0, cacheRead: 0, cacheWrite: 0)
        }

        return CostBreakdown(
            input: Double(usage.inputTokens) / 1000.0 * price.inputPer1K,
            output: Double(usage.outputTokens) / 1000.0 * price.outputPer1K,
            cacheRead: Double(usage.cacheReadInputTokens) / 1000.0 * price.cacheReadPer1K,
            cacheWrite: Double(usage.cacheCreationInputTokens) / 1000.0 * price.cacheWritePer1K
        )
    }

    /// Estimate daily cost using cumulative ratios
    /// Since daily data only has total tokens, we estimate breakdown from cumulative usage
    func estimateDailyCost(
        totalTokens: Int,
        model: ClaudeModel,
        cumulativeUsage: ModelUsage?
    ) -> Double {
        guard let price = pricing[model] else { return 0 }

        guard let cumulative = cumulativeUsage, cumulative.totalTokens > 0 else {
            // Fallback: assume 30% input, 70% output (typical conversation ratio)
            let inputTokens = Double(totalTokens) * 0.3
            let outputTokens = Double(totalTokens) * 0.7
            return (inputTokens / 1000.0 * price.inputPer1K) +
                   (outputTokens / 1000.0 * price.outputPer1K)
        }

        // Calculate ratios from cumulative data
        let totalCumulative = Double(cumulative.totalTokens)

        let inputRatio = Double(cumulative.inputTokens) / totalCumulative
        let outputRatio = Double(cumulative.outputTokens) / totalCumulative
        let cacheReadRatio = Double(cumulative.cacheReadInputTokens) / totalCumulative
        let cacheWriteRatio = Double(cumulative.cacheCreationInputTokens) / totalCumulative

        let tokens = Double(totalTokens)
        return (tokens * inputRatio / 1000.0 * price.inputPer1K) +
               (tokens * outputRatio / 1000.0 * price.outputPer1K) +
               (tokens * cacheReadRatio / 1000.0 * price.cacheReadPer1K) +
               (tokens * cacheWriteRatio / 1000.0 * price.cacheWritePer1K)
    }
}

struct CostBreakdown {
    let input: Double
    let output: Double
    let cacheRead: Double
    let cacheWrite: Double

    var total: Double {
        input + output + cacheRead + cacheWrite
    }
}
