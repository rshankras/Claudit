import Foundation
import Security

/// Service to fetch real-time usage data from Anthropic API
enum UsageAPI {
    private static let usageURL = URL(string: "https://api.anthropic.com/api/oauth/usage")!
    private static let keychainService = "Claude Code-credentials"

    /// Fetch current usage from Anthropic API
    static func fetchUsage() async throws -> UsageResponse {
        // Check credentials exist
        guard let credentials = getCredentials() else {
            throw UsageAPIError.noCredentials
        }

        // Check token expiration
        if credentials.claudeAiOauth?.isExpired == true {
            throw UsageAPIError.tokenExpired
        }

        guard let token = credentials.claudeAiOauth?.accessToken else {
            throw UsageAPIError.noCredentials
        }

        var request = URLRequest(url: usageURL)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Claudit/1.0 (macOS Usage Tracker)", forHTTPHeaderField: "User-Agent")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw UsageAPIError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw UsageAPIError.httpError(httpResponse.statusCode)
        }

        return try JSONDecoder().decode(UsageResponse.self, from: data)
    }

    /// Get full credentials from macOS Keychain
    static func getCredentials() -> ClaudeCredentials? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let jsonString = String(data: data, encoding: .utf8),
              let credentials = try? JSONDecoder().decode(ClaudeCredentials.self, from: Data(jsonString.utf8)) else {
            return nil
        }

        return credentials
    }

    /// Get OAuth access token from macOS Keychain
    static func getAccessToken() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let jsonString = String(data: data, encoding: .utf8) else {
            return nil
        }

        guard let credentials = try? JSONDecoder().decode(ClaudeCredentials.self, from: Data(jsonString.utf8)) else {
            return nil
        }

        return credentials.claudeAiOauth?.accessToken
    }

    /// Get subscription type from Keychain credentials
    static func getSubscriptionType() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let jsonString = String(data: data, encoding: .utf8),
              let credentials = try? JSONDecoder().decode(ClaudeCredentials.self, from: Data(jsonString.utf8)) else {
            return nil
        }

        return credentials.claudeAiOauth?.subscriptionType
    }
}

enum UsageAPIError: Error, LocalizedError {
    case noCredentials
    case tokenExpired
    case invalidResponse
    case httpError(Int)

    var errorDescription: String? {
        switch self {
        case .noCredentials:
            return "No Claude Code credentials found. Please sign in to Claude Code first."
        case .tokenExpired:
            return "Your Claude Code session has expired. Please restart Claude Code to refresh your credentials."
        case .invalidResponse:
            return "Invalid response from API"
        case .httpError(401):
            return "Authentication failed. Please restart Claude Code and sign in again."
        case .httpError(429):
            return "Rate limited by Anthropic. Please try again in a few minutes."
        case .httpError(let code):
            return "Unable to fetch quota (HTTP \(code)). Check your internet connection."
        }
    }
}
