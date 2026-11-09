import SwiftUI

@main
struct WatchHookApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var tab: AppTab = .compose

    enum AppTab: Hashable { case compose, destinations, history, help }

    init() {
        PhoneSync.shared.activate()
        ConfigStore.shared.onChange = { PhoneSync.shared.push($0) }  // 失敗の理由は ConfigStore.syncError に入る
    }

    var body: some Scene {
        WindowGroup {
            TabView(selection: $tab) {
                Tab("送る", systemImage: "paperplane.fill", value: .compose) {
                    ComposeView { tab = .destinations }
                }
                Tab("送り先", systemImage: "scope", value: .destinations) {
                    DestinationListView()
                }
                Tab("履歴", systemImage: "clock", value: .history) {
                    HistoryView()
                }
                Tab("使い方", systemImage: "book", value: .help) {
                    HelpView()
                }
            }
            // アイコンに合わせて夜空の配色で固定する
            .preferredColorScheme(.dark)
            .tint(Cosmos.lavender)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                ConfigStore.shared.reloadIfNeeded()
                Task { await MessageDispatcher.shared.flush() }
            }
        }
    }
}
