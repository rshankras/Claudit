import Foundation

enum InsightsParser {
    private static let facetsDirectory: URL = {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".claude/usage-data/facets")
    }()

    /// Returns (insights, most recent file modification date)
    static func loadInsights() -> (insights: [SessionInsight], lastModified: Date?) {
        let fm = FileManager.default
        guard fm.fileExists(atPath: facetsDirectory.path) else { return ([], nil) }

        guard let files = try? fm.contentsOfDirectory(
            at: facetsDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: .skipsHiddenFiles
        ) else { return ([], nil) }

        let decoder = JSONDecoder()
        var insights: [SessionInsight] = []
        var newestDate: Date?

        for file in files where file.pathExtension == "json" {
            guard let data = try? Data(contentsOf: file),
                  let insight = try? decoder.decode(SessionInsight.self, from: data) else {
                continue
            }
            insights.append(insight)

            if let modDate = try? file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate {
                if newestDate == nil || modDate > newestDate! {
                    newestDate = modDate
                }
            }
        }

        return (insights, newestDate)
    }

    static func summarize(_ insights: [SessionInsight], lastModified: Date?) -> InsightsSummary {
        guard !insights.isEmpty else { return .empty }

        var outcomeDistribution: [String: Int] = [:]
        var frictionBreakdown: [String: Int] = [:]
        var sessionTypeBreakdown: [String: Int] = [:]
        var satisfactionBreakdown: [String: Int] = [:]
        var goalCategoryBreakdown: [String: Int] = [:]
        var successTypes: [String: Int] = [:]
        var helpfulnessBreakdown: [String: Int] = [:]

        var totalOutcomeScore = 0.0

        for insight in insights {
            // Outcomes
            outcomeDistribution[insight.outcome, default: 0] += 1
            totalOutcomeScore += outcomeScore(insight.outcome)

            // Friction
            for (type, count) in insight.frictionCounts {
                frictionBreakdown[type, default: 0] += count
            }

            // Session types
            sessionTypeBreakdown[insight.sessionType, default: 0] += 1

            // Satisfaction
            for (level, count) in insight.userSatisfactionCounts {
                satisfactionBreakdown[level, default: 0] += count
            }

            // Goal categories
            for (category, count) in insight.goalCategories {
                goalCategoryBreakdown[category, default: 0] += count
            }

            // Success types
            if !insight.primarySuccess.isEmpty {
                successTypes[insight.primarySuccess, default: 0] += 1
            }

            // Helpfulness
            helpfulnessBreakdown[insight.claudeHelpfulness, default: 0] += 1
        }

        let productivityScore = Int((totalOutcomeScore / Double(insights.count)).rounded())

        // Friction rate
        let sessionsWithFriction = insights.filter { !$0.frictionCounts.isEmpty }.count
        let frictionRate = Int((Double(sessionsWithFriction) / Double(insights.count) * 100).rounded())

        // Helpfulness rate (essential + very_helpful)
        let helpfulCount = helpfulnessBreakdown["essential", default: 0] + helpfulnessBreakdown["very_helpful", default: 0]
        let helpfulnessRate = Int((Double(helpfulCount) / Double(insights.count) * 100).rounded())

        // Friction log — sessions with non-empty friction_detail
        let frictionLog = insights
            .filter { !$0.frictionDetail.isEmpty }
            .map { insight in
                FrictionLogEntry(
                    sessionId: insight.sessionId,
                    outcome: insight.outcome,
                    frictionDetail: insight.frictionDetail,
                    frictionTypes: Array(insight.frictionCounts.keys),
                    briefSummary: insight.briefSummary
                )
            }

        // Helpfulness → outcome correlation
        var helpOutcome: [String: (total: Int, fully: Int)] = [:]
        for insight in insights {
            var entry = helpOutcome[insight.claudeHelpfulness] ?? (total: 0, fully: 0)
            entry.total += 1
            if insight.outcome == "fully_achieved" { entry.fully += 1 }
            helpOutcome[insight.claudeHelpfulness] = entry
        }
        let helpfulnessOrder = ["essential", "very_helpful", "moderately_helpful", "slightly_helpful", "unhelpful"]
        let helpfulnessCorrelations = helpfulnessOrder.compactMap { level -> HelpfulnessCorrelation? in
            guard let data = helpOutcome[level] else { return nil }
            return HelpfulnessCorrelation(level: level, sessionCount: data.total, fullyAchievedCount: data.fully)
        }

        // Session type → satisfaction correlation
        var typeSat: [String: (positive: Int, negative: Int, total: Int)] = [:]
        for insight in insights {
            var entry = typeSat[insight.sessionType] ?? (positive: 0, negative: 0, total: 0)
            for (level, count) in insight.userSatisfactionCounts {
                entry.total += count
                if ["satisfied", "likely_satisfied", "happy"].contains(level) {
                    entry.positive += count
                } else if ["dissatisfied", "frustrated"].contains(level) {
                    entry.negative += count
                }
            }
            typeSat[insight.sessionType] = entry
        }
        let sessionTypeSatisfactions = typeSat
            .map { SessionTypeSatisfaction(sessionType: $0.key, positiveCount: $0.value.positive, negativeCount: $0.value.negative, totalCount: $0.value.total) }
            .sorted { $0.positiveRate > $1.positiveRate }

        let recommendations = generateRecommendations(
            insights: insights,
            outcomeDistribution: outcomeDistribution,
            frictionBreakdown: frictionBreakdown,
            sessionTypeBreakdown: sessionTypeBreakdown,
            satisfactionBreakdown: satisfactionBreakdown,
            goalCategoryBreakdown: goalCategoryBreakdown
        )

        return InsightsSummary(
            totalSessions: insights.count,
            productivityScore: productivityScore,
            frictionRate: frictionRate,
            helpfulnessRate: helpfulnessRate,
            outcomeDistribution: outcomeDistribution,
            frictionBreakdown: frictionBreakdown,
            sessionTypeBreakdown: sessionTypeBreakdown,
            satisfactionBreakdown: satisfactionBreakdown,
            goalCategoryBreakdown: goalCategoryBreakdown,
            topSuccessTypes: successTypes,
            helpfulnessBreakdown: helpfulnessBreakdown,
            recommendations: recommendations,
            frictionLog: frictionLog,
            helpfulnessCorrelations: helpfulnessCorrelations,
            sessionTypeSatisfactions: sessionTypeSatisfactions,
            lastGeneratedDate: lastModified
        )
    }

    // MARK: - Recommendation Generation

    private static func generateRecommendations(
        insights: [SessionInsight],
        outcomeDistribution: [String: Int],
        frictionBreakdown: [String: Int],
        sessionTypeBreakdown: [String: Int],
        satisfactionBreakdown: [String: Int],
        goalCategoryBreakdown: [String: Int]
    ) -> [InsightRecommendation] {
        var recs: [InsightRecommendation] = []
        let total = insights.count
        guard total >= 3 else { return recs }

        // 1. Top friction source — actionable tip per type
        if let topFriction = frictionBreakdown.max(by: { $0.value < $1.value }), topFriction.value >= 3 {
            let tip = frictionTip(topFriction.key)
            recs.append(InsightRecommendation(
                icon: "exclamationmark.triangle.fill",
                title: tip.title,
                detail: "\(topFriction.value) occurrences of \(formatLabel(topFriction.key)). \(tip.advice)",
                severity: topFriction.value >= 10 ? .high : .medium
            ))
        }

        // 2. Multi-task sessions with low achievement
        let multiTaskSessions = insights.filter { $0.sessionType == "multi_task" }
        if multiTaskSessions.count >= 3 {
            let fullyAchieved = multiTaskSessions.filter { $0.outcome == "fully_achieved" }.count
            let achieveRate = Double(fullyAchieved) / Double(multiTaskSessions.count)
            if achieveRate < 0.5 {
                let pct = Int((achieveRate * 100).rounded())
                recs.append(InsightRecommendation(
                    icon: "arrow.triangle.branch",
                    title: "Break up multi-task sessions",
                    detail: "Only \(pct)% of multi-task sessions fully achieved their goals. Single-task sessions tend to have higher success rates — try splitting complex requests into focused sessions.",
                    severity: achieveRate < 0.3 ? .high : .medium
                ))
            }
        }

        // 3. Frustration / dissatisfaction alert
        let frustrated = satisfactionBreakdown["frustrated", default: 0]
        let dissatisfied = satisfactionBreakdown["dissatisfied", default: 0]
        let negativeCount = frustrated + dissatisfied
        let totalSatisfaction = satisfactionBreakdown.values.reduce(0, +)
        if negativeCount >= 3, totalSatisfaction > 0 {
            let pct = Int((Double(negativeCount) / Double(totalSatisfaction) * 100).rounded())
            recs.append(InsightRecommendation(
                icon: "hand.thumbsdown.fill",
                title: "Reduce frustration points",
                detail: "\(pct)% of interactions resulted in dissatisfaction or frustration. Review friction details for patterns — providing clearer instructions or more context upfront often helps.",
                severity: pct >= 20 ? .high : .medium
            ))
        }

        // 4. Low-performing goal categories
        var outcomeByGoal: [String: (fully: Int, total: Int)] = [:]
        for insight in insights {
            for category in insight.goalCategories.keys {
                var entry = outcomeByGoal[category] ?? (fully: 0, total: 0)
                entry.total += 1
                if insight.outcome == "fully_achieved" { entry.fully += 1 }
                outcomeByGoal[category] = entry
            }
        }
        let weakGoals = outcomeByGoal
            .filter { $0.value.total >= 3 && Double($0.value.fully) / Double($0.value.total) < 0.4 }
            .sorted { Double($0.value.fully) / Double($0.value.total) < Double($1.value.fully) / Double($1.value.total) }
        if let weakest = weakGoals.first {
            let pct = Int((Double(weakest.value.fully) / Double(weakest.value.total) * 100).rounded())
            recs.append(InsightRecommendation(
                icon: "target",
                title: "\(formatLabel(weakest.key)) tasks need better setup",
                detail: "Only \(pct)% of \(formatLabel(weakest.key).lowercased()) sessions fully achieved their goals (\(weakest.value.fully)/\(weakest.value.total)). Try providing more context, examples, or breaking the task into smaller steps.",
                severity: .medium
            ))
        }

        // 5. Iterative refinement sessions have low satisfaction
        let iterativeSessions = insights.filter { $0.sessionType == "iterative_refinement" }
        if iterativeSessions.count >= 3 {
            var positive = 0
            var totalSat = 0
            for s in iterativeSessions {
                for (level, count) in s.userSatisfactionCounts {
                    totalSat += count
                    if ["satisfied", "likely_satisfied", "happy"].contains(level) {
                        positive += count
                    }
                }
            }
            if totalSat > 0 {
                let posRate = Double(positive) / Double(totalSat)
                if posRate < 0.75 {
                    let pct = Int((posRate * 100).rounded())
                    recs.append(InsightRecommendation(
                        icon: "arrow.2.squarepath",
                        title: "Iterative refinement causing friction",
                        detail: "Only \(pct)% positive satisfaction in iterative refinement sessions. Try being more specific about what to change on each iteration, or provide before/after examples.",
                        severity: posRate < 0.5 ? .high : .medium
                    ))
                }
            }
        }

        // 6. Exploration sessions with frequent friction (by design, but worth noting)
        let explorations = insights.filter { $0.sessionType == "exploration" }
        if explorations.count >= 3 {
            let withFriction = explorations.filter { !$0.frictionCounts.isEmpty }.count
            if Double(withFriction) / Double(explorations.count) > 0.5 {
                recs.append(InsightRecommendation(
                    icon: "magnifyingglass",
                    title: "Exploration sessions hit frequent friction",
                    detail: "\(withFriction) of \(explorations.count) exploration sessions encountered friction. Consider starting with a clear question or scope before exploring.",
                    severity: .low
                ))
            }
        }

        // 7. Positive reinforcement when doing well
        let fullyAchieved = outcomeDistribution["fully_achieved", default: 0]
        if total > 0, Double(fullyAchieved) / Double(total) >= 0.7 {
            recs.append(InsightRecommendation(
                icon: "hand.thumbsup.fill",
                title: "Strong achievement rate",
                detail: "\(Int((Double(fullyAchieved) / Double(total) * 100).rounded()))% of sessions fully achieved their goals. Your prompting approach is working well — keep providing clear context and structured requests.",
                severity: .low
            ))
        }

        return recs
    }

    private static func frictionTip(_ type: String) -> (title: String, advice: String) {
        switch type {
        case "buggy_code":
            return ("Reduce buggy code output",
                    "Try asking Claude to write tests first, or request step-by-step implementation with verification between steps.")
        case "wrong_approach":
            return ("Avoid wrong approaches early",
                    "Provide more context about your architecture and constraints upfront so Claude picks the right strategy.")
        case "misunderstood_request":
            return ("Clarify requests upfront",
                    "Be specific about expected input/output, and include examples of what you want. A brief spec prevents misunderstandings.")
        case "tool_limitation":
            return ("Work around tool limitations",
                    "When hitting tool limits, try breaking the task into smaller pieces or providing file paths explicitly.")
        case "api_error", "api_errors":
            return ("API errors slowing you down",
                    "Consider retrying after a short wait, or breaking large operations into smaller batches to avoid timeouts.")
        case "user_rejected_action":
            return ("Review before executing",
                    "Ask Claude to explain its plan before executing, especially for destructive or hard-to-reverse operations.")
        case "excessive_changes":
            return ("Keep changes focused",
                    "Ask for minimal, targeted changes instead of broad refactors. Use explicit scope like 'only modify this function.'")
        case "rate_limit_hit":
            return ("Manage rate limits",
                    "Space out heavy sessions or use lighter models for simple tasks to stay within quota.")
        default:
            return ("Address recurring friction",
                    "Review session details to identify specific patterns causing this friction type.")
        }
    }

    private static func formatLabel(_ snakeCase: String) -> String {
        snakeCase.replacingOccurrences(of: "_", with: " ").capitalized
    }

    private static func outcomeScore(_ outcome: String) -> Double {
        switch outcome {
        case "fully_achieved": return 100
        case "mostly_achieved": return 75
        case "partially_achieved": return 50
        case "not_achieved": return 0
        default: return 50
        }
    }
}
