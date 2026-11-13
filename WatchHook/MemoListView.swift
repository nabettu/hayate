import SwiftUI
import WatchHookCore

/// iPhone と Apple Watch で入力したメモ (メモの正は iPhone)。開くと連携ごとの状態・後から送る・共有・削除。
struct MemoListView: View {
    @State private var memos: [Memo] = []
    @State private var path: [UUID] = []
    @Binding var openMemoID: UUID?

    var body: some View {
        NavigationStack(path: $path) {
            List {
                if memos.isEmpty {
                    ContentUnavailableView("メモはまだありません", systemImage: "note.text",
                                           description: Text("この iPhone と Apple Watch で入力したメモが表示されます。"))
                        .listRowBackground(Color.clear)
                }
                ForEach(memos) { memo in
                    NavigationLink(value: memo.id) {
                        MemoRow(memo: memo)
                    }
                    .listRowBackground(Cosmos.card)
                }
            }
            .navigationTitle("メモ")
            // 1 件ずつ別のカードにする (1 枚に詰めると行どうしがくっついて見える)
            .listRowSpacing(10)
            .cosmicListBackground()
            .navigationDestination(for: UUID.self) { MemoDetailView(memoID: $0) }
            .refreshable {
                await MemoDispatcher.shared.flush()
                await reload()
            }
            .task { await reload() }
            .onReceive(NotificationCenter.default.publisher(for: MemoDispatcher.didChange)) { _ in
                Task { await reload() }
            }
            // リマインダーの URL (hayate://memo/<id>) から開いたとき
            .onChange(of: openMemoID, initial: true) {
                guard let id = openMemoID else { return }
                path = [id]
                openMemoID = nil
            }
        }
    }

    private func reload() async {
        memos = await MemoDispatcher.shared.memos
    }
}

private struct MemoRow: View {
    let memo: Memo

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(memo.text).lineLimit(3)
            HStack(spacing: 6) {
                Image(systemName: memo.origin == .watch ? "applewatch" : "iphone")
                    .accessibilityLabel(memo.origin == .watch ? "Apple Watch" : "iPhone")
                Label(memo.summary.label, systemImage: memo.summary.symbol)
                    .foregroundStyle(memo.summary.color)
                Spacer()
                Text(memo.createdAt, style: .relative)
            }
            .font(.caption).foregroundStyle(.secondary)
        }
    }
}

extension Memo.Summary {
    var color: Color {
        switch self {
        case .memoOnly: .secondary
        case .waiting: .orange
        case .someFailed: .red
        case .allDone: .green
        }
    }
}

struct MemoDetailView: View {
    let memoID: UUID
    @State private var memo: Memo?
    @State private var sending: Set<UUID> = []
    @State private var store = ConfigStore.shared
    @State private var confirmDelete = false
    @State private var deleteFailed = false
    @State private var saveFailed = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Group {
            if let memo {
                Section {
                    Text(memo.text).textSelection(.enabled)
                    HStack {
                        Label(memo.origin == .watch ? "Apple Watch" : "iPhone",
                              systemImage: memo.origin == .watch ? "applewatch" : "iphone")
                        Spacer()
                        Text(memo.createdAt.formatted(date: .abbreviated, time: .shortened))
                    }
                    .font(.caption).foregroundStyle(.secondary)
                }
                Section("送り先・連携") {
                    if memo.deliveries.isEmpty {
                        Text("メモとして保存しただけです").foregroundStyle(.secondary)
                    }
                    ForEach(memo.deliveries) { d in
                        DeliveryRow(memoID: memo.id, delivery: d, isSending: sending.contains(d.id)) {
                            saveFailed = true
                        }
                    }
                }
                Section {
                    sendLaterMenu(memo)
                    Button {
                        UIPasteboard.general.string = memo.text
                    } label: {
                        Label("コピー", systemImage: "doc.on.doc")
                    }
                    ShareLink(item: memo.text) {
                        Label("共有", systemImage: "square.and.arrow.up")
                    }
                    Button(role: .destructive) {
                        confirmDelete = true
                    } label: {
                        Label("削除", systemImage: "trash")
                    }
                }
            } else {
                Text("このメモは削除されました").foregroundStyle(.secondary)
            }
            }
            .listRowBackground(Cosmos.card)
        }
        .navigationTitle("メモ")
        .navigationBarTitleDisplayMode(.inline)
        .cosmicListBackground()
        .confirmationDialog("このメモを削除しますか？", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("削除", role: .destructive) {
                Task {
                    if await MemoDispatcher.shared.remove(memoID: memoID) {
                        dismiss()
                    } else {
                        deleteFailed = true
                    }
                }
            }
        } message: {
            Text("まだ送っていない分は送るのをやめます。送り終えたもの・作ったリマインダーは消えません。Apple Watch からも消えます。")
        }
        .alert("削除できませんでした", isPresented: $deleteFailed) {
            Button("OK", role: .cancel) {}
        }
        .alert("保存できなかったため、送りませんでした", isPresented: $saveFailed) {
            Button("OK", role: .cancel) {}
        }
        .task { await reload() }
        .onReceive(NotificationCenter.default.publisher(for: MemoDispatcher.didChange)) { _ in
            Task { await reload() }
        }
    }

    @ViewBuilder private func sendLaterMenu(_ memo: Memo) -> some View {
        Menu {
            ForEach(store.config.destinations) { d in
                Button(d.displayName) {
                    Task {
                        if await !MemoDispatcher.shared.sendLater(memoID: memo.id, destination: d) { saveFailed = true }
                    }
                }
            }
        } label: {
            Label("送り先へ送る", systemImage: "paperplane")
        }
        .disabled(store.config.destinations.isEmpty)
    }

    private func reload() async {
        memo = await MemoDispatcher.shared.memo(id: memoID)
        sending = await MemoDispatcher.shared.sendingIDs
    }
}

private struct DeliveryRow: View {
    let memoID: UUID
    let delivery: Delivery
    let isSending: Bool
    /// 送り直しを保存できなかったとき
    var onRetryFailed: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: symbol).foregroundStyle(Cosmos.star).accessibilityHidden(true)
                Text(delivery.target.displayName).lineLimit(2)
                Spacer()
                Text(delivery.status.label(isSending: isSending))
                    .font(.caption).foregroundStyle(color)
            }
            if let reason = delivery.status.reason {
                Text(reason).font(.caption2).foregroundStyle(.secondary)
            }
            if delivery.owner == .watch {
                Text("Apple Watch から送ります").font(.caption2).foregroundStyle(.secondary)
            } else if canRetry {
                Button("送り直す") {
                    Task {
                        if await !MemoDispatcher.shared.retry(memoID: memoID, deliveryID: delivery.id) { onRetryFailed() }
                    }
                }
                .font(.caption)
                .buttonStyle(.borderless)
            }
        }
    }

    private var canRetry: Bool {
        guard !isSending else { return false }
        switch delivery.status {
        case .pending, .failed: return true
        case .done, .cancelled: return false
        }
    }

    private var symbol: String {
        switch delivery.target {
        case .webhook: "paperplane"
        case .reminder: "checklist"
        case .markdown: "doc.text"
        }
    }

    private var color: Color {
        switch delivery.status {
        case .done: .green
        case .pending: .orange
        case .failed: .red
        case .cancelled: .secondary
        }
    }
}
