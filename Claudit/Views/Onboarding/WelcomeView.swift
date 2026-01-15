import SwiftUI

struct WelcomeView: View {
    @Environment(\.settingsManager) private var settings
    @Environment(\.dismiss) private var dismiss
    var onComplete: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            // App Icon and Title
            VStack(spacing: 12) {
                Image(systemName: "chart.pie.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.blue)

                Text("Welcome to Claudit")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Track your Claude Code usage and costs")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 20)

            Divider()
                .padding(.horizontal, 40)

            // Features
            VStack(alignment: .leading, spacing: 16) {
                FeatureRow(
                    icon: "dollarsign.circle",
                    color: .green,
                    title: "Cost Tracking",
                    description: "Monitor daily, weekly, and monthly spending across all Claude models"
                )

                FeatureRow(
                    icon: "gauge.with.dots.needle.50percent",
                    color: .orange,
                    title: "Quota Monitoring",
                    description: "Real-time quota status with alerts before you hit limits"
                )

                FeatureRow(
                    icon: "folder",
                    color: .blue,
                    title: "Project Breakdown",
                    description: "See which projects consume the most tokens"
                )

                FeatureRow(
                    icon: "lock.shield",
                    color: .purple,
                    title: "Privacy First",
                    description: "All calculations happen locally. Your data stays on your Mac."
                )
            }
            .padding(.horizontal, 40)

            Divider()
                .padding(.horizontal, 40)

            // Requirements
            VStack(alignment: .leading, spacing: 8) {
                Text("Requirements")
                    .font(.headline)

                HStack(spacing: 8) {
                    Image(systemName: hasClaudeCodeCredentials ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(hasClaudeCodeCredentials ? Color.green : Color.red)
                    Text("Claude Code installed and signed in")
                        .foregroundStyle(hasClaudeCodeCredentials ? Color.primary : Color.red)
                }
                .font(.callout)

                if !hasClaudeCodeCredentials {
                    Text("Please install Claude Code and sign in, then relaunch Claudit.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 40)

            // Keychain note
            VStack(alignment: .leading, spacing: 4) {
                Label("Keychain Access", systemImage: "key.fill")
                    .font(.headline)
                Text("On first launch, macOS will ask to access \"Claude Code-credentials\" from your Keychain. Click **Always Allow** to grant permanent access.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 40)

            Spacer()

            // Get Started Button
            Button {
                settings.hasSeenOnboarding = true
                onComplete()
                dismiss()
            } label: {
                Text("Get Started")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 40)
            .padding(.bottom, 24)
            .disabled(!hasClaudeCodeCredentials)
        }
        .frame(width: 500, height: 680)
    }

    private var hasClaudeCodeCredentials: Bool {
        UsageAPI.getCredentials() != nil
    }
}

struct FeatureRow: View {
    let icon: String
    let color: Color
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
