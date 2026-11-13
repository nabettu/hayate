import SwiftUI

@main
struct WatchHookApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var tab: AppTab = .compose
    /// リマインダーの URL (hayate://memo/<id>) から開くメモ
    @State private var openMemoID: UUID?

    enum AppTab: Hashable { case compose, memos, integrations, help }

    init() {
        PhoneSync.shared.activate()
        ConfigStore.shared.onChange = { PhoneSync.shared.push($0) }  // 失敗の理由は ConfigStore.syncError に入る
    }

    var body: some Scene {
        WindowGroup {
            TabView(selection: $tab) {
                Tab("入力", systemImage: "square.and.pencil", value: .compose) {
                    ComposeView { tab = .integrations }
                }
                Tab("メモ", systemImage: "note.text", value: .memos) {
                    MemoListView(openMemoID: $openMemoID)
                }
                Tab("連携", systemImage: "point.3.connected.trianglepath.dotted", value: .integrations) {
                    DestinationListView()
                }
                Tab("使い方", systemImage: "book", value: .help) {
                    HelpView()
                }
            }
            // アイコンに合わせて夜空の配色で固定する
            .preferredColorScheme(.dark)
            .tint(Cosmos.lavender)
            .onOpenURL { url in
                guard url.scheme == "hayate", url.host() == "memo",
                      let id = UUID(uuidString: url.lastPathComponent) else { return }
                tab = .memos
                openMemoID = id
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                ConfigStore.shared.reloadIfNeeded()
                Task { await MemoDispatcher.shared.flush() }
            }
        }
    }
}
