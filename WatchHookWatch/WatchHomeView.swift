import SwiftUI
import WatchKit
import WatchHookCore

struct WatchHomeView: View {
    @State private var store = ConfigStore.shared
    @State private var lastResult: MemoFeedback?
    /// 結果を出すたびに進める。「保存しました」を消すときに、その後に出た結果まで消さないため。
    @State private var resultSerial = 0
    /// 「保存して送りました」を出しておく長さ。送れなかった・あとで送り直す、は読めるよう消さない。
    private static let sentMessageDuration: Duration = .seconds(3)
    @State private var isSending = false
    @State private var flight: FlightPhase = .idle
    /// 送るボタンの位置 (送るときにここから紙飛行機が飛び立つ)。
    @State private var orbFrame: CGRect = .zero

    var body: some View {
        NavigationStack {
            // 入力の画面の下にメモの一覧を置く (デジタルクラウンを回すか、上へスワイプ = 下へスクロールで移る)
            TabView {
                homePage
                    .containerBackground(for: .tabView) { CosmicBackground(starCount: 26) }
                WatchHistoryView()
                    .containerBackground(for: .tabView) { CosmicBackground(starCount: 26) }
            }
            .tabViewStyle(.verticalPage)
            // 押して開く画面の背景
            .containerBackground(for: .navigation) { CosmicBackground(starCount: 26) }
        }
        .tint(Cosmos.lavender)
    }

