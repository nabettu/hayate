import SwiftUI
import WatchHookCore

/// iPhone でメモを入力する画面。保存と連携の送り方は時計と同じ `MemoDispatcher` を使う。
struct ComposeView: View {
    @State private var store = ConfigStore.shared
    @State private var integrations = IntegrationStore.shared
    @State private var text = ""
    @State private var isSending = false
    @State private var flight: FlightPhase = .idle
    @State private var lastResult: MemoFeedback?
    /// 見出しの紙飛行機の位置 (送るときにここから飛び立つ)。
    @State private var headerPlaneFrame: CGRect = .zero
    @FocusState private var focused: Bool
    /// 「連携」タブへ移る。
    var openIntegrations: () -> Void = {}

    private var canSend: Bool {
        !isSending && MessageText.normalized(text) != nil
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ScrollView {
                    VStack(spacing: 20) {
                        header
                        ForEach([store.saveError, store.syncError].compactMap { $0 }, id: \.self) { message in
                            Label(message, systemImage: "exclamationmark.triangle.fill")
                                .font(.subheadline)
                                .foregroundStyle(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(14)
                                .cosmicCard(cornerRadius: 16)
                        }
                        editor
                        Button {
                            Task { await send() }
                        } label: {
                            Label("メモする", systemImage: "paperplane.fill")
                        }
                        .buttonStyle(GlowButtonStyle())
                        .disabled(!canSend)
                        statusView
                            .frame(minHeight: 44)
                        targetsCard
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                }
                .scrollDismissesKeyboard(.interactively)
                FlightStage(phase: flight, planeSize: 120, launchFrame: headerPlaneFrame,
                            launchWidth: Self.headerPlaneWidth)
                    .ignoresSafeArea()
            }
            .background { CosmicBackground() }
            .toolbar {
                #if DEBUG
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        ForEach(FlightDemo.allCases) { demo in
                            Button(demo.rawValue) { Task { await playDemo(demo) } }
                        }
                    } label: {
                        Label("演出だけ見る", systemImage: "sparkles")
                    }
                    .disabled(isSending)
                }
                #endif
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完了") { focused = false }
                }
            }
        }
    }

    /// 入力したメモがどこへ行くか。押すと「連携」タブへ。
    private var targetsCard: some View {
        Button(action: openIntegrations) {
            VStack(alignment: .leading, spacing: 8) {
                let enabled = store.config.enabledDestinations
                Label {
                    Text(enabled.isEmpty ? String(localized: "送り先なし (メモだけ保存)")
                                         : enabled.map(\.displayName).joined(separator: "、"))
                        .lineLimit(2)
                } icon: {
                    Image(systemName: "paperplane").foregroundStyle(Cosmos.star)
                }
                if integrations.settings.reminder.isEnabled, let list = integrations.settings.reminder.listName {
                    let keyword = integrations.settings.reminder.keywords.first ?? ""
                    Label {
                        Text("「\(keyword)」で始めるとリマインダー (\(list)) に追加")
                    } icon: {
                        Image(systemName: "checklist").foregroundStyle(Cosmos.star)
                    }
                }
                if integrations.settings.markdown.isEnabled, let folder = integrations.settings.markdown.folderName {
                    Label {
                        Text("Markdown (\(folder)) に追記")
                    } icon: {
                        Image(systemName: "doc.text").foregroundStyle(Cosmos.star)
                    }
                }
            }
            .font(.footnote)
            .foregroundStyle(Cosmos.lavender)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .cosmicCard(cornerRadius: 16)
        }
        .buttonStyle(.plain)
    }

    private var header: some View {
        VStack(spacing: 6) {
            PaperPlane()
                .frame(width: Self.headerPlaneWidth)
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { headerPlaneFrame = $0 }
                .shadow(color: Cosmos.violet.opacity(0.9), radius: 16)
                // 飛び立つときは演出の紙飛行機と入れ替える (すぐ消す)。戻るときだけふわっと出す
                .opacity(flight == .idle ? 1 : 0)
                .animation(flight == .idle ? .easeIn(duration: 0.5) : nil, value: flight == .idle)
            Text("Hayate")
                .font(.system(.title, design: .rounded, weight: .bold))
                .foregroundStyle(.white)
            Text("メモして、リマインダーや webhook へ飛ばします")
                .font(.subheadline)
                .foregroundStyle(Cosmos.lavender.opacity(0.85))
        }
        .padding(.top, 24)
    }

    private var editor: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $text)
                .focused($focused)
                // 送信中に書き足した分を、送り終えたときの入力欄のクリアで消さないよう、送り終えるまで触らせない
                .disabled(isSending)
                .scrollContentBackground(.hidden)
                .foregroundStyle(.white)
                .frame(minHeight: 160)
                .padding(10)
            if text.isEmpty {
                Text("メモを入力")
                    .foregroundStyle(.white.opacity(0.35))
                    .padding(.horizontal, 15)
                    .padding(.vertical, 18)
                    .allowsHitTesting(false)
            }
        }
        .cosmicCard()
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Cosmos.lavender.opacity(focused ? 0.6 : 0), lineWidth: 1.5)
        )
        .animation(.easeInOut(duration: 0.2), value: focused)
    }

    @ViewBuilder private var statusView: some View {
        if isSending {
            Text("保存中…").foregroundStyle(Cosmos.lavender)
        } else if let lastResult {
            Group {
                switch lastResult.status {
                case .sent:
                    Label(lastResult.title, systemImage: "checkmark.circle.fill").foregroundStyle(Cosmos.star)
                case .pending:
                    Label(lastResult.title, systemImage: "arrow.clockwise").foregroundStyle(.orange)
                case .failed:
                    VStack(spacing: 4) {
                        Label(lastResult.title, systemImage: "xmark.circle.fill").foregroundStyle(.red)
                        if let detail = lastResult.detail {
                            Text(detail).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .font(.subheadline)
            .multilineTextAlignment(.center)
            .transition(.scale.combined(with: .opacity))
        }
    }

    private static let headerPlaneWidth: CGFloat = 72

    private func send() async {
        guard let body = MessageText.normalized(text), !isSending else { return }
        focused = false
        var saved = false
        await run {
            let memo = await MemoDispatcher.shared.record(text: body, source: "phone")
            saved = memo != nil
            return MemoFeedback(memo: memo, role: .phone)
        } onResult: { status in
            // 保存できたら入力欄を空にする (送れなかった分はメモの一覧から送り直せる)。保存できなければ残す
            if saved { text = "" }
            switch status {
            case .sent: UINotificationFeedbackGenerator().notificationOccurred(.success)
            case .pending: UINotificationFeedbackGenerator().notificationOccurred(.warning)
            case .failed: UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
        }
    }

    private func run(_ work: () async -> MemoFeedback, onResult: (MessageStatus) -> Void) async {
        isSending = true
        lastResult = nil
        var feedback: MemoFeedback?
        await playFlight(set: { flight = $0 }, current: { flight }, onResult: { status in
            isSending = false
            withAnimation(.spring(duration: 0.4)) { lastResult = feedback }
            onResult(status)
        }, work: {
            let result = await work()
            feedback = result
            return result.status
        })
    }

    #if DEBUG
    /// 保存せずに演出だけ流す。
    private func playDemo(_ demo: FlightDemo) async {
        focused = false
        await run({ MemoFeedback(demo: await demo.work()) }) { _ in }
    }
    #endif
}
