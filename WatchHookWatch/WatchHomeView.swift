import SwiftUI
import WatchKit
import WatchHookCore

struct WatchHomeView: View {
    @State private var store = ConfigStore.shared
    /// 時計の中だけで選ぶ送り先 (iPhone の「既定」とは別に持つ)。
    @AppStorage("selectedDestinationID") private var selectedID: String = ""
    @State private var lastResult: SendOutcome?
    @State private var isSending = false
    @State private var flight: FlightPhase = .idle
    /// 送るボタンの位置 (送るときにここから紙飛行機が飛び立つ)。
    @State private var orbFrame: CGRect = .zero
    @State private var entitlements = EntitlementStore.shared
    /// お試しの期限を画面を開いたまま過ぎても表示を変えるため、1 分ごとに進める。
    @State private var now = Date.now

    private var destination: Destination? { store.config.resolve(selectedID: selectedID) }

    var body: some View {
        NavigationStack {
            Group {
                if let destination {
                    ZStack {
                        ScrollView {
                            VStack(spacing: 8) {
                                saveErrorView
                                accessView
                                // 標準の入力画面 (音声入力・スクリブル・キーボード) を開く。ダブルタップでも押せる
                                TextFieldLink(prompt: Text("話すか、文字を入力")) {
                                    SendOrb(isBusy: isSending, planeLaunched: { if case .sending = flight { true } else { false } }())
                                        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { orbFrame = $0 }
                                } onSubmit: { text in
                                    Task { await send(text, to: destination) }
                                }
                                .buttonStyle(.plain)
                                .handGestureShortcut(.primaryAction)
                                .disabled(isSending || !entitlements.access(now: now).canSend)
                                .accessibilityLabel("送る")

                                statusView
                                    .frame(minHeight: 22)

                                if store.config.destinations.count > 1 {
                                    Picker(selection: $selectedID) {
                                        ForEach(store.config.destinations) { d in
                                            // iPhone で既定にした送り先が、時計で何も選んでいないときの送り先
                                            Text(d.id == store.config.defaultDestination?.id ? String(localized: "\(d.displayName) (既定)") : d.displayName)
                                                .tag(d.id.uuidString)
                                        }
                                    } label: {
                                        Label("送り先", systemImage: "paperplane")
                                    }
                                    .tint(Cosmos.lavender)
                                } else {
                                    Label(destination.displayName, systemImage: "paperplane")
                                        .font(.footnote).foregroundStyle(Cosmos.lavender)
                                }

                                NavigationLink {
                                    WatchHistoryView()
                                } label: {
                                    Label("履歴", systemImage: "clock")
                                }
                                .font(.footnote)

                                #if DEBUG
                                VStack(spacing: 4) {
                                    Text("演出だけ見る (デバッグ)").font(.caption2).foregroundStyle(.secondary)
                                    ForEach(FlightDemo.allCases) { demo in
                                        Button(demo.rawValue) { Task { await playDemo(demo) } }
                                            .font(.caption2)
                                            .disabled(isSending)
                                    }
                                }
                                .padding(.top, 8)
                                #endif
                            }
                        }
                        FlightStage(phase: flight, planeSize: 56, launchFrame: orbFrame, launchWidth: 34,
                                    launchFadesIn: true)
                            .ignoresSafeArea()
                    }
                    .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { now = $0 }
                    .onAppear(perform: fixSelection)
                    .onChange(of: store.config) { fixSelection() }
                    // 前に送った結果を、選び直した送り先の結果と見間違えないように消す
                    .onChange(of: selectedID) { if !isSending { lastResult = nil } }
                } else {
                    ScrollView {
                        VStack(spacing: 10) {
                            saveErrorView
                            PaperPlane().frame(width: 44)
                                .shadow(color: Cosmos.violet, radius: 8)
                            Text("iPhone の Hayate で送り先を登録してください")
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

    /// お試し前・お試しが終わったとき。購入は iPhone で行う。
    @ViewBuilder private var accessView: some View {
        if let message = entitlements.access(now: now).blockedMessage {
            Label(message, systemImage: "lock.fill")
                .font(.caption2)
                .foregroundStyle(.orange)
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
            Text("送信中…").font(.footnote).foregroundStyle(Cosmos.lavender)
        } else if let lastResult {
            let name = lastResult.destinationName
            Group {
                switch lastResult.status {
                case .sent:
                    Label("「\(name)」に送りました", systemImage: "checkmark.circle.fill").foregroundStyle(Cosmos.star)
                case .pending:
                    Label("「\(name)」へはあとで送り直します", systemImage: "arrow.clockwise").foregroundStyle(.orange)
                case .failed(let reason):
                    VStack {
                        Label("「\(name)」に送れませんでした", systemImage: "xmark.circle.fill").foregroundStyle(.red)
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
        if let corrected = store.config.correctedSelection(selectedID) { selectedID = corrected }
    }

    private func send(_ text: String, to destination: Destination) async {
        // 最初の await より前に立てる (StoreKit を読んでいる間にもう一度送れないように)
        guard let text = MessageText.normalized(text), !isSending else { return }
        isSending = true
        // 画面を開いたままお試しの期限を過ぎることがあるので、送る直前にも確かめる。
        // 画面用の refresh は別の refresh と重なると結果を捨てるので、判定はその場で読んだ結果で行う
        let access = await EntitlementStore.currentAccess()
        Task { await entitlements.refresh() }  // 画面の表示も合わせる
        now = .now
        if let blocked = access.blockedMessage {
            isSending = false
            lastResult = SendOutcome(status: .failed(reason: String(localized: "送っていません。\(blocked)")), destinationName: destination.displayName)
            WKHaptic.play(.failure)
            return
        }
        await run(destinationName: destination.displayName) {
            await MessageDispatcher.shared.send(text: text, destination: destination, source: "watch")
        }
    }

    private func run(destinationName: String, _ work: () async -> MessageStatus) async {
        isSending = true
        lastResult = nil
        await playFlight(set: { flight = $0 }, current: { flight }, onResult: { status in
            isSending = false
            withAnimation(.spring(duration: 0.4)) { lastResult = SendOutcome(status: status, destinationName: destinationName) }
            switch status {
            case .sent: WKHaptic.play(.success)
            case .pending: WKHaptic.play(.retry)
            case .failed: WKHaptic.play(.failure)
            }
        }, work: work)
    }

    #if DEBUG
    /// 送らずに演出だけ流す (履歴にも残らない)。
    private func playDemo(_ demo: FlightDemo) async {
        await run(destinationName: destination?.displayName ?? "演出", demo.work)
    }
    #endif
}

/// 送るボタン (話す・文字を入力する)。紫に光る丸と、ゆっくり広がる輪。
private struct SendOrb: View {
    var isBusy: Bool
    /// 紙飛行機が飛び立っているあいだはボタンの中の紙飛行機を隠す (飛んでいるのと 2 機に見えないように)。
    var planeLaunched = false
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
                    Image(systemName: "paperplane.fill").font(.title2.bold())
                        .opacity(planeLaunched ? 0 : 1)
                        .animation(.easeOut(duration: 0.15), value: planeLaunched)
                    Text("送る").font(.caption2.bold())
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
    /// お試しの期限を画面を開いたまま過ぎても、再送ボタンを消すため 1 分ごとに進める。
    @State private var now = Date.now

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
                    if case .sent = e.status {} else if EntitlementStore.shared.access(now: now).canSend {
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
        .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { now = $0 }
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
