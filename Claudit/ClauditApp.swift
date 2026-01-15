import SwiftUI

@main
struct ClauditApp: App {
    @State private var statsManager = StatsManager()

    init() {
        PerfLog.start("appInit")
    }

    var body: some Scene {
        // Menubar
        MenuBarExtra {
            MenuBarContentView()
                .environment(statsManager)
                .onAppear { PerfLog.end("menuOpen") }
        } label: {
            MenuBarIconView()
                .environment(statsManager)
                .task {
                    PerfLog.end("appInit")
                    PerfLog.start("startWatching")
                    statsManager.startWatching()
                    PerfLog.end("startWatching")
                }
                .onTapGesture { PerfLog.start("menuOpen") }
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
