import SwiftUI
import Charts

struct DashboardView: View {
    @Environment(StatsManager.self) private var statsManager: StatsManager?
    @Environment(\.settingsManager) private var settings
    @State private var selectedTimeRange: TimeRange = .week
    @State private var selectedTab: DashboardTab = .overview
    @State private var showExportAlert = false
    @State private var exportAlertMessage = ""

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

    enum DashboardTab: String, CaseIterable {
        case overview
        case projects
        case models
        case efficiency

        var label: String {
            switch self {
            case .overview: return "Overview"
            case .projects: return "Projects"
            case .models: return "Models"
            case .efficiency: return "Efficiency"
            }
        }

        var icon: String {
            switch self {
            case .overview: return "chart.bar"
            case .projects: return "folder"
            case .models: return "cpu"
            case .efficiency: return "gauge.with.dots.needle.50percent"
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            sidebarView
                .navigationSplitViewColumnWidth(min: 200, ideal: 220)
        } detail: {
            TabView(selection: $selectedTab) {
                // Tab 1: Overview (current charts + table)
                OverviewTabView(statsManager: statsManager, selectedTimeRange: $selectedTimeRange)
                    .tabItem {
                        Label(DashboardTab.overview.label, systemImage: DashboardTab.overview.icon)
                    }
                    .tag(DashboardTab.overview)

                // Tab 2: Projects (full list with search and sort)
                ProjectsTabView(statsManager: statsManager, selectedTimeRange: $selectedTimeRange)
                    .tabItem {
                        Label(DashboardTab.projects.label, systemImage: DashboardTab.projects.icon)
                    }
                    .tag(DashboardTab.projects)

                // Tab 3: Models (detailed breakdown with table)
                ModelsTabView(statsManager: statsManager)
                    .tabItem {
                        Label(DashboardTab.models.label, systemImage: DashboardTab.models.icon)
                    }
                    .tag(DashboardTab.models)

                // Tab 4: Efficiency (cache efficiency and recommendations)
                EfficiencyTabView(statsManager: statsManager)
                    .tabItem {
                        Label(DashboardTab.efficiency.label, systemImage: DashboardTab.efficiency.icon)
                    }
                    .tag(DashboardTab.efficiency)
            }
        }
        .navigationTitle("Claudit")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        exportDailyUsage()
                    } label: {
                        Label("Export Daily Usage", systemImage: "calendar")
                    }

                    Button {
                        exportProjects()
                    } label: {
                        Label("Export Projects", systemImage: "folder")
                    }

                    Button {
                        exportSummary()
                    } label: {
                        Label("Export Summary", systemImage: "doc.text")
                    }
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .disabled(statsManager == nil)
            }
        }
        .alert("Export", isPresented: $showExportAlert) {
            Button("OK") {}
        } message: {
            Text(exportAlertMessage)
        }
    }

    // MARK: - Export Functions

    private func exportDailyUsage() {
        guard let stats = statsManager else { return }

        Task {
            do {
                let csv = try ExportManager.exportDailyUsage(stats.dailyCosts, pricing: settings.modelPricing)
                let dateStr = DateFormatters.yyyyMMdd.string(from: Date())
                let success = await ExportManager.saveCSV(content: csv, suggestedName: "claudit-daily-usage-\(dateStr).csv")
                if success {
                    exportAlertMessage = "Daily usage exported successfully."
                    showExportAlert = true
                }
            } catch {
                exportAlertMessage = "Export failed: \(error.localizedDescription)"
                showExportAlert = true
            }
        }
    }

    private func exportProjects() {
        guard let stats = statsManager else { return }

        Task {
            do {
                let projects: [ProjectUsage]
                switch selectedTimeRange {
                case .week: projects = stats.projectCostsWeek
                case .month: projects = stats.projectCostsMonth
                case .all: projects = stats.projectCostsAllTime
                }

                let csv = try ExportManager.exportProjectUsage(projects, pricing: settings.modelPricing)
                let dateStr = DateFormatters.yyyyMMdd.string(from: Date())
                let success = await ExportManager.saveCSV(content: csv, suggestedName: "claudit-projects-\(selectedTimeRange.rawValue.lowercased())-\(dateStr).csv")
                if success {
                    exportAlertMessage = "Project usage exported successfully."
                    showExportAlert = true
                }
            } catch {
                exportAlertMessage = "Export failed: \(error.localizedDescription)"
                showExportAlert = true
            }
        }
    }

    private func exportSummary() {
        guard let stats = statsManager else { return }

        Task {
            do {
                let csv = try ExportManager.exportSummary(stats, pricing: settings.modelPricing)
                let dateStr = DateFormatters.yyyyMMdd.string(from: Date())
                let success = await ExportManager.saveCSV(content: csv, suggestedName: "claudit-summary-\(dateStr).csv")
                if success {
                    exportAlertMessage = "Summary exported successfully."
                    showExportAlert = true
                }
            } catch {
                exportAlertMessage = "Export failed: \(error.localizedDescription)"
                showExportAlert = true
            }
        }
    }

    private var sidebarView: some View {
        List {
            Section("Summary") {
                SummaryRow(title: "Today", cost: statsManager?.todayCost ?? 0, tokens: statsManager?.todayTokens ?? 0)
                SummaryRow(title: "This Week", cost: statsManager?.weekCost ?? 0, tokens: statsManager?.weekTokens ?? 0)
                SummaryRow(title: "This Month", cost: statsManager?.monthCost ?? 0, tokens: statsManager?.monthTokens ?? 0)
                SummaryRow(title: "All Time", cost: statsManager?.totalCost ?? 0, tokens: statsManager?.totalTokens ?? 0)
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
}

struct SummaryRow: View {
    let title: String
    let cost: Double
    let tokens: Int

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "$%.2f", cost))
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.semibold)
                Text("\(tokens.formatTokenCount()) tokens")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
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

                    TableColumn("Tokens") { cost in
                        let tokens = cost.tokensByModel.values.reduce(0, +)
                        Text(tokens.formatTokenCount())
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
