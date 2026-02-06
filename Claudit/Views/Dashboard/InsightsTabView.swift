import SwiftUI
import Charts

struct InsightsTabView: View {
    let statsManager: StatsManager?

    private var summary: InsightsSummary? {
        statsManager?.insightsSummary
    }

    var body: some View {
        ScrollView {
            if let summary, summary.totalSessions > 0 {
                VStack(spacing: 20) {
                    // 1. Score Card — key metrics at a glance
                    scoreCard(summary)

                    // 2. Areas to Improve — actionable recommendations
                    recommendationsSection(summary)

                    // 3. Friction — log + breakdown in one place
                    frictionSection(summary)

                    // 4. Activity & Outcomes — what you do + how it goes
                    activitySection(summary)

                    // 5. Quality — satisfaction + helpfulness
                    qualitySection(summary)

                    // Footer
                    stalenessHint(summary)
                }
                .padding()
            } else {
                emptyState
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "brain.head.profile")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No Insights Data")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Run **/insights** in Claude Code to generate session analysis data.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Text("Facet files will appear at ~/.claude/usage-data/facets/")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding()
    }

    // MARK: - 1. Score Card

    private func scoreCard(_ summary: InsightsSummary) -> some View {
        let achieved = summary.outcomeDistribution["fully_achieved", default: 0]
        let achieveRate = summary.totalSessions > 0
            ? Int((Double(achieved) / Double(summary.totalSessions) * 100).rounded())
            : 0

        return GroupBox {
            VStack(spacing: 16) {
                HStack(spacing: 0) {
                    metricCell(label: "Score", value: "\(summary.productivityScore)",
                               subtitle: "out of 100", color: scoreColor(summary.productivityScore))
                    Divider().frame(height: 60)
                    metricCell(label: "Achieved", value: "\(achieveRate)%",
                               subtitle: "fully achieved", color: scoreColor(achieveRate))
                    Divider().frame(height: 60)
                    metricCell(label: "Sessions", value: "\(summary.totalSessions)",
                               subtitle: "analyzed", color: nil)
                }
                Divider()
                HStack(spacing: 0) {
                    metricCell(label: "Friction", value: "\(summary.frictionRate)%",
                               subtitle: "sessions with friction", color: frictionRateColor(summary.frictionRate))
                    Divider().frame(height: 60)
                    metricCell(label: "Helpfulness", value: "\(summary.helpfulnessRate)%",
                               subtitle: "essential or very helpful", color: scoreColor(summary.helpfulnessRate))
                }
            }
            .padding()
        } label: {
            Text("Overview")
                .font(.headline)
        }
    }

    private func metricCell(label: String, value: String, subtitle: String, color: Color?) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.title, design: .rounded, weight: .bold))
                .foregroundStyle(color ?? .primary)
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 2. Areas to Improve

    private func recommendationsSection(_ summary: InsightsSummary) -> some View {
        GroupBox {
            if summary.recommendations.isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.title2)
                    Text("No actionable recommendations — your workflow looks solid!")
                        .foregroundStyle(.secondary)
                }
                .padding()
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(summary.recommendations) { rec in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: rec.icon)
                                .foregroundStyle(severityColor(rec.severity))
                                .font(.title3)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(rec.title)
                                    .font(.headline)
                                Text(rec.detail)
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(10)
                        .background(severityBackground(rec.severity))
                        .cornerRadius(8)
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 4)
            }
        } label: {
            Label("Areas to Improve", systemImage: "lightbulb.fill")
                .font(.headline)
        }
    }

    // MARK: - 3. Friction (Log + Breakdown)

    private func frictionSection(_ summary: InsightsSummary) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 16) {
                // Friction log entries (the actionable part)
                if summary.frictionLog.isEmpty {
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.title2)
                        Text("No friction recorded — smooth sailing!")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                } else {
                    ForEach(summary.frictionLog.prefix(5)) { entry in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 8) {
                                Image(systemName: outcomeIcon(entry.outcome))
                                    .foregroundStyle(outcomeColor(entry.outcome))
                                    .font(.caption)
                                Text(entry.frictionTypes.map { formatLabel($0) }.joined(separator: ", "))
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.secondary)
                            }
                            Text(entry.frictionDetail)
                                .font(.callout)
                                .lineLimit(2)
                                .help(entry.frictionDetail)
                            Text(entry.briefSummary)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                        }
                        .padding(8)
                        .background(Color.secondary.opacity(0.06))
                        .cornerRadius(6)
                    }
                }

                // Collapsible breakdown donut
                if !summary.frictionBreakdown.isEmpty {
                    DisclosureGroup {
                        frictionDonut(summary.frictionBreakdown)
                    } label: {
                        Text("Friction type breakdown")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 4)
        } label: {
            Label("Friction (\(summary.frictionLog.count) sessions)", systemImage: "exclamationmark.bubble")
                .font(.headline)
        }
    }

    private func frictionDonut(_ breakdown: [String: Int]) -> some View {
        let data = breakdown.sorted { $0.value > $1.value }
        let total = data.reduce(0) { $0 + $1.value }

        return HStack(spacing: 20) {
            Chart(data, id: \.key) { item in
                SectorMark(
                    angle: .value("Count", item.value),
                    innerRadius: .ratio(0.5),
                    angularInset: 2
                )
                .foregroundStyle(frictionColor(for: item.key, in: data.map(\.key)))
                .cornerRadius(4)
            }
            .frame(width: 120, height: 120)

            VStack(alignment: .leading, spacing: 6) {
                ForEach(data, id: \.key) { item in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(frictionColor(for: item.key, in: data.map(\.key)))
                            .frame(width: 8, height: 8)
                        Text(formatLabel(item.key))
                            .font(.caption)
                        Spacer()
                        Text("\(item.value) (\(percentage(item.value, of: total))%)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.top, 8)
    }

    // MARK: - 4. Activity & Outcomes

    private func activitySection(_ summary: InsightsSummary) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 16) {
                // Outcomes bar chart (always visible — compact)
                let outcomeData = sortedOutcomes(summary.outcomeDistribution)
                if !outcomeData.isEmpty {
                    Chart(outcomeData, id: \.key) { item in
                        BarMark(
                            x: .value("Count", item.value),
                            y: .value("Outcome", formatLabel(item.key))
                        )
                        .foregroundStyle(outcomeColor(item.key))
                        .cornerRadius(4)
                        .annotation(position: .trailing) {
                            Text("\(item.value)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .chartXAxis(.hidden)
                    .frame(height: CGFloat(outcomeData.count) * 36)
                }

                // Collapsible: Session types
                DisclosureGroup {
                    sessionTypesContent(summary.sessionTypeBreakdown)
                } label: {
                    Text("Session types")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                // Collapsible: What you work on
                DisclosureGroup {
                    goalCategoriesContent(summary.goalCategoryBreakdown)
                } label: {
                    Text("What you work on (top 8)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 4)
        } label: {
            Label("Activity & Outcomes", systemImage: "chart.bar")
                .font(.headline)
        }
    }

    private func sessionTypesContent(_ breakdown: [String: Int]) -> some View {
        let data = breakdown.sorted { $0.value > $1.value }
        return VStack(alignment: .leading, spacing: 6) {
            ForEach(data, id: \.key) { item in
                HStack {
                    Text(formatLabel(item.key))
                        .font(.callout)
                    Spacer()
                    Text("\(item.value)")
                        .font(.system(.callout, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.top, 4)
    }

    private func goalCategoriesContent(_ breakdown: [String: Int]) -> some View {
        let data = Array(breakdown.sorted { $0.value > $1.value }.prefix(8))
        return VStack(alignment: .leading, spacing: 6) {
            ForEach(data, id: \.key) { item in
                HStack {
                    Text(formatLabel(item.key))
                        .font(.callout)
                    Spacer()
                    Text("\(item.value)")
                        .font(.system(.callout, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.top, 4)
    }

    // MARK: - 5. Quality (Satisfaction + Helpfulness + Success)

    private func qualitySection(_ summary: InsightsSummary) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 16) {
                // Helpfulness → success rate (always visible — key insight)
                if !summary.helpfulnessCorrelations.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Helpfulness → Success Rate")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        ForEach(summary.helpfulnessCorrelations) { item in
                            HStack {
                                Text(formatLabel(item.level))
                                    .font(.callout)
                                    .frame(width: 130, alignment: .leading)
                                ProgressView(value: Double(item.successRate), total: 100)
                                    .tint(scoreColor(item.successRate))
                                Text("\(item.successRate)%")
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 36, alignment: .trailing)
                            }
                        }
                    }
                }

                // What helped most (always visible — compact)
                let topSuccess = Array(summary.topSuccessTypes.sorted { $0.value > $1.value }.prefix(3))
                if !topSuccess.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("What Helped Most")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        ForEach(topSuccess, id: \.key) { item in
                            HStack(spacing: 6) {
                                Image(systemName: "star.fill")
                                    .foregroundStyle(.yellow)
                                    .font(.caption2)
                                Text(formatLabel(item.key))
                                    .font(.callout)
                                Spacer()
                                Text("\(item.value)")
                                    .font(.system(.callout, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                // Collapsible: Satisfaction breakdown
                DisclosureGroup {
                    satisfactionContent(summary.satisfactionBreakdown)
                } label: {
                    Text("Satisfaction breakdown")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 4)
        } label: {
            Label("Quality", systemImage: "hand.thumbsup")
                .font(.headline)
        }
    }

    private func satisfactionContent(_ breakdown: [String: Int]) -> some View {
        let data = sortedSatisfaction(breakdown)
        let total = data.reduce(0) { $0 + $1.value }

        return VStack(alignment: .leading, spacing: 6) {
            ForEach(data, id: \.key) { item in
                HStack {
                    Circle()
                        .fill(satisfactionColor(item.key))
                        .frame(width: 8, height: 8)
                    Text(formatLabel(item.key))
                        .font(.callout)
                    Spacer()
                    Text("\(item.value)")
                        .font(.system(.callout, design: .monospaced))
                        .foregroundStyle(.secondary)
                    if total > 0 {
                        Text("(\(percentage(item.value, of: total))%)")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .frame(width: 40, alignment: .trailing)
                    }
                }
            }
        }
        .padding(.top, 4)
    }

    // MARK: - Staleness Hint

    private func stalenessHint(_ summary: InsightsSummary) -> some View {
        VStack(spacing: 4) {
            if let date = summary.lastGeneratedDate {
                let interval = Date().timeIntervalSince(date)
                let age = formattedAge(interval)
                HStack(spacing: 4) {
                    Image(systemName: interval > 86400 ? "exclamationmark.circle" : "clock")
                        .font(.caption)
                    Text("Last updated \(age) (\(summary.totalSessions) sessions)")
                }
                .foregroundStyle(interval > 86400 ? .secondary : .tertiary)
            }
            HStack(spacing: 4) {
                Image(systemName: "terminal")
                    .font(.caption2)
                Text("Run /insights in Claude Code to include new sessions")
            }
            .foregroundStyle(.tertiary)
        }
        .font(.caption)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.top, 8)
    }

    private func formattedAge(_ interval: TimeInterval) -> String {
        let minutes = Int(interval / 60)
        if minutes < 1 { return "just now" }
        if minutes < 60 { return "\(minutes)m ago" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours)h ago" }
        let days = hours / 24
        if days == 1 { return "yesterday" }
        return "\(days) days ago"
    }

    // MARK: - Helpers

    private func frictionRateColor(_ rate: Int) -> Color {
        if rate <= 30 { return .green }
        if rate <= 50 { return .orange }
        return .red
    }

    private func scoreColor(_ score: Int) -> Color {
        if score >= 75 { return .green }
        if score >= 50 { return .orange }
        return .red
    }

    private func outcomeColor(_ outcome: String) -> Color {
        switch outcome {
        case "fully_achieved": return .green
        case "mostly_achieved": return .yellow
        case "partially_achieved": return .orange
        case "not_achieved": return .red
        default: return .gray
        }
    }

    private func outcomeIcon(_ outcome: String) -> String {
        switch outcome {
        case "fully_achieved": return "checkmark.circle.fill"
        case "mostly_achieved": return "checkmark.circle"
        case "partially_achieved": return "minus.circle"
        case "not_achieved": return "xmark.circle.fill"
        default: return "questionmark.circle"
        }
    }

    private func satisfactionColor(_ level: String) -> Color {
        switch level {
        case "happy": return .green
        case "satisfied": return .green.opacity(0.7)
        case "likely_satisfied": return .blue
        case "dissatisfied": return .orange
        case "frustrated": return .red
        default: return .gray
        }
    }

    private func severityColor(_ severity: InsightRecommendation.Severity) -> Color {
        switch severity {
        case .high: return .red
        case .medium: return .orange
        case .low: return .green
        }
    }

    private func severityBackground(_ severity: InsightRecommendation.Severity) -> Color {
        switch severity {
        case .high: return .red.opacity(0.1)
        case .medium: return .orange.opacity(0.1)
        case .low: return .green.opacity(0.1)
        }
    }

    private func frictionColor(for key: String, in keys: [String]) -> Color {
        let colors: [Color] = [.red, .orange, .yellow, .purple, .pink, .brown, .gray]
        guard let index = keys.firstIndex(of: key) else { return .gray }
        return colors[index % colors.count]
    }

    private func formatLabel(_ snakeCase: String) -> String {
        snakeCase
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }

    private func percentage(_ value: Int, of total: Int) -> Int {
        guard total > 0 else { return 0 }
        return Int((Double(value) / Double(total) * 100).rounded())
    }

    private func sortedOutcomes(_ dict: [String: Int]) -> [(key: String, value: Int)] {
        let order = ["fully_achieved", "mostly_achieved", "partially_achieved", "not_achieved"]
        return dict.sorted { a, b in
            let ai = order.firstIndex(of: a.key) ?? order.count
            let bi = order.firstIndex(of: b.key) ?? order.count
            return ai < bi
        }
    }

    private func sortedSatisfaction(_ dict: [String: Int]) -> [(key: String, value: Int)] {
        let order = ["happy", "satisfied", "likely_satisfied", "dissatisfied", "frustrated"]
        return dict.sorted { a, b in
            let ai = order.firstIndex(of: a.key) ?? order.count
            let bi = order.firstIndex(of: b.key) ?? order.count
            return ai < bi
        }
    }
}
