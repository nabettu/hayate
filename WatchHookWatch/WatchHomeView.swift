import SwiftUI
import WatchKit
import WatchHookCore

struct WatchHomeView: View {
    @State private var store = ConfigStore.shared
    /// 時計の中だけで選ぶ送り先 (iPhone の「既定」とは別に持つ)。
    @AppStorage("selectedDestinationID") private var selectedID: String = ""
    @State private var lastStatus: MessageStatus?
    @State private var isSending = false
    @State private var flight: FlightPhase = .idle

    private var destination: Destination? { store.config.resolve(selectedID: selectedID) }

    var body: some View {
        NavigationStack {
            Group {
                if let destination {
                    ZStack {
                        ScrollView {
                            VStack(spacing: 8) {
                                saveErrorView
                                // 標準の入力画面 (音声入力・スクリブル) を開く。ダブルタップでも押せる
                                TextFieldLink(prompt: Text("話してください")) {
                                    MicOrb(isBusy: isSending)
                                } onSubmit: { text in
                                    Task { await send(text, to: destination) }
                                }
                                .buttonStyle(.plain)
                                .handGestureShortcut(.primaryAction)
                                .disabled(isSending)
                                .accessibilityLabel("話す")

                                statusView
                                    .frame(minHeight: 22)

                                if store.config.destinations.count > 1 {
                                    Picker(selection: $selectedID) {
                                        ForEach(store.config.destinations) { d in
                                            Text(d.name).tag(d.id.uuidString)
                                        }
                                    } label: {
                                        Label("送り先", systemImage: "paperplane")
                                    }
                                    .tint(Cosmos.lavender)
                                } else {
                                    Label(destination.name, systemImage: "paperplane")
                                        .font(.footnote).foregroundStyle(Cosmos.lavender)
                                }

                                NavigationLink {
                                    WatchHistoryView()
                                } label: {
                                    Label("履歴", systemImage: "clock")
                                }
                                .font(.footnote)
                            }
                        }
                        FlightStage(phase: flight, planeSize: 56)
                            .ignoresSafeArea()
                    }
                    .onAppear(perform: fixSelection)
                    .onChange(of: store.config) { fixSelection() }
                } else {
                    ScrollView {
                        VStack(spacing: 10) {
                            saveErrorView
                            PaperPlane().frame(width: 44)
                                .shadow(color: Cosmos.violet, radius: 8)
                            Text("iPhone の WatchHook で送り先を登録してください")
                                .multilineTextAlignment(.center)
                                .font(.footnote)
                            Button("再読み込み") { WatchSync.shared.requestConfig() }
                                .tint(Cosmos.violet)
                            // 送り先が無くても、これまでの履歴は見られるようにする
                            NavigationLink {
                                WatchHistoryView()
                            } label: {
                                Label("履歴", systemImage: "clock")
                            }
                            .font(.footnote)
                        }
                    }
                }
            }
            .containerBackground(for: .navigation) { CosmicBackground(starCount: 26) }
        }
        .tint(Cosmos.lavender)
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
            Text("送信中…").font(.footnote).foregroundStyle(Cosmos.lavender)
        } else if let lastStatus {
            Group {
                switch lastStatus {
                case .sent:
                    Label("送りました", systemImage: "checkmark.circle.fill").foregroundStyle(Cosmos.star)
                case .pending:
                    Label("あとで送り直します", systemImage: "arrow.clockwise").foregroundStyle(.orange)
                case .failed(let reason):
                    VStack {
                        Label("送れませんでした", systemImage: "xmark.circle.fill").foregroundStyle(.red)
                        Text(reason).font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
            .font(.footnote)
            .transition(.scale.combined(with: .opacity))
        }
    }

    /// 選んでいた送り先が iPhone で消されたら、既定の送り先に合わせる (表示と実際の送り先をずらさない)。
    private func fixSelection() {
        let resolved = store.config.resolve(selectedID: selectedID)?.id.uuidString ?? ""
        if resolved != selectedID { selectedID = resolved }
    }

    private func send(_ text: String, to destination: Destination) async {
        guard let text = MessageText.normalized(text) else { return }
        let start = Date.now
        isSending = true
        lastStatus = nil
        flight = .sending(since: start)
        let status = await MessageDispatcher.shared.send(text: text, destination: destination, source: "watch")
        // 紙飛行機が飛んできてから結果を出す
        await waitForArrival(since: start)
        isSending = false
        withAnimation(.spring(duration: 0.4)) { lastStatus = status }
        let phase: FlightPhase
        switch status {
        case .sent:
            phase = .sent(at: .now)
            WKHaptic.play(.success)
        case .pending:
            phase = .queued(at: .now)
            WKHaptic.play(.retry)
        case .failed:
            phase = .failed(at: .now)
            WKHaptic.play(.failure)
        }
        flight = phase
        try? await Task.sleep(for: .seconds(FlightPhase.exit * 1.5))
        if flight == phase { flight = .idle }
    }
}

/// 話すボタン。紫に光る丸と、ゆっくり広がる輪。
private struct MicOrb: View {
    var isBusy: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20, paused: reduceMotion || isBusy)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            ZStack {
                ForEach(0..<2) { i in
                    let p = reduceMotion ? 0.3 : (t / 2.4 + Double(i) * 0.5).truncatingRemainder(dividingBy: 1)
                    Circle()
                        .stroke(Cosmos.lavender.opacity(0.55 * (1 - p)), lineWidth: 1.5)
                        .scaleEffect(1 + p * 0.45)
                }
                Circle()
                    .fill(Cosmos.glow)
                    .overlay(Circle().strokeBorder(.white.opacity(0.35), lineWidth: 1))
                    .shadow(color: Cosmos.violet.opacity(0.9), radius: 10)
                VStack(spacing: 2) {
                    Image(systemName: "mic.fill").font(.title2.bold())
                    Text("話す").font(.caption2.bold())
                }
                .foregroundStyle(.white)
            }
            .frame(width: 84, height: 84)
            .opacity(isBusy ? 0.5 : 1)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
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
                        .font(.caption2).foregroundStyle(Cosmos.lavender.opacity(0.8))
                }
                .listRowBackground(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Cosmos.card))
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
        .containerBackground(for: .navigation) { CosmicBackground(starCount: 26) }
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
