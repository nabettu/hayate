import SwiftUI
import WatchHookCore

/// iPhone からテキストを入力して送り先へ送る画面。送り方 (履歴・再送) は時計と同じ `MessageDispatcher` を使う。
struct ComposeView: View {
    @State private var store = ConfigStore.shared
    /// iPhone の中だけで選ぶ送り先 (未選択なら既定)。時計の選択とは別に持つ。
    @AppStorage("composeDestinationID") private var selectedID: String = ""
    @State private var text = ""
    @State private var isSending = false
    @State private var flight: FlightPhase = .idle
    @State private var lastStatus: MessageStatus?
    /// 見出しの紙飛行機の位置 (送るときにここから飛び立つ)。
    @State private var headerPlaneFrame: CGRect = .zero
    @FocusState private var focused: Bool
    /// 送り先が無いときに「送り先」タブへ移る。
    var openDestinations: () -> Void = {}

    private var destination: Destination? { store.config.resolve(selectedID: selectedID) }
    private var canSend: Bool { !isSending && destination != nil && MessageText.normalized(text) != nil }

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
                        if let destination {
                            destinationPicker(current: destination)
                            editor
                            Button {
                                Task { await send() }
                            } label: {
                                Label("送る", systemImage: "paperplane.fill")
                            }
                            .buttonStyle(GlowButtonStyle())
                            .disabled(!canSend)
                            statusView
                                .frame(minHeight: 44)
                        } else if store.saveError == nil {
                            // 設定を読めなかったとき (上にエラーを出す) は「未登録」と案内しない
                            emptyState
                        }
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
            .onAppear(perform: fixSelection)
            .onChange(of: store.config) { fixSelection() }
        }
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
            Text("テキストを書いて、webhook へ飛ばします")
                .font(.subheadline)
                .foregroundStyle(Cosmos.lavender.opacity(0.85))
        }
        .padding(.top, 24)
    }

    private func destinationPicker(current: Destination) -> some View {
        Menu {
            Picker("送り先", selection: $selectedID) {
                ForEach(store.config.destinations) { d in
                    Text(d.name).tag(d.id.uuidString)
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "scope")
                    .foregroundStyle(Cosmos.star)
                Text("送り先").foregroundStyle(.secondary)
                Text(current.name).fontWeight(.semibold).foregroundStyle(.white).lineLimit(1)
                Spacer(minLength: 0)
                Image(systemName: "chevron.up.chevron.down").font(.caption).foregroundStyle(.secondary)
            }
            .font(.subheadline)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .cosmicCard(cornerRadius: 16)
        }
        // 送信中に変えると、結果の表示が実際に送った先とずれるので変えさせない
        .disabled(store.config.destinations.count < 2 || isSending)
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
                Text("送りたいことを入力")
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
            Text("送信中…").foregroundStyle(Cosmos.lavender)
        } else if let lastStatus {
            Group {
                switch lastStatus {
                case .sent:
                    Label("送りました", systemImage: "checkmark.circle.fill").foregroundStyle(Cosmos.star)
                case .pending:
                    Label("今は送れませんでした。あとで送り直します", systemImage: "arrow.clockwise").foregroundStyle(.orange)
                case .failed(let reason):
                    VStack(spacing: 4) {
                        Label("送れませんでした", systemImage: "xmark.circle.fill").foregroundStyle(.red)
                        Text(reason).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .font(.subheadline)
            .multilineTextAlignment(.center)
            .transition(.scale.combined(with: .opacity))
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Text("送り先がまだありません")
                .font(.headline).foregroundStyle(.white)
            Text("「送り先」タブで Slack・Discord・webhook を登録すると、ここから送れます。")
                .font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                openDestinations()
            } label: {
                Label("送り先を登録する", systemImage: "plus")
            }
            .buttonStyle(GlowButtonStyle())
        }
        .padding(20)
        .cosmicCard()
    }

    private func fixSelection() {
        if let corrected = store.config.correctedSelection(selectedID) { selectedID = corrected }
    }

    private static let headerPlaneWidth: CGFloat = 72

    private func send() async {
        guard let destination, let body = MessageText.normalized(text) else { return }
        focused = false
        await run {
            await MessageDispatcher.shared.send(text: body, destination: destination, source: "phone")
        } onResult: { status in
            switch status {
            case .sent:
                text = ""
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            case .pending:
                // 履歴に残って自動で送り直すので、入力欄は空にする (同じ内容を二重に送らないように)
                text = ""
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
            case .failed:
                // 直して送り直せるよう、入力は残す
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
        }
    }

    private func run(_ work: () async -> MessageStatus, onResult: (MessageStatus) -> Void) async {
        isSending = true
        lastStatus = nil
        await playFlight(set: { flight = $0 }, current: { flight }, onResult: { status in
            isSending = false
            withAnimation(.spring(duration: 0.4)) { lastStatus = status }
            onResult(status)
        }, work: work)
    }

    #if DEBUG
    /// 送らずに演出だけ流す (履歴にも残らない)。
    private func playDemo(_ demo: FlightDemo) async {
        focused = false
        await run(demo.work) { _ in }
    }
    #endif
}
