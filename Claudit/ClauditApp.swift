import SwiftUI

@main
struct ClauditApp: App {
    @State private var statsManager = StatsManager()

    var body: some Scene {
        // Menubar
        MenuBarExtra {
            MenuBarContentView()
                .environment(statsManager)
        } label: {
            MenuBarIconView()
                .environment(statsManager)
                .task {
                    statsManager.startWatching()
                }
        }
        .menuBarExtraStyle(.window)

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
