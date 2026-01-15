import SwiftUI
import Charts

struct ModelBreakdownView: View {
    let costs: [CumulativeCost]

    private var totalCost: Double {
        costs.reduce(0) { $0 + $1.totalCost }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Cost by Model")
                .font(.headline)

            HStack(spacing: 20) {
                // Pie Chart
                pieChart
                    .frame(width: 150, height: 150)

                // Legend
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(costs) { cost in
                        HStack {
                            Circle()
                                .fill(cost.model.color)
                                .frame(width: 12, height: 12)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(cost.model.displayName)
                                    .font(.subheadline)
                                Text(String(format: "$%.2f (%.1f%%)", cost.totalCost, percentage(for: cost)))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
    }

    private var pieChart: some View {
        Chart(costs) { cost in
            SectorMark(
                angle: .value("Cost", cost.totalCost),
                innerRadius: .ratio(0.5),
                angularInset: 2
            )
            .foregroundStyle(cost.model.color)
            .cornerRadius(4)
        }
    }

    private func percentage(for cost: CumulativeCost) -> Double {
        guard totalCost > 0 else { return 0 }
        return (cost.totalCost / totalCost) * 100
    }
}

struct ModelCostBreakdownView: View {
    let cost: CumulativeCost

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(cost.model.color)
                    .frame(width: 12, height: 12)
                Text(cost.model.displayName)
                    .font(.headline)
                Spacer()
                Text(String(format: "$%.2f", cost.totalCost))
                    .font(.system(.title3, design: .monospaced, weight: .semibold))
            }

            Divider()

            Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 8) {
                GridRow {
                    Text("Input")
                        .foregroundStyle(.secondary)
                    Text(String(format: "$%.2f", cost.inputCost))
                        .font(.system(.body, design: .monospaced))
                }
                GridRow {
                    Text("Output")
                        .foregroundStyle(.secondary)
                    Text(String(format: "$%.2f", cost.outputCost))
                        .font(.system(.body, design: .monospaced))
                }
                GridRow {
                    Text("Cache Read")
                        .foregroundStyle(.secondary)
                    Text(String(format: "$%.2f", cost.cacheReadCost))
                        .font(.system(.body, design: .monospaced))
                }
                GridRow {
                    Text("Cache Write")
                        .foregroundStyle(.secondary)
                    Text(String(format: "$%.2f", cost.cacheWriteCost))
                        .font(.system(.body, design: .monospaced))
                }
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
    }
}

#Preview {
    let opus = ModelUsage(
        inputTokens: 100000,
        outputTokens: 500000,
        cacheReadInputTokens: 1000000,
        cacheCreationInputTokens: 50000,
        webSearchRequests: 0,
        costUSD: 0,
        contextWindow: 0
    )

    let sonnet = ModelUsage(
        inputTokens: 200000,
        outputTokens: 800000,
        cacheReadInputTokens: 2000000,
        cacheCreationInputTokens: 100000,
        webSearchRequests: 0,
        costUSD: 0,
        contextWindow: 0
    )

    let calculator = CostCalculator(pricing: SettingsManager.defaultPricing)

    return ModelBreakdownView(costs: [
        CumulativeCost(
            model: .opus,
            totalCost: 85.50,
            breakdown: calculator.calculateCostBreakdown(for: opus, model: .opus),
            usage: opus
        ),
        CumulativeCost(
            model: .sonnet,
            totalCost: 42.30,
            breakdown: calculator.calculateCostBreakdown(for: sonnet, model: .sonnet),
            usage: sonnet
        )
    ])
    .frame(width: 400, height: 300)
    .padding()
}
