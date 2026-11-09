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
                        } else {
                            emptyState
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                }
                .scrollDismissesKeyboard(.interactively)
                FlightStage(phase: flight, planeSize: 120)
                    .ignoresSafeArea()
            }
            .background { CosmicBackground() }
            .toolbar {
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
                .frame(width: 72)
                .shadow(color: Cosmos.violet.opacity(0.9), radius: 16)
                .opacity(flight == .idle ? 1 : 0.25)
                .animation(.easeInOut(duration: 0.3), value: flight == .idle)
            Text("WatchHook")
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
        .disabled(store.config.destinations.count < 2)
    }

    private var editor: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $text)
                .focused($focused)
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
        let resolved = store.config.resolve(selectedID: selectedID)?.id.uuidString ?? ""
        if resolved != selectedID { selectedID = resolved }
    }

    private func send() async {
        guard let destination, let body = MessageText.normalized(text) else { return }
        focused = false
        let start = Date.now
        isSending = true
        lastStatus = nil
        flight = .sending(since: start)
        let status = await MessageDispatcher.shared.send(text: body, destination: destination, source: "phone")
        await waitForArrival(since: start)
        isSending = false
        withAnimation(.spring(duration: 0.4)) { lastStatus = status }
        let phase: FlightPhase
        switch status {
        case .sent:
            phase = .sent(at: .now)
            text = ""
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .pending:
            // 履歴に残って自動で送り直すので、入力欄は空にする (同じ内容を二重に送らないように)
            phase = .queued(at: .now)
            text = ""
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        case .failed:
            // 直して送り直せるよう、入力は残す
            phase = .failed(at: .now)
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
        flight = phase
        try? await Task.sleep(for: .seconds(FlightPhase.exit * 1.5))
        if flight == phase { flight = .idle }
    }
}
