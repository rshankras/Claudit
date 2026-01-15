import Foundation
import UserNotifications

/// Manages macOS notifications for quota alerts
@MainActor
final class NotificationManager {
    static let shared = NotificationManager()

    private var lastAlertedThreshold: [String: Int] = [:]  // quota type -> last alerted threshold

    private init() {
        requestPermission()
    }

    /// Request notification permissions
    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    /// Check quotas and send alerts if thresholds are crossed
    func checkAndSendAlerts(for response: UsageResponse) {
        let settings = SettingsManager.shared
        guard settings.alertsEnabled else { return }

        let thresholds = settings.alertThresholds

        // Check weekly (all models) quota
        if let weekly = response.sevenDay {
            checkQuota(
                type: "Weekly (All Models)",
                percent: weekly.utilizationPercent,
                thresholds: thresholds
            )
        }

        // Check session quota
        if let session = response.fiveHour {
            checkQuota(
                type: "Session",
                percent: session.utilizationPercent,
                thresholds: thresholds
            )
        }

        // Check Sonnet quota
        if let sonnet = response.sevenDaySonnet {
            checkQuota(
                type: "Weekly Sonnet",
                percent: sonnet.utilizationPercent,
                thresholds: thresholds
            )
        }

        // Check Opus quota
        if let opus = response.sevenDayOpus {
            checkQuota(
                type: "Weekly Opus",
                percent: opus.utilizationPercent,
                thresholds: thresholds
            )
        }
    }

    /// Check a single quota type and send alert if threshold crossed
    private func checkQuota(type: String, percent: Int, thresholds: [Int]) {
        // Find the highest threshold that's been crossed
        let crossedThreshold = thresholds.filter { percent >= $0 }.max()

        guard let crossed = crossedThreshold else {
            // Below all thresholds, reset
            lastAlertedThreshold.removeValue(forKey: type)
            return
        }

        // Only alert if this is a new/higher threshold than last time
        let lastAlerted = lastAlertedThreshold[type] ?? 0
        if crossed > lastAlerted {
            sendAlert(type: type, percent: percent, threshold: crossed)
            lastAlertedThreshold[type] = crossed
        }
    }

    /// Send a notification alert
    private func sendAlert(type: String, percent: Int, threshold: Int) {
        let content = UNMutableNotificationContent()

        // Set title based on severity
        if threshold >= 95 {
            content.title = "Claude Quota Critical"
        } else if threshold >= 90 {
            content.title = "Claude Quota Warning"
        } else {
            content.title = "Claude Quota Alert"
        }

        content.body = "\(type) quota at \(percent)%"
        content.sound = .default
        content.categoryIdentifier = "QUOTA_ALERT"

        let request = UNNotificationRequest(
            identifier: "quota-\(type)-\(threshold)",
            content: content,
            trigger: nil  // Immediate delivery
        )

        UNUserNotificationCenter.current().add(request) { _ in }
    }

    /// Reset alert state (e.g., when quotas reset)
    func resetAlertState() {
        lastAlertedThreshold.removeAll()
    }
}
