import SwiftUI

@main
struct FusionStudioApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var ipcClient = IPCClient()
    @StateObject private var taskManager = TaskManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(ipcClient)
                .environmentObject(taskManager)
                .frame(minWidth: 1100, minHeight: 700)
                .onAppear {
                    NSApp.setActivationPolicy(.regular)
                    NSApp.activate(ignoringOtherApps: true)
                }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Fusion Studio") {
                    appState.showAboutPanel = true
                }
            }
            CommandGroup(replacing: .help) {
                Button("Fusion Studio Help") {
                    appState.showHelp = true
                }
            }
        }
    }
}