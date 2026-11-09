import SwiftUI

@main
struct WatchHookWatchApp: App {
    @Environment(\.scenePhase) private var scenePhase

    init() {
        WatchSync.shared.activate()
    }

    var body: some Scene {
        WindowGroup {
            WatchHomeView()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                WatchSync.shared.requestConfig()
                Task { await MessageDispatcher.shared.flush() }
            }
        }
    }
}
