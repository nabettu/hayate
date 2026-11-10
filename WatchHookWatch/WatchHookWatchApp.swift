import SwiftUI

@main
struct WatchHookWatchApp: App {
    @Environment(\.scenePhase) private var scenePhase

    init() {
        WatchSync.shared.activate()
        EntitlementStore.shared.start()
    }

    var body: some Scene {
        WindowGroup {
            WatchHomeView()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                ConfigStore.shared.reloadIfNeeded()
                WatchSync.shared.requestConfig()
                Task { await EntitlementStore.shared.refresh() }
                Task { await MessageDispatcher.shared.flush() }
            }
        }
    }
}
