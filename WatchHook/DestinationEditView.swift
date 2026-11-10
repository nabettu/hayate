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
                Group {
                    Section {
                        TextField(namePlaceholder, text: $destination.name)
                    } header: {
                        Text("名前")
                    } footer: {
                        Text("Apple Watch・Siri・履歴で送り先として出る名前です。空のときは URL のホスト名を出します。")
                    }

                    Section {
                        TextField(urlPlaceholder, text: $destination.url, axis: .vertical)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    } header: {
                        Text("URL")
                    } footer: {
                        Text(urlFooter)
                    }

                    Section {
                        TextField("前に付ける文", text: $destination.textPrefix, axis: .vertical)
                        TextField("後ろに付ける文", text: $destination.textSuffix, axis: .vertical)
                    } header: {
                        Text("前後に付ける文")
                    } footer: {
                        Text("話した内容の前後に、書いたとおりに付けて送ります (空白や改行もそのまま)。例: 前に「#買い物 」と書くと「#買い物 牛乳」と送ります。")
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
                .listRowBackground(Cosmos.card)
            }
            .scrollDismissesKeyboard(.interactively)
            .cosmicListBackground()
            .navigationTitle(destination.displayName)
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

    private var namePlaceholder: String {
        switch destination.kind {
        case .slack: String(localized: "例: 家族の Slack")
        case .discord: String(localized: "例: メモ用チャンネル")
        case .custom: String(localized: "例: 買い物リスト")
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
        case .slack: String(localized: "Slack の Incoming Webhook の URL を貼ってください。")
        case .discord: String(localized: "Discord のチャンネル設定 > 連携サービス > ウェブフック の URL を貼ってください。")
        case .custom: String(localized: "https の URL だけ使えます。")
        }
    }

    private func save() {
        do {
            try RequestBuilder.validate(destination)
            if onSave(destination) {
                dismiss()
            } else {
                self.error = ConfigStore.shared.saveError ?? String(localized: "端末に保存できませんでした")
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// お試し前にテスト送信した回数 (秘密ではないので UserDefaults)。
    private static let testSendsKey = "testSendsBeforeTrial"

    private func sendTest() async {
        error = nil
        // 押した時点の設定で確かめて送る。StoreKit を読む await の間に URL などを書き換えられても、
        // 確かめていない設定 (書き換え後の URL に元の認証ヘッダ等) で送らないように
        let target = destination
        do { try RequestBuilder.validate(target) } catch {
            self.error = error.localizedDescription
            return
        }
        isTesting = true
        defer { isTesting = false }
        // 本文テンプレートを書き換えれば好きな内容を送れるので、お試し前は回数を決め、お試しが終わったあとは送らない
        let access = await EntitlementStore.currentAccess()
        let used = UserDefaults.standard.integer(forKey: Self.testSendsKey)
        guard TestSendPolicy.allows(access: access, usedBeforeTrial: used) else {
            testResult = access == .trialNotStarted
                ? String(localized: "お試し前のテスト送信は \(TestSendPolicy.limitBeforeTrial) 回までです。7 日間の無料お試しを始めると続けて試せます")
                : String(localized: "お試し期間が終わったため、テスト送信もできません。購入すると続けて使えます")
            return
        }
        if TestSendPolicy.counts(access: access) {
            UserDefaults.standard.set(used + 1, forKey: Self.testSendsKey)
        }
        let message = OutgoingMessage(text: target.wrap(String(localized: "Hayate のテスト送信です")), destinationID: target.id, source: "test")
        let result = await WebhookSender().send(message, to: target)
        switch result {
        case .sent(let code): testResult = String(localized: "届きました (HTTP \(code))")
        case .retryableFailure(let r), .permanentFailure(let r): testResult = String(localized: "送れませんでした: \(r)")
        case .cancelled: testResult = nil
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
