import SwiftUI
import Charts

struct DashboardView: View {
    @Environment(StatsManager.self) private var statsManager: StatsManager?
    @State private var selectedTimeRange: TimeRange = .week

    enum TimeRange: String, CaseIterable {
        case week = "Week"
        case month = "Month"
        case all = "All Time"

        var days: Int? {
            switch self {
            case .week: return 7
            case .month: return 30
            case .all: return nil
            }
        }
    }

    var filteredCosts: [DailyCost] {
        guard let costs = statsManager?.dailyCosts else { return [] }
        guard let days = selectedTimeRange.days else { return costs }

        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        return costs.filter { $0.date >= cutoff }.sorted { $0.date < $1.date }
    }

    var body: some View {
        NavigationSplitView {
            sidebarView
                .navigationSplitViewColumnWidth(min: 200, ideal: 220)
        } detail: {
            detailView
        }
        .navigationTitle("Claudit")
    }

    private var sidebarView: some View {
        List {
            Section("Summary") {
                SummaryRow(title: "Today", cost: statsManager?.todayCost ?? 0)
                SummaryRow(title: "This Week", cost: statsManager?.weekCost ?? 0)
                SummaryRow(title: "This Month", cost: statsManager?.monthCost ?? 0)
                SummaryRow(title: "All Time", cost: statsManager?.totalCost ?? 0)
            }

            Section("By Model") {
                if let costs = statsManager?.cumulativeCosts, !costs.isEmpty {
                    ForEach(costs) { cost in
                        ModelRow(cost: cost)
                    }
                } else {
                    Text("No usage data")
                        .foregroundStyle(.secondary)
                }
            }

            Section("Statistics") {
                if let stats = statsManager?.stats {
                    LabeledContent("Total Sessions", value: "\(stats.totalSessions)")
                    LabeledContent("Total Messages", value: "\(stats.totalMessages)")
                }
            }
        }
        .listStyle(.sidebar)
    }

    private var detailView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Time Range Picker
                Picker("Time Range", selection: $selectedTimeRange) {
                    ForEach(TimeRange.allCases, id: \.self) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                // Cost Chart
                CostChartView(dailyCosts: filteredCosts)
                    .frame(height: 300)
                    .padding()

                // Model Breakdown Chart
                if let costs = statsManager?.cumulativeCosts, !costs.isEmpty {
                    ModelBreakdownView(costs: costs)
                        .frame(height: 250)
                        .padding()
                }

                // Daily Details Table
                DailyDetailsTable(dailyCosts: filteredCosts)
                    .padding()
            }
            .padding(.vertical)
        }
        .background(Color(nsColor: .textBackgroundColor))
    }
}

struct SummaryRow: View {
    let title: String
    let cost: Double

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(String(format: "$%.2f", cost))
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }
}

struct ModelRow: View {
    let cost: CumulativeCost

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Circle()
                    .fill(cost.model.color)
                    .frame(width: 10, height: 10)
                Text(cost.model.displayName)
                Spacer()
                Text(String(format: "$%.2f", cost.totalCost))
                    .font(.system(.body, design: .monospaced))
            }

            Text("\(formatTokens(cost.usage.inputTokens)) in, \(formatTokens(cost.usage.outputTokens)) out")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func formatTokens(_ tokens: Int) -> String {
        if tokens >= 1_000_000_000 {
            return String(format: "%.1fB", Double(tokens) / 1_000_000_000)
        } else if tokens >= 1_000_000 {
            return String(format: "%.1fM", Double(tokens) / 1_000_000)
        } else if tokens >= 1000 {
            return String(format: "%.1fK", Double(tokens) / 1000)
        }
        return "\(tokens)"
    }
}

struct DailyDetailsTable: View {
    let dailyCosts: [DailyCost]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Daily Breakdown")
                .font(.headline)

            if dailyCosts.isEmpty {
                Text("No data for selected period")
                    .foregroundStyle(.secondary)
            } else {
                Table(dailyCosts.sorted { $0.date > $1.date }) {
                    TableColumn("Date") { cost in
                        Text(cost.date, style: .date)
                    }
                    .width(min: 100, ideal: 120)

                    TableColumn("Cost") { cost in
                        Text(String(format: "$%.2f", cost.totalCost))
                            .font(.system(.body, design: .monospaced))
                    }
                    .width(min: 80, ideal: 100)

                    TableColumn("Messages") { cost in
                        Text("\(cost.messageCount)")
                    }
                    .width(min: 60, ideal: 80)

                    TableColumn("Sessions") { cost in
                        Text("\(cost.sessionCount)")
                    }
                    .width(min: 60, ideal: 80)

                    TableColumn("Tool Calls") { cost in
                        Text("\(cost.toolCallCount)")
                    }
                    .width(min: 60, ideal: 80)
                }
                .frame(minHeight: 200)
            }
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
    }
}
