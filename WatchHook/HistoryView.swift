import SwiftUI
import WatchHookCore

/// iPhone から送った分 (Siri・テスト以外) の履歴。時計から送った分は時計の履歴にある。
struct HistoryView: View {
    @State private var entries: [MessageLogEntry] = []
    @State private var sending: Set<UUID> = []

    var body: some View {
        NavigationStack {
            List {
                if entries.isEmpty {
                    ContentUnavailableView("履歴はまだありません", systemImage: "clock",
                                           description: Text("この iPhone から送った内容が表示されます。Apple Watch から送った分は時計の履歴を見てください。"))
                        .listRowBackground(Color.clear)
                }
                ForEach(entries) { e in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(e.message.text).lineLimit(3)
                        HStack {
                            Text(e.destinationName)
                            Text(e.label(sending: sending)).foregroundStyle(color(e.status))
                            Spacer()
                            Text(e.message.createdAt, style: .relative)
                        }
                        .font(.caption).foregroundStyle(.secondary)
                        if let detail = e.status.detail, !isSent(e.status) {
                            Text(detail).font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    .listRowBackground(Cosmos.card)
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
            .cosmicListBackground()
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
        sending = await MessageDispatcher.shared.sendingIDs
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
