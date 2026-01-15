import Foundation
import os.log
import ServiceManagement
import SwiftUI

@Observable
final class SettingsManager {
    /// Shared instance for backward compatibility during migration
    /// Prefer Environment injection for new code
    static let shared = SettingsManager()

    private static let logger = Logger(subsystem: "com.claudit", category: "settings")
    private let defaults = UserDefaults.standard
    private let pricingKey = "modelPricing"
    private let launchAtLoginKey = "launchAtLogin"
    private let weeklyLimitKey = "weeklyLimit"
    private let showQuotaInMenubarKey = "showQuotaInMenubar"
    private let alertsEnabledKey = "alertsEnabled"
    private let alertThresholdsKey = "alertThresholds"
    private let hasSeenOnboardingKey = "hasSeenOnboarding"

    var modelPricing: [ClaudeModel: ModelPricing] {
        didSet {
            savePricing()
            NotificationCenter.default.post(name: .pricingChanged, object: nil)
        }
    }

    var launchAtLogin: Bool {
        didSet {
            defaults.set(launchAtLogin, forKey: launchAtLoginKey)
            updateLaunchAtLogin(launchAtLogin)
        }
    }

    /// Weekly spending limit in USD (default $200 - estimated Claude Max limit)
    var weeklyLimit: Double {
        didSet {
            defaults.set(weeklyLimit, forKey: weeklyLimitKey)
            NotificationCenter.default.post(name: .quotaSettingsChanged, object: nil)
        }
    }

    /// Whether to show quota percentage in menubar instead of cost
    var showQuotaInMenubar: Bool {
        didSet {
            defaults.set(showQuotaInMenubar, forKey: showQuotaInMenubarKey)
            NotificationCenter.default.post(name: .quotaSettingsChanged, object: nil)
        }
    }

    /// Whether quota alerts are enabled
    var alertsEnabled: Bool {
        didSet {
            defaults.set(alertsEnabled, forKey: alertsEnabledKey)
        }
    }

    /// Thresholds (percentages) at which to send alerts
    var alertThresholds: [Int] {
        didSet {
            defaults.set(alertThresholds, forKey: alertThresholdsKey)
        }
    }

    /// Whether user has seen the onboarding screen
    var hasSeenOnboarding: Bool {
        didSet {
            defaults.set(hasSeenOnboarding, forKey: hasSeenOnboardingKey)
        }
    }

    private init() {
        self.launchAtLogin = defaults.bool(forKey: launchAtLoginKey)

        // Load quota settings with defaults
        let savedLimit = defaults.double(forKey: weeklyLimitKey)
        self.weeklyLimit = savedLimit > 0 ? savedLimit : 200.0  // Default $200

        // Default to showing quota in menubar
        if defaults.object(forKey: showQuotaInMenubarKey) != nil {
            self.showQuotaInMenubar = defaults.bool(forKey: showQuotaInMenubarKey)
        } else {
            self.showQuotaInMenubar = true
        }

        // Load alert settings with defaults
        if defaults.object(forKey: alertsEnabledKey) != nil {
            self.alertsEnabled = defaults.bool(forKey: alertsEnabledKey)
        } else {
            self.alertsEnabled = true  // Default enabled
        }

        if let savedThresholds = defaults.array(forKey: alertThresholdsKey) as? [Int], !savedThresholds.isEmpty {
            self.alertThresholds = savedThresholds
        } else {
            self.alertThresholds = [75, 90, 95]  // Default thresholds
        }

        self.hasSeenOnboarding = defaults.bool(forKey: hasSeenOnboardingKey)

        if let data = defaults.data(forKey: pricingKey),
           let decoded = try? JSONDecoder().decode([String: ModelPricing].self, from: data) {
            var pricing: [ClaudeModel: ModelPricing] = [:]
            for (key, value) in decoded {
                if let model = ClaudeModel(rawValue: key) {
                    pricing[model] = value
                }
            }
            // Ensure all models have pricing (use defaults for missing)
            for model in ClaudeModel.allCases {
                if pricing[model] == nil {
                    pricing[model] = ModelPricing.defaultPricing(for: model)
                }
            }
            self.modelPricing = pricing
        } else {
            self.modelPricing = Self.defaultPricing
        }
    }

    static var defaultPricing: [ClaudeModel: ModelPricing] {
        var pricing: [ClaudeModel: ModelPricing] = [:]
        for model in ClaudeModel.allCases {
            pricing[model] = ModelPricing.defaultPricing(for: model)
        }
        return pricing
    }

    func resetToDefaults() {
        modelPricing = Self.defaultPricing
    }

    func pricing(for model: ClaudeModel) -> ModelPricing {
        modelPricing[model] ?? ModelPricing.defaultPricing(for: model)
    }

    private func savePricing() {
        var dict: [String: ModelPricing] = [:]
        for (model, pricing) in modelPricing {
            dict[model.rawValue] = pricing
        }
        if let data = try? JSONEncoder().encode(dict) {
            defaults.set(data, forKey: pricingKey)
        }
    }

    private func updateLaunchAtLogin(_ enable: Bool) {
        do {
            if enable {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            Self.logger.error("Failed to update launch at login: \(error.localizedDescription)")
        }
    }
}

extension Notification.Name {
    static let pricingChanged = Notification.Name("pricingChanged")
    static let quotaSettingsChanged = Notification.Name("quotaSettingsChanged")
}

// MARK: - Environment Support

private struct SettingsManagerKey: EnvironmentKey {
    static let defaultValue = SettingsManager.shared
}

extension EnvironmentValues {
    var settingsManager: SettingsManager {
        get { self[SettingsManagerKey.self] }
        set { self[SettingsManagerKey.self] = newValue }
    }
}
