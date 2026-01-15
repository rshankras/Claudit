import SwiftUI

struct MenuBarContentView: View {
    @Environment(StatsManager.self) private var statsManager: StatsManager?
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings
    @Environment(\.dismiss) private var dismiss

    private var settings = SettingsManager.shared

    var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider()
            quotaView
            Divider()
            costSummaryView
            Divider()
            cacheEfficiencyView
            Divider()
            projectBreakdownView
            Divider()
            if let manager = statsManager, !manager.recommendations.isEmpty {
                recommendationsView
                Divider()
            }
            modelBreakdownView
            Divider()
            footerView
        }
        .frame(width: 280)
    }

    private var headerView: some View {
        HStack {
            Text("Claudit")
                .font(.headline)

            Spacer()

            if statsManager?.isLoading == true {
                ProgressView()
                    .scaleEffect(0.7)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var quotaView: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let manager = statsManager, manager.usageResponse != nil {
                // Session quota
                if let session = manager.sessionUsage {
                    QuotaRow(
                        title: "Current Session",
                        percent: session.utilizationPercent,
                        resetDate: session.resetsAtDate,
                        color: quotaColor(for: session.utilizationPercent)
                    )
                }

                // Weekly all models
                if let weekly = manager.weeklyUsage {
                    QuotaRow(
                        title: "Weekly (all models)",
                        percent: weekly.utilizationPercent,
                        resetDate: weekly.resetsAtDate,
                        color: quotaColor(for: weekly.utilizationPercent)
                    )
                }

                // Weekly Sonnet
                if let sonnet = manager.sonnetUsage {
                    QuotaRow(
                        title: "Weekly (Sonnet)",
                        percent: sonnet.utilizationPercent,
                        resetDate: sonnet.resetsAtDate,
                        color: quotaColor(for: sonnet.utilizationPercent)
                    )
                }

                // Weekly Opus (if available)
                if let opus = manager.opusUsage {
                    QuotaRow(
                        title: "Weekly (Opus)",
                        percent: opus.utilizationPercent,
                        resetDate: opus.resetsAtDate,
                        color: quotaColor(for: opus.utilizationPercent)
                    )
                }

                // Extra usage status
                if let extra = manager.extraUsage {
                    HStack {
                        Text("Extra usage")
                            .font(.caption)
                        Spacer()
                        Text(extra.isEnabled ? "Enabled" : "Disabled")
                            .font(.caption)
                            .foregroundStyle(extra.isEnabled ? .green : .secondary)
                    }
                }

                // Pacing indicator (only shown when warning or critical)
                if let message = manager.pacingMessage {
                    HStack(spacing: 6) {
                        Image(systemName: manager.quotaPacingStatus == .critical ? "exclamationmark.triangle.fill" : "clock")
                            .foregroundStyle(pacingColor(for: manager.quotaPacingStatus))
                        Text(message)
                            .font(.caption2)
                            .foregroundStyle(pacingColor(for: manager.quotaPacingStatus))
                    }
                    .padding(.top, 4)
                }
            } else if let error = statsManager?.usageError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            } else {
                Text("Loading quota...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
    }

    private func quotaColor(for percent: Int) -> Color {
        if percent >= 90 { return .red }
        if percent >= 75 { return .orange }
        return .green
    }

    private func pacingColor(for status: StatsManager.PacingStatus) -> Color {
        switch status {
        case .safe: return .green
        case .warning: return .orange
        case .critical: return .red
        }
    }

    private var costSummaryView: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                CostCard(title: "Today", cost: statsManager?.todayCost ?? 0, tokens: statsManager?.todayTokens ?? 0)
                CostCard(title: "This Week", cost: statsManager?.weekCost ?? 0, tokens: statsManager?.weekTokens ?? 0)
            }
            HStack(spacing: 12) {
                CostCard(title: "This Month", cost: statsManager?.monthCost ?? 0, tokens: statsManager?.monthTokens ?? 0)
                CostCard(title: "All Time", cost: statsManager?.totalCost ?? 0, tokens: statsManager?.totalTokens ?? 0)
            }
        }
        .padding(12)
    }

    private var cacheEfficiencyView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Cache Efficiency")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let manager = statsManager {
                HStack(spacing: 16) {
                    // Today's cache efficiency
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Today")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 4) {
                            Text("\(manager.todayCacheHitPercent)%")
                                .font(.system(.title3, design: .monospaced, weight: .semibold))
                                .foregroundStyle(cacheColor(for: manager.todayCacheHitPercent))
                            Text("hit rate")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        if manager.todayCacheSavings > 0 {
                            Text("Saved \(formatCurrency(manager.todayCacheSavings))")
                                .font(.caption2)
                                .foregroundStyle(.green)
                        }
                    }

                    Spacer()

                    // This week's cache efficiency
                    VStack(alignment: .leading, spacing: 4) {
                        Text("This Week")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 4) {
                            Text("\(manager.weekCacheHitPercent)%")
                                .font(.system(.title3, design: .monospaced, weight: .semibold))
                                .foregroundStyle(cacheColor(for: manager.weekCacheHitPercent))
                            Text("hit rate")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        if manager.weekCacheSavings > 0 {
                            Text("Saved \(formatCurrency(manager.weekCacheSavings))")
                                .font(.caption2)
                                .foregroundStyle(.green)
                        }
                    }
                }
            } else {
                Text("No cache data")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
    }

    private func cacheColor(for percent: Int) -> Color {
        if percent >= 60 { return .green }
        if percent >= 30 { return .orange }
        return .red
    }

    private var recommendationsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Insights")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let manager = statsManager {
                ForEach(manager.recommendations) { rec in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "lightbulb.fill")
                            .foregroundStyle(.yellow)
                            .font(.caption)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(rec.detail)
                                .font(.caption)
                            Text("Could save ~\(formatCurrency(rec.potentialSavings))")
                                .font(.caption2)
                                .foregroundStyle(.green)
                        }
                    }
                }
            }
        }
        .padding(12)
    }

    private var projectBreakdownView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Projects (This Week)")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let manager = statsManager, !manager.projectCosts.isEmpty {
                let pricing = settings.modelPricing
                let totalCost = manager.projectCosts.reduce(0) { $0 + $1.cost(using: pricing) }

                // Show top 4 projects
                ForEach(manager.projectCosts.prefix(4)) { project in
                    let cost = project.cost(using: pricing)
                    let percent = totalCost > 0 ? Int(cost / totalCost * 100) : 0

                    HStack {
                        Image(systemName: "folder.fill")
                            .foregroundStyle(.secondary)
                            .font(.caption2)
                        Text(project.projectName)
                            .font(.caption)
                            .lineLimit(1)
                        Spacer()
                        Text("\(percent)%")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(formatCurrency(cost))
                            .font(.caption.monospacedDigit())
                    }
                }

                // Show "and X more" if there are more projects
                if manager.projectCosts.count > 4 {
                    Text("and \(manager.projectCosts.count - 4) more...")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("No project data")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
    }

    private var modelBreakdownView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("By Model")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let costs = statsManager?.cumulativeCosts, !costs.isEmpty {
                ForEach(costs) { cost in
                    HStack {
                        Circle()
                            .fill(cost.model.color)
                            .frame(width: 8, height: 8)
                        Text(cost.model.displayName)
                            .font(.caption)
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(formatCurrency(cost.totalCost))
                                .font(.caption.monospacedDigit())
                                .fontWeight(.semibold)
                            Text(cost.usage.totalTokens.formatTokenCount())
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } else {
                Text("No usage data")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
    }

    private var footerView: some View {
        HStack {
            if let lastUpdated = statsManager?.lastUpdated {
                Text("Updated \(lastUpdated, style: .relative) ago")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                openWindow(id: "dashboard")
                NSApp.activate(ignoringOtherApps: true)
                dismiss()
            } label: {
                Image(systemName: "chart.bar.xaxis")
            }
            .buttonStyle(.borderless)
            .help("Open Dashboard")

            Button {
                openSettings()
                NSApp.activate(ignoringOtherApps: true)
                dismiss()
            } label: {
                Image(systemName: "gear")
            }
            .buttonStyle(.borderless)
            .help("Settings")

            Button {
                statsManager?.loadStats()
                Task {
                    await statsManager?.fetchUsageFromAPI()
                }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .help("Refresh")

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.borderless)
            .keyboardShortcut("q")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func formatCurrency(_ value: Double) -> String {
        String(format: "$%.2f", value)
    }
}

struct CostCard: View {
    let title: String
    let cost: Double
    let tokens: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(String(format: "$%.2f", cost))
                .font(.system(.title3, design: .monospaced, weight: .semibold))
            Text("\(tokens.formatTokenCount()) tokens")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }
}

struct QuotaRow: View {
    let title: String
    let percent: Int
    let resetDate: Date?
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(percent)%")
                    .font(.caption.monospacedDigit().bold())
                    .foregroundStyle(color)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(color)
                        .frame(width: min(geometry.size.width, geometry.size.width * Double(percent) / 100.0), height: 6)
                }
            }
            .frame(height: 6)

            if let resetDate = resetDate {
                Text("Resets \(resetDate, style: .relative)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
