import Foundation

/// Formatting utilities for displaying numbers in human-readable format
extension Int {
    /// Format token count with K/M/B suffixes
    /// Examples: 1500 → "1.5K", 1_000_000 → "1.0M", 1_234_567_890 → "1.2B"
    func formatTokenCount() -> String {
        if self >= 1_000_000_000 {
            return String(format: "%.1fB", Double(self) / 1_000_000_000.0)
        } else if self >= 1_000_000 {
            return String(format: "%.1fM", Double(self) / 1_000_000.0)
        } else if self >= 1000 {
            return String(format: "%.1fK", Double(self) / 1000.0)
        } else {
            return "\(self)"
        }
    }
}

/// Bundle version helpers
extension Bundle {
    var appVersion: String {
        let version = infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

/// Time interval formatting for duration display
extension TimeInterval {
    /// Format duration in human-readable form
    /// Examples: 45 min → "45m", 3 hours → "3h", 2 days 5 hours → "2d 5h"
    var formattedDuration: String {
        let hours = self / 3600.0

        if hours < 1 {
            let minutes = Int(hours * 60)
            return "\(max(1, minutes))m"
        } else if hours < 24 {
            return "\(Int(hours))h"
        } else {
            let days = Int(hours / 24)
            let remainingHours = Int(hours.truncatingRemainder(dividingBy: 24))
            if remainingHours == 0 {
                return "\(days)d"
            }
            return "\(days)d \(remainingHours)h"
        }
    }
}
