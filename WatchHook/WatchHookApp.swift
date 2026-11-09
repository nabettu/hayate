import SwiftUI

@main
struct WatchHookApp: App {
    @Environment(\.scenePhase) private var scenePhase

    init() {
        PhoneSync.shared.activate()
        ConfigStore.shared.onChange = { PhoneSync.shared.push($0) }  // 失敗の理由は ConfigStore.syncError に入る
        // 購入の状態が変わったら時計へ知らせる (設定の版と一緒に applicationContext に載せる)
        EntitlementStore.shared.onChange = { ConfigStore.shared.resync() }
        EntitlementStore.shared.start()
    }

    var body: some Scene {
        WindowGroup {
            TabView {
                Tab("送り先", systemImage: "paperplane") {
                    DestinationListView()
                }
                Tab("履歴", systemImage: "clock") {
                    HistoryView()
                }
                Tab("使い方", systemImage: "book") {
                    HelpView()
                }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                ConfigStore.shared.reloadIfNeeded()
                Task { await EntitlementStore.shared.refresh() }
                Task { await MessageDispatcher.shared.flush() }
            }
        }
    }
}
