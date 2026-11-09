import SwiftUI
import WatchHookCore

/// この iPhone から送った分と、Apple Watch から送った分 (時計から届いた写し) をまとめた履歴。
/// 再送・削除ができるのは、この iPhone の分だけ (時計の分は時計の履歴で操作する)。
struct HistoryView: View {
    @State private var entries: [MessageLogEntry] = []
    @State private var sending: Set<UUID> = []
    @State private var watchHistory = WatchHistoryStore.shared

    private var rows: [CombinedHistory.Row] {
        CombinedHistory.rows(local: entries, watch: watchHistory.entries)
    }

    var body: some View {
        NavigationStack {
            List {
                if rows.isEmpty {
                    ContentUnavailableView("履歴はまだありません", systemImage: "clock",
                                           description: Text("この iPhone と Apple Watch から送った内容が表示されます。"))
                }
                ForEach(rows) { row in
                    let e = row.entry
                    let fromWatch = row.origin == .watch
                    VStack(alignment: .leading, spacing: 4) {
                        Text(e.message.text).lineLimit(3)
                        HStack {
                            Label(fromWatch ? "Apple Watch" : "iPhone", systemImage: fromWatch ? "applewatch" : "iphone")
                                .labelStyle(.iconOnly)
                            Text(e.destinationName)
                            Text(fromWatch ? e.status.label : e.label(sending: sending)).foregroundStyle(color(e.status))
                            Spacer()
                            Text(e.message.createdAt, style: .relative)
                        }
                        .font(.caption).foregroundStyle(.secondary)
                        if let detail = e.status.detail, !isSent(e.status) {
                            Text(detail).font(.caption2).foregroundStyle(.secondary)
                        }
                        if fromWatch, !isSent(e.status) {
                            Text("再送・削除は Apple Watch の履歴から").font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    .swipeActions {
                        if !fromWatch {
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
                if let updatedAt = watchHistory.updatedAt {
                    Text("Apple Watch の履歴: \(updatedAt.formatted(date: .abbreviated, time: .shortened)) 時点")
                        .font(.caption2).foregroundStyle(.secondary)
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
