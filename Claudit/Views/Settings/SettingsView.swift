import SwiftUI

struct SettingsView: View {
    @Environment(StatsManager.self) private var statsManager: StatsManager?
    private var settings = SettingsManager.shared
    @State private var showResetConfirmation = false

    var body: some View {
        Form {
            Section("General") {
                Toggle("Launch at Login", isOn: Bindable(settings).launchAtLogin)
            }

            Section("Account") {
                HStack {
                    Text("Subscription")
                    Spacer()
                    Text(statsManager?.subscriptionType?.capitalized ?? "Unknown")
                        .foregroundStyle(.secondary)
                }

                Toggle("Show quota % in menubar", isOn: Bindable(settings).showQuotaInMenubar)

                Text("Quota data is fetched from Anthropic's API using your Claude Code credentials.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Alerts") {
                Toggle("Enable quota alerts", isOn: Bindable(settings).alertsEnabled)

                if settings.alertsEnabled {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Alert at these thresholds:")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 12) {
                            ThresholdToggle(threshold: 75, thresholds: Bindable(settings).alertThresholds)
                            ThresholdToggle(threshold: 90, thresholds: Bindable(settings).alertThresholds)
                            ThresholdToggle(threshold: 95, thresholds: Bindable(settings).alertThresholds)
                        }
                    }

                    Text("You'll receive a macOS notification when quota reaches these levels.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Pricing (per 1K tokens)") {
                ForEach(ClaudeModel.allCases) { model in
                    PricingEditor(
                        model: model,
                        pricing: binding(for: model)
                    )
                }
            }

            Section {
                HStack {
                    Button("Reset to Defaults") {
                        showResetConfirmation = true
                    }
                    .buttonStyle(.bordered)

                    Spacer()

                    Button("Recalculate Costs") {
                        statsManager?.loadStats()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 450, height: 620)
        .confirmationDialog(
            "Reset Pricing",
            isPresented: $showResetConfirmation
        ) {
            Button("Reset to Defaults", role: .destructive) {
                settings.resetToDefaults()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will reset all pricing to Anthropic's current rates.")
        }
    }

    private func binding(for model: ClaudeModel) -> Binding<ModelPricing> {
        Binding(
            get: { settings.modelPricing[model] ?? ModelPricing.defaultPricing(for: model) },
            set: { settings.modelPricing[model] = $0 }
        )
    }
}

struct PricingEditor: View {
    let model: ClaudeModel
    @Binding var pricing: ModelPricing
    @State private var isExpanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 12) {
                PricingField(label: "Input", value: $pricing.inputPer1K)
                PricingField(label: "Output", value: $pricing.outputPer1K)
                PricingField(label: "Cache Read", value: $pricing.cacheReadPer1K)
                PricingField(label: "Cache Write", value: $pricing.cacheWritePer1K)
            }
            .padding(.vertical, 8)
        } label: {
            HStack {
                Circle()
                    .fill(model.color)
                    .frame(width: 10, height: 10)
                Text(model.displayName)
            }
        }
    }
}

struct PricingField: View {
    let label: String
    @Binding var value: Double

    var body: some View {
        HStack {
            Text(label)
                .frame(width: 100, alignment: .leading)

            TextField("", value: $value, format: .number.precision(.fractionLength(2...5)))
                .textFieldStyle(.roundedBorder)
                .frame(width: 100)

            Text("$")
                .foregroundStyle(.secondary)
        }
    }
}

struct ThresholdToggle: View {
    let threshold: Int
    @Binding var thresholds: [Int]

    private var isEnabled: Bool {
        thresholds.contains(threshold)
    }

    var body: some View {
        Toggle("\(threshold)%", isOn: Binding(
            get: { isEnabled },
            set: { newValue in
                if newValue {
                    if !thresholds.contains(threshold) {
                        thresholds.append(threshold)
                        thresholds.sort()
                    }
                } else {
                    thresholds.removeAll { $0 == threshold }
                }
            }
        ))
        .toggleStyle(.checkbox)
    }
}

#Preview {
    SettingsView()
}
