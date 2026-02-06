import Foundation

struct SessionInsight: Codable, Identifiable, Sendable {
    var id: String { sessionId }

    let underlyingGoal: String
    let goalCategories: [String: Int]
    let outcome: String
    let userSatisfactionCounts: [String: Int]
    let claudeHelpfulness: String
    let sessionType: String
    let frictionCounts: [String: Int]
    let frictionDetail: String
    let primarySuccess: String
    let briefSummary: String
    let sessionId: String

    enum CodingKeys: String, CodingKey {
        case underlyingGoal = "underlying_goal"
        case goalCategories = "goal_categories"
        case outcome
        case userSatisfactionCounts = "user_satisfaction_counts"
        case claudeHelpfulness = "claude_helpfulness"
        case sessionType = "session_type"
        case frictionCounts = "friction_counts"
        case frictionDetail = "friction_detail"
        case primarySuccess = "primary_success"
        case briefSummary = "brief_summary"
        case sessionId = "session_id"
    }
}

/// An actionable recommendation derived from session patterns
struct InsightRecommendation: Identifiable, Sendable {
    let id = UUID()
    let icon: String
    let title: String
    let detail: String
    let severity: Severity

    enum Severity: Sendable {
        case high, medium, low
    }
}

/// A friction log entry from a specific session
struct FrictionLogEntry: Identifiable, Sendable {
    var id: String { sessionId }
    let sessionId: String
    let outcome: String
    let frictionDetail: String
    let frictionTypes: [String]
    let briefSummary: String
}

/// Helpfulness level correlated with success rate
struct HelpfulnessCorrelation: Identifiable, Sendable {
    var id: String { level }
    let level: String
    let sessionCount: Int
    let fullyAchievedCount: Int
    var successRate: Int {
        guard sessionCount > 0 else { return 0 }
        return Int((Double(fullyAchievedCount) / Double(sessionCount) * 100).rounded())
    }
}

/// Session type correlated with positive satisfaction rate
struct SessionTypeSatisfaction: Identifiable, Sendable {
    var id: String { sessionType }
    let sessionType: String
    let positiveCount: Int
    let negativeCount: Int
    let totalCount: Int
    var positiveRate: Int {
        guard totalCount > 0 else { return 0 }
        return Int((Double(positiveCount) / Double(totalCount) * 100).rounded())
    }
}

struct InsightsSummary: Sendable {
    let totalSessions: Int
    let productivityScore: Int
    let frictionRate: Int                                   // % of sessions with any friction
    let helpfulnessRate: Int                                // % essential + very_helpful
    let outcomeDistribution: [String: Int]
    let frictionBreakdown: [String: Int]
    let sessionTypeBreakdown: [String: Int]
    let satisfactionBreakdown: [String: Int]
    let goalCategoryBreakdown: [String: Int]
    let topSuccessTypes: [String: Int]
    let helpfulnessBreakdown: [String: Int]
    let recommendations: [InsightRecommendation]
    let frictionLog: [FrictionLogEntry]                     // Sessions with friction details
    let helpfulnessCorrelations: [HelpfulnessCorrelation]   // Helpfulness → success rate
    let sessionTypeSatisfactions: [SessionTypeSatisfaction]  // Session type → satisfaction
    let lastGeneratedDate: Date?                              // Most recent facet file date

    static let empty = InsightsSummary(
        totalSessions: 0,
        productivityScore: 0,
        frictionRate: 0,
        helpfulnessRate: 0,
        outcomeDistribution: [:],
        frictionBreakdown: [:],
        sessionTypeBreakdown: [:],
        satisfactionBreakdown: [:],
        goalCategoryBreakdown: [:],
        topSuccessTypes: [:],
        helpfulnessBreakdown: [:],
        recommendations: [],
        frictionLog: [],
        helpfulnessCorrelations: [],
        sessionTypeSatisfactions: [],
        lastGeneratedDate: nil
    )
}
