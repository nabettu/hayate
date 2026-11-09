import SwiftUI
import WatchKit
import WatchHookCore

struct WatchHomeView: View {
    @State private var store = ConfigStore.shared
    /// 時計の中だけで選ぶ送り先 (iPhone の「既定」とは別に持つ)。
    @AppStorage("selectedDestinationID") private var selectedID: String = ""
    @State private var lastStatus: MessageStatus?
    @State private var isSending = false

    private var destination: Destination? {
        UUID(uuidString: selectedID).flatMap { store.config.destination(id: $0) } ?? store.config.defaultDestination
    }

    var body: some View {
        NavigationStack {
            if let destination {
                ScrollView {
                    VStack(spacing: 10) {
                        saveErrorView
                        // 標準の入力画面 (音声入力・スクリブル) を開く。ダブルタップでも押せる
                        TextFieldLink(prompt: Text("話してください")) {
                            Label("話す", systemImage: "mic.fill")
                                .font(.title3.bold())
                                .frame(maxWidth: .infinity, minHeight: 64)
                        } onSubmit: { text in
                            Task { await send(text, to: destination) }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                        .handGestureShortcut(.primaryAction)
                        .disabled(isSending)

                        statusView

                        if store.config.destinations.count > 1 {
                            Picker("送り先", selection: $selectedID) {
                                ForEach(store.config.destinations) { d in
                                    Text(d.name).tag(d.id.uuidString)
                                }
                            }
                        } else {
                            Text(destination.name).font(.footnote).foregroundStyle(.secondary)
                        }

                        NavigationLink("履歴") { WatchHistoryView() }
                            .font(.footnote)
                    }
                }
                .navigationTitle("WatchHook")
                .onAppear(perform: fixSelection)
                .onChange(of: store.config) { fixSelection() }
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        saveErrorView
                        Image(systemName: "iphone").font(.title2)
                        Text("iPhone の WatchHook で送り先を登録してください")
                            .multilineTextAlignment(.center)
                            .font(.footnote)
                        Button("再読み込み") { WatchSync.shared.requestConfig() }
                        // 送り先が無くても、これまでの履歴は見られるようにする
                        NavigationLink("履歴") { WatchHistoryView() }
                            .font(.footnote)
                    }
                }
                .navigationTitle("WatchHook")
            }
        }
    }

    /// iPhone から届いた設定を時計に保存できなかったとき。
    @ViewBuilder private var saveErrorView: some View {
        if let error = store.saveError ?? store.syncError {
            VStack(spacing: 4) {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption2).foregroundStyle(.red)
                Button("もう一度受け取る") { WatchSync.shared.requestConfig() }.font(.caption2)
            }
        }
    }

    @ViewBuilder private var statusView: some View {
        if isSending {
            ProgressView()
        } else if let lastStatus {
            switch lastStatus {
            case .sent:
                Label("送りました", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
            case .pending:
                Label("あとで送り直します", systemImage: "arrow.clockwise").foregroundStyle(.orange)
            case .failed(let reason):
                VStack {
                    Label("送れませんでした", systemImage: "xmark.circle.fill").foregroundStyle(.red)
                    Text(reason).font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
    }

    /// 選んでいた送り先が iPhone で消されたら、既定の送り先に合わせる (表示と実際の送り先をずらさない)。
    private func fixSelection() {
        let exists = UUID(uuidString: selectedID).flatMap { store.config.destination(id: $0) } != nil
        if !exists { selectedID = store.config.defaultDestination?.id.uuidString ?? "" }
    }

    private func send(_ text: String, to destination: Destination) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isSending = true
        let status = await MessageDispatcher.shared.send(text: trimmed, destination: destination, source: "watch")
        isSending = false
        lastStatus = status
        switch status {
        case .sent: WKHaptic.play(.success)
        case .pending: WKHaptic.play(.retry)
        case .failed: WKHaptic.play(.failure)
        }
    }
}

private enum WKHaptic {
    static func play(_ type: WKHapticType) {
        WKInterfaceDevice.current().play(type)
    }
}

struct WatchHistoryView: View {
    @State private var entries: [MessageLogEntry] = []
    @State private var sending: Set<UUID> = []

    var body: some View {
        List {
            if entries.isEmpty {
                Text("まだありません").foregroundStyle(.secondary)
            }
            ForEach(entries) { e in
                VStack(alignment: .leading) {
                    Text(e.message.text).lineLimit(2)
                    Text("\(e.destinationName) · \(e.label(sending: sending))")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                .swipeActions {
                    if case .sent = e.status {} else {
                        Button("再送") {
                            Task {
                                await MessageDispatcher.shared.retry(e.id)
                                await reload()
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("履歴")
        .task { await reload() }
        .onReceive(NotificationCenter.default.publisher(for: MessageDispatcher.didChange)) { _ in
            Task { await reload() }
        }
    }

    private func reload() async {
        entries = await MessageDispatcher.shared.entries
        sending = await MessageDispatcher.shared.sendingIDs
    }
}