    private var homePage: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 12) {
                    saveErrorView
                    // 標準の入力画面 (音声入力・スクリブル・キーボード) を開く。ダブルタップでも押せる。
                    // 送り先が無くてもメモとして保存できる
                    TextFieldLink(prompt: Text("話すか、文字を入力")) {
                        SendOrb(isBusy: isSending, planeLaunched: flight.isFlying)
                            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { orbFrame = $0 }
                    } onSubmit: { text in
                        Task { await record(text) }
                    }
                    .buttonStyle(.plain)
                    .handGestureShortcut(.primaryAction)
                    .disabled(isSending)
                    .accessibilityLabel("メモする")

                    statusView
                        .frame(minHeight: 22)

                    destinationsLabel

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
    }

    /// 入力したメモをどこへ送るか (iPhone で有効にした送り先)。選ぶ画面は無い。
    @ViewBuilder private var destinationsLabel: some View {
        let enabled = store.config.enabledDestinations
        Group {
            switch enabled.count {
            case 0:
                Label("メモだけ保存", systemImage: "note.text")
            case 1:
                Label(enabled[0].displayName, systemImage: "paperplane")
            default:
                Label("送り先 \(enabled.count) 件", systemImage: "paperplane")
            }
        }
        .font(.footnote)
        .lineLimit(1)
        .foregroundStyle(Cosmos.lavender)
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
            Text("保存中…").font(.footnote).foregroundStyle(Cosmos.lavender)
        } else if let lastResult {
            Group {
                switch lastResult.status {
                case .sent:
                    Label(lastResult.title, systemImage: "checkmark.circle.fill").foregroundStyle(Cosmos.star)
                case .pending:
                    Label(lastResult.title, systemImage: "arrow.clockwise").foregroundStyle(.orange)
                case .failed:
                    VStack(spacing: 2) {
                        Label(lastResult.title, systemImage: "xmark.circle.fill").foregroundStyle(.red)
                        if let detail = lastResult.detail {
                            Text(detail).font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .font(.footnote)
            .multilineTextAlignment(.center)
            .transition(.scale.combined(with: .opacity))
        }
    }

    private func record(_ text: String) async {
        guard let text = MessageText.normalized(text), !isSending else { return }
        await run {
            MemoFeedback(memo: await MemoDispatcher.shared.record(text: text, source: "watch"), role: .watch)
        }
    }

    private func run(_ work: () async -> MemoFeedback) async {
        isSending = true
        lastResult = nil
        var feedback: MemoFeedback?
        await playFlight(set: { flight = $0 }, current: { flight }, onResult: { status in
            isSending = false
            withAnimation(.spring(duration: 0.4)) { lastResult = feedback }
            resultSerial += 1
            if case .sent = status { hideSentMessage(serial: resultSerial) }
            switch status {
            case .sent: WKHaptic.play(.success)
            case .pending: WKHaptic.play(.retry)
            case .failed: WKHaptic.play(.failure)
            }
        }, work: {
            let result = await work()
            feedback = result
            return result.status
        })
    }

    private func hideSentMessage(serial: Int) {
        Task {
            try? await Task.sleep(for: Self.sentMessageDuration)
            guard resultSerial == serial, !isSending else { return }
            withAnimation(.easeOut(duration: 0.4)) { lastResult = nil }
        }
    }

    #if DEBUG
    /// 保存せずに演出だけ流す。
    private func playDemo(_ demo: FlightDemo) async {
        await run {
            MemoFeedback(demo: await demo.work())
        }
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
                    Text("メモ").font(.caption2.bold())
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

/// 時計に残っているメモ (直近 50 件)。消す・後から送るは iPhone で行う。
struct WatchHistoryView: View {
    @State private var memos: [Memo] = []
    @State private var sending: Set<UUID> = []

    var body: some View {
        List {
            if memos.isEmpty {
                Text("まだありません").foregroundStyle(.secondary)
            }
            ForEach(memos) { memo in
                NavigationLink {
                    WatchMemoDetailView(memoID: memo.id)
                } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(memo.text).lineLimit(2)
                        HStack(spacing: 4) {
                            Image(systemName: memo.summary.symbol)
                            Text(memo.summary.label)
                            if memo.phoneSync == .waiting {
                                Image(systemName: "iphone.slash").accessibilityLabel("iPhone に未同期")
                            }
                        }
                        .font(.caption2).foregroundStyle(Cosmos.lavender.opacity(0.8))
                    }
                }
                .listRowBackground(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Cosmos.card))
            }
        }
        .navigationTitle("メモ")
        .task { await reload() }
        .onReceive(NotificationCenter.default.publisher(for: MemoDispatcher.didChange)) { _ in
            Task { await reload() }
        }
    }

    private func reload() async {
        memos = await MemoDispatcher.shared.memos
        sending = await MemoDispatcher.shared.sendingIDs
    }
}

/// 1 件のメモと、連携ごとの状態。時計から送る webhook は、送れなかったら送り直せる。
private struct WatchMemoDetailView: View {
    let memoID: UUID
    @State private var memo: Memo?
    @State private var sending: Set<UUID> = []

    var body: some View {
        List {
            if let memo {
                Text(memo.text)
                Text(memo.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2).foregroundStyle(.secondary)
                if memo.phoneSync == .waiting {
                    Label("iPhone にまだ渡せていません", systemImage: "iphone.slash")
                        .font(.caption2).foregroundStyle(.orange)
                }
                ForEach(memo.deliveries) { d in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(d.target.displayName).font(.footnote).lineLimit(2)
                        Text(d.status.label(isSending: sending.contains(d.id)))
                            .font(.caption2).foregroundStyle(Cosmos.lavender.opacity(0.8))
                        if let reason = d.status.reason, !d.status.isDone {
                            Text(reason).font(.caption2).foregroundStyle(.secondary)
                        }
                        if d.owner == .watch, !d.status.isDone, d.status != .cancelled, !sending.contains(d.id) {
                            Button("送り直す") {
                                Task { await MemoDispatcher.shared.retry(memoID: memoID, deliveryID: d.id) }
                            }
                            .font(.caption2)
                        }
                    }
                }
            } else {
                Text("このメモは削除されました").foregroundStyle(.secondary)
            }
        }
        .navigationTitle("メモ")
        .task { await reload() }
        .onReceive(NotificationCenter.default.publisher(for: MemoDispatcher.didChange)) { _ in
            Task { await reload() }
        }
    }

    private func reload() async {
        memo = await MemoDispatcher.shared.memo(id: memoID)
        sending = await MemoDispatcher.shared.sendingIDs
    }
}
