import SwiftUI

@main
struct ClauditApp: App {
    @State private var statsManager = StatsManager()
    @State private var showOnboarding = !SettingsManager.shared.hasSeenOnboarding

    var body: some Scene {
        // Menubar
        MenuBarExtra {
            MenuBarContentView()
                .environment(statsManager)
        } label: {
            MenuBarIconView()
                .environment(statsManager)
                .task {
                    // Show onboarding on first launch
                    if !SettingsManager.shared.hasSeenOnboarding {
                        showOnboarding = true
                    }
                    statsManager.startWatching()
                }
        }
        .menuBarExtraStyle(.window)

        // Onboarding Window
        Window("Welcome to Claudit", id: "onboarding") {
            WelcomeView {
                showOnboarding = false
            }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultPosition(.center)

        // Dashboard Window
        Window("Claudit Dashboard", id: "dashboard") {
            DashboardView()
                .environment(statsManager)
        }
        .defaultSize(width: 900, height: 700)
        .windowResizability(.contentMinSize)

        // Settings
        Settings {
            SettingsView()
                .environment(statsManager)
        }
    }
}
