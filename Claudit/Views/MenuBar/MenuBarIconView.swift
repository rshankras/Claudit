import SwiftUI

struct MenuBarIconView: View {
    @Environment(StatsManager.self) private var statsManager: StatsManager?
    private var settings = SettingsManager.shared

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: iconName)

            if let manager = statsManager {
                Text(displayText(manager))
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(textColor(manager))
            }
        }
    }

    private var iconName: String {
        if settings.showQuotaInMenubar {
            return "chart.pie"
        }
        return "dollarsign.circle"
    }

    private func displayText(_ manager: StatsManager) -> String {
        if settings.showQuotaInMenubar {
            // Use real API data if available
            let percent = manager.weeklyPercent
            return "\(percent)%"
        } else {
            return formatCost(manager.todayCost)
        }
    }

    private func textColor(_ manager: StatsManager) -> Color {
        guard settings.showQuotaInMenubar else { return .primary }
        switch manager.quotaColor(for: manager.weeklyPercent) {
        case .red: return .red
        case .yellow: return .orange
        case .green: return .primary
        }
    }

    private func formatCost(_ cost: Double) -> String {
        if cost >= 100 {
            return "$\(Int(cost))"
        } else if cost >= 10 {
            return String(format: "$%.1f", cost)
        } else {
            return String(format: "$%.2f", cost)
        }
    }
}
