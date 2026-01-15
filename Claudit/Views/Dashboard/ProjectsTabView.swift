import SwiftUI

struct ProjectsTabView: View {
    let statsManager: StatsManager?
    @Binding var selectedTimeRange: DashboardView.TimeRange
    @State private var sortOrder: ProjectSortOrder = .costDescending
    @State private var searchText = ""

    enum ProjectSortOrder {
        case costDescending
        case costAscending
        case name
        case tokens
    }

    private var projectsForTimeRange: [ProjectUsage] {
        guard let manager = statsManager else { return [] }

        switch selectedTimeRange {
        case .week:
            return manager.projectCostsWeek
        case .month:
            return manager.projectCostsMonth
        case .all:
            return manager.projectCostsAllTime
        }
    }

    private func getTotalCostForRange() -> Double {
        guard let manager = statsManager else { return 0 }

        switch selectedTimeRange {
        case .week:
            return manager.weekCost
        case .month:
            return manager.monthCost
        case .all:
            return manager.totalCost
        }
    }

    var filteredProjects: [ProjectUsage] {
        let pricing = SettingsManager.shared.modelPricing

        // Apply search filter
        let filtered = searchText.isEmpty
            ? projectsForTimeRange
            : projectsForTimeRange.filter { $0.projectName.localizedCaseInsensitiveContains(searchText) }

        // Apply sorting
        return filtered.sorted(by: { lhs, rhs in
            switch sortOrder {
            case .costDescending:
                return lhs.cost(using: pricing) > rhs.cost(using: pricing)
            case .costAscending:
                return lhs.cost(using: pricing) < rhs.cost(using: pricing)
            case .name:
                return lhs.projectName < rhs.projectName
            case .tokens:
                let lhsTotal = lhs.usage.inputTokens + lhs.usage.outputTokens + lhs.usage.cacheReadTokens + lhs.usage.cacheWriteTokens
                let rhsTotal = rhs.usage.inputTokens + rhs.usage.outputTokens + rhs.usage.cacheReadTokens + rhs.usage.cacheWriteTokens
                return lhsTotal > rhsTotal
            }
        })
    }

    var body: some View {
        VStack(spacing: 0) {
            // Time Range Picker
            Picker("Time Range", selection: $selectedTimeRange) {
                ForEach(DashboardView.TimeRange.allCases, id: \.self) { range in
                    Text(range.rawValue).tag(range)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            Divider()

            // Toolbar
            HStack {
                TextField("Search projects...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 300)

                Spacer()

                Picker("Sort", selection: $sortOrder) {
                    Text("Cost ↓").tag(ProjectSortOrder.costDescending)
                    Text("Cost ↑").tag(ProjectSortOrder.costAscending)
                    Text("Name").tag(ProjectSortOrder.name)
                    Text("Tokens").tag(ProjectSortOrder.tokens)
                }
                .pickerStyle(.menu)
            }
            .padding()

            Divider()

            // Project List
            if filteredProjects.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: searchText.isEmpty ? "folder" : "magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text(searchText.isEmpty ? "No project data" : "No projects found")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    if !searchText.isEmpty {
                        Text("Try a different search term")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: .textBackgroundColor))
            } else {
                Table(filteredProjects) {
                    TableColumn("Project") { project in
                        HStack(spacing: 8) {
                            Image(systemName: "folder.fill")
                                .foregroundStyle(.secondary)
                            Text(project.projectName)
                                .lineLimit(1)
                        }
                    }
                    .width(min: 150, ideal: 250)

                    TableColumn("Cost") { project in
                        Text(String(format: "$%.2f", project.cost(using: SettingsManager.shared.modelPricing)))
                            .monospacedDigit()
                            .fontWeight(.semibold)
                    }
                    .width(min: 80, ideal: 100)

                    TableColumn("Tokens") { project in
                        let totalTokens = project.usage.inputTokens + project.usage.outputTokens + project.usage.cacheReadTokens + project.usage.cacheWriteTokens
                        Text(totalTokens.formatTokenCount())
                            .monospacedDigit()
                    }
                    .width(min: 80, ideal: 100)

                    TableColumn("% of Total") { project in
                        let totalCost = getTotalCostForRange()
                        let percent = totalCost > 0 ? (project.cost(using: SettingsManager.shared.modelPricing) / totalCost) * 100 : 0
                        Text(String(format: "%.1f%%", percent))
                            .monospacedDigit()
                    }
                    .width(min: 80, ideal: 100)
                }
                .background(Color(nsColor: .textBackgroundColor))
            }
        }
    }
}
