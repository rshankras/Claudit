import SwiftUI

struct ModelsTabView: View {
    let statsManager: StatsManager?

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Donut Chart with Legend
                if let costs = statsManager?.cumulativeCosts, !costs.isEmpty {
                    GroupBox {
                        ModelBreakdownView(costs: costs)
                            .frame(height: 300)
                    } label: {
                        Text("Cost Distribution")
                            .font(.headline)
                    }

                    // Detailed Cost Breakdown Table
                    GroupBox {
                        Table(costs) {
                            TableColumn("Model") { cost in
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(cost.model.color)
                                        .frame(width: 12, height: 12)
                                    Text(cost.model.displayName)
                                }
                            }
                            .width(min: 100, ideal: 150)

                            TableColumn("Total Cost") { cost in
                                Text(String(format: "$%.2f", cost.totalCost))
                                    .monospacedDigit()
                                    .fontWeight(.semibold)
                            }
                            .width(min: 80, ideal: 100)

                            TableColumn("Tokens") { cost in
                                Text(cost.usage.totalTokens.formatTokenCount())
                                    .monospacedDigit()
                            }
                            .width(min: 80, ideal: 100)

                            TableColumn("Input") { cost in
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(String(format: "$%.2f", cost.inputCost))
                                        .monospacedDigit()
                                    Text(cost.usage.inputTokens.formatTokenCount())
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .width(min: 80, ideal: 100)

                            TableColumn("Output") { cost in
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(String(format: "$%.2f", cost.outputCost))
                                        .monospacedDigit()
                                    Text(cost.usage.outputTokens.formatTokenCount())
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .width(min: 80, ideal: 100)

                            TableColumn("Cache Read") { cost in
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(String(format: "$%.2f", cost.cacheReadCost))
                                        .monospacedDigit()
                                    Text(cost.usage.cacheReadInputTokens.formatTokenCount())
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .width(min: 80, ideal: 110)

                            TableColumn("Cache Write") { cost in
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(String(format: "$%.2f", cost.cacheWriteCost))
                                        .monospacedDigit()
                                    Text(cost.usage.cacheCreationInputTokens.formatTokenCount())
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .width(min: 80, ideal: 110)
                        }
                        .frame(minHeight: 200)
                    } label: {
                        Text("Detailed Breakdown")
                            .font(.headline)
                    }
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "cpu")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("No model usage data")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .padding()
        }
        .background(Color(nsColor: .textBackgroundColor))
    }
}
