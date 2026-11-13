import SwiftUI

@main
struct WatchHookWatchApp: App {
    @Environment(\.scenePhase) private var scenePhase

    init() {
        WatchSync.shared.activate()
    }

    var body: some Scene {
        WindowGroup {
            #if DEBUG
            let gallery = UserDefaults.standard.integer(forKey: "widgetGallery")
            if gallery > 0 {
                WidgetGalleryView(page: gallery)
            } else {
                WatchHomeView()
            }
            #else
            WatchHomeView()
            #endif
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                ConfigStore.shared.reloadIfNeeded()
                WatchSync.shared.requestConfig()
                WatchSync.shared.resendWaitingMemos()
                Task { await MemoDispatcher.shared.flush() }
            }
        }
    }
}
