import SwiftUI

@main
struct WatchHookApp: App {
    @Environment(\.scenePhase) private var scenePhase

    init() {
        PhoneSync.shared.activate()
        ConfigStore.shared.onChange = { PhoneSync.shared.push($0) }  // 失敗の理由は ConfigStore.syncError に入る
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
                Tab("使い方", systemImage: "applewatch") {
                    HowToView()
                }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await MessageDispatcher.shared.flush() } }
        }
    }
}
