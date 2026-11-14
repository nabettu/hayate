import SwiftUI

@main
struct WatchHookWatchApp: App {
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // 前面に来る前につながって失敗しても赤字を出さないよう、つなぐ前から準備中にする
        WatchSync.shared.beginStartup()
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
                WatchSync.shared.beginStartup()
                WatchSync.shared.requestConfig()
                WatchSync.shared.resendWaitingMemos()
                Task { await MemoDispatcher.shared.flush() }
            }
        }
    }
}
