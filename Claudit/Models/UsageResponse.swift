import Foundation

/// Response from the Claude usage API
struct UsageResponse: Codable, Sendable {
    let fiveHour: UsageLimit?
    let sevenDay: UsageLimit?
    let sevenDayOauthApps: UsageLimit?
    let sevenDayOpus: UsageLimit?
    let sevenDaySonnet: UsageLimit?
    let iguanaNecktie: UsageLimit?
    let extraUsage: ExtraUsage?

    enum CodingKeys: String, CodingKey {
        case fiveHour = "five_hour"
        case sevenDay = "seven_day"
        case sevenDayOauthApps = "seven_day_oauth_apps"
        case sevenDayOpus = "seven_day_opus"
        case sevenDaySonnet = "seven_day_sonnet"
        case iguanaNecktie = "iguana_necktie"
        case extraUsage = "extra_usage"
    }
}

struct UsageLimit: Codable, Sendable {
    let utilization: Double
    let resetsAt: String?  // API can return null for some quotas

    enum CodingKeys: String, CodingKey {
        case utilization
        case resetsAt = "resets_at"
    }

    var resetsAtDate: Date? {
        guard let resetsAt else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [
            .withInternetDateTime,
            .withFractionalSeconds,
            .withColonSeparatorInTimeZone
        ]
        return formatter.date(from: resetsAt)
    }

    var utilizationPercent: Int {
        Int(utilization)
    }
}

struct ExtraUsage: Codable, Sendable {
    let isEnabled: Bool
    let monthlyLimit: Double?
    let usedCredits: Double?
    let utilization: Double?

    enum CodingKeys: String, CodingKey {
        case isEnabled = "is_enabled"
        case monthlyLimit = "monthly_limit"
        case usedCredits = "used_credits"
        case utilization
    }
}

/// Credentials stored in Keychain
struct ClaudeCredentials: Codable, Sendable {
    let claudeAiOauth: OAuthCredentials?
}

struct OAuthCredentials: Codable, Sendable {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Int64
    let scopes: [String]
    let subscriptionType: String?
    let rateLimitTier: String?

    var isExpired: Bool {
        Date().timeIntervalSince1970 * 1000 > Double(expiresAt)
    }
}
