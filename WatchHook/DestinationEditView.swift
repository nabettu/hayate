import SwiftUI
import WatchHookCore

struct DestinationEditView: View {
    @Environment(\.dismiss) private var dismiss
    @State var destination: Destination
    /// 保存できたら true
    let onSave: (Destination) -> Bool

    @State private var error: String?
    @State private var testResult: String?
    @State private var isTesting = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("名前", text: $destination.name)
                    TextField(urlPlaceholder, text: $destination.url, axis: .vertical)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } footer: {
                    Text(urlFooter)
                }

                if destination.kind == .custom {
                    Section("リクエスト") {
                        Picker("メソッド", selection: $destination.method) {
                            ForEach(HTTPMethod.allCases, id: \.self) { Text($0.rawValue) }
                        }
                        Picker("本文の形式", selection: $destination.bodyEncoding) {
                            Text("JSON").tag(BodyEncoding.json)
                            Text("フォーム").tag(BodyEncoding.form)
                            Text("テキスト").tag(BodyEncoding.plain)
                        }
                    }

                    Section {
                        ForEach($destination.headers) { $h in
                            HeaderRow(header: $h)
                        }
                        .onDelete { destination.headers.remove(atOffsets: $0) }
                        Button("ヘッダを追加") {
                            destination.headers.append(HeaderField(name: "Authorization", value: "Bearer ", isSecret: true))
                        }
                    } header: {
                        Text("ヘッダ")
                    } footer: {
                        Text("Authorization などの認証ヘッダを登録できます。値は iPhone と Apple Watch の Keychain にだけ保存されます。")
                    }

                    Section {
                        TextEditor(text: $destination.bodyTemplate)
                            .font(.system(.footnote, design: .monospaced))
                            .frame(minHeight: 120)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    } header: {
                        Text("本文")
                    } footer: {
                        Text("{{text}} = 話した内容、{{id}} = メッセージ ID (再送しても同じ)、{{sentAt}} = 送信日時 (UTC)、{{source}} = 送信元。JSON では値を \"\" で囲んでください。")
                    }
                }

                Section {
                    Button {
                        Task { await sendTest() }
                    } label: {
                        HStack {
                            Text("テスト送信")
                            if isTesting { Spacer(); ProgressView() }
                        }
                    }
                    .disabled(isTesting)
                    if let testResult {
                        Text(testResult).font(.footnote).foregroundStyle(.secondary)
                    }
                }

                if let error {
                    Section { Text(error).foregroundStyle(.red) }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(destination.name.isEmpty ? "送り先" : destination.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完了") {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                }
            }
        }
    }

    private var urlPlaceholder: String {
        switch destination.kind {
        case .slack: "https://hooks.slack.com/services/..."
        case .discord: "https://discord.com/api/webhooks/..."
        case .custom: "https://example.com/webhook"
        }
    }

    private var urlFooter: String {
        switch destination.kind {
        case .slack: "Slack の Incoming Webhook の URL を貼ってください。"
        case .discord: "Discord のチャンネル設定 > 連携サービス > ウェブフック の URL を貼ってください。"
        case .custom: "https の URL だけ使えます。"
        }
    }

    private func save() {
        do {
            try RequestBuilder.validate(destination)
            if onSave(destination) {
                dismiss()
            } else {
                self.error = "端末に保存できませんでした"
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func sendTest() async {
        error = nil
        do { try RequestBuilder.validate(destination) } catch {
            self.error = error.localizedDescription
            return
        }
        isTesting = true
        defer { isTesting = false }
        let message = OutgoingMessage(text: "WatchHook のテスト送信です", destinationID: destination.id, source: "test")
        let result = await WebhookSender().send(message, to: destination)
        switch result {
        case .sent(let code): testResult = "届きました (HTTP \(code))"
        case .retryableFailure(let r), .permanentFailure(let r): testResult = "送れませんでした: \(r)"
        }
    }
}

private struct HeaderRow: View {
    @Binding var header: HeaderField
    @State private var reveal = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField("名前 (例: Authorization)", text: $header.name)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.subheadline.bold())
            HStack {
                Group {
                    if header.isSecret && !reveal {
                        SecureField("値", text: $header.value)
                    } else {
                        TextField("値", text: $header.value)
                    }
                }
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                if header.isSecret {
                    Button { reveal.toggle() } label: {
                        Image(systemName: reveal ? "eye.slash" : "eye")
                    }
                    .buttonStyle(.borderless)
                }
            }
            Toggle("秘密の値として伏せる", isOn: $header.isSecret).font(.caption)
        }
    }
}
