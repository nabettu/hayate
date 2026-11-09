import SwiftUI
import WatchHookCore

/// iPhone から送った分 (Siri・テスト以外) の履歴。時計から送った分は時計の履歴にある。
struct HistoryView: View {
    @State private var entries: [MessageLogEntry] = []

    var body: some View {
        NavigationStack {
            List {
                if entries.isEmpty {
                    ContentUnavailableView("履歴はまだありません", systemImage: "clock",
                                           description: Text("この iPhone から送った内容が表示されます。Apple Watch から送った分は時計の履歴を見てください。"))
                }
                ForEach(entries) { e in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(e.message.text).lineLimit(3)
                        HStack {
                            Text(e.destinationName)
                            Text(e.status.label).foregroundStyle(color(e.status))
                            Spacer()
                            Text(e.message.createdAt, style: .relative)
                        }
                        .font(.caption).foregroundStyle(.secondary)
                        if let detail = e.status.detail, !isSent(e.status) {
                            Text(detail).font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    .swipeActions {
                        Button("削除", role: .destructive) {
                            Task { await MessageDispatcher.shared.remove(e.id); await reload() }
                        }
                        if !isSent(e.status) {
                            Button("再送") {
                                Task { await MessageDispatcher.shared.retry(e.id); await reload() }
                            }.tint(.blue)
                        }
                    }
                }
            }
            .navigationTitle("履歴")
            .refreshable {
                await MessageDispatcher.shared.flush()
                await reload()
            }
            .task { await reload() }
            .onReceive(NotificationCenter.default.publisher(for: MessageDispatcher.didChange)) { _ in
                Task { await reload() }
            }
        }
    }

    private func reload() async {
        entries = await MessageDispatcher.shared.entries
    }

    private func isSent(_ s: MessageStatus) -> Bool {
        if case .sent = s { true } else { false }
    }

    private func color(_ s: MessageStatus) -> Color {
        switch s {
        case .sent: .green
        case .pending: .orange
        case .failed: .red
        }
    }
}

struct HowToView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("Apple Watch から送る") {
                    Label("「Hey Siri、WatchHook で送って」と話しかけ、続けて送りたい内容を話す", systemImage: "mic")
                    Label("または WatchHook を開き、親指と人差し指をダブルタップ (Series 9 / Ultra 2 以降) して話す", systemImage: "hand.tap")
                    Label("時計から直接送り先へ送ります。iPhone のアプリが閉じていても届きます", systemImage: "paperplane")
                }
                Section("送れなかったとき") {
                    Label("通信できないときは時計 / iPhone に溜めておき、次に開いたときに送り直します", systemImage: "arrow.clockwise")
                }
                Section("受け取る側") {
                    Label("ヘッダ X-WatchHook-Message-Id は再送しても同じ値です。重複の除去に使えます", systemImage: "number")
                }
            }
            .navigationTitle("使い方")
        }
    }
}
