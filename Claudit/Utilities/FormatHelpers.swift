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
