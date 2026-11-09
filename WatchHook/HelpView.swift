import SwiftUI

/// アプリ内のマニュアル。目次 → 各ページ。
struct HelpView: View {
    var body: some View {
        NavigationStack {
            List {
                Group {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Apple Watch で話した内容を、登録した送り先 (Slack・Discord・自分の webhook) へそのまま送るアプリです。")
                            Text("はじめに").font(.headline).padding(.top, 4)
                            Step(number: 1, text: "「送り先」タブの + から送り先を登録する")
                            Step(number: 2, text: "編集画面の「テスト送信」で届くか確かめる")
                            Step(number: 3, text: "Apple Watch で「Hey Siri、WatchHook で送って」と話しかける")
                        }
                        .padding(.vertical, 4)
                    }

                    Section("使い方") {
                        NavigationLink { WatchUsagePage() } label: {
                            Label("Apple Watch から送る", systemImage: "applewatch")
                        }
                        NavigationLink { WidgetPage() } label: {
                            Label("文字盤・スマートスタックに置く", systemImage: "square.stack")
                        }
                        NavigationLink { ChooseDestinationPage() } label: {
                            Label("送り先を切り替える", systemImage: "star")
                        }
                    }

                    Section("送り先の登録") {
                        NavigationLink { SlackPage() } label: {
                            Label("Slack", systemImage: "number")
                        }
                        NavigationLink { DiscordPage() } label: {
                            Label("Discord", systemImage: "bubble.left.and.bubble.right")
                        }
                        NavigationLink { CustomWebhookPage() } label: {
                            Label("Webhook (自由に設定)", systemImage: "curlybraces")
                        }
                    }

                    Section("困ったとき") {
                        NavigationLink { TroublePage() } label: {
                            Label("送れなかったとき", systemImage: "exclamationmark.triangle")
                        }
                        NavigationLink { ReceiverSpecPage() } label: {
                            Label("受け取る側の仕様", systemImage: "server.rack")
                        }
                        NavigationLink { PrivacyPage() } label: {
                            Label("データの扱い", systemImage: "lock")
                        }
                    }
                }
                .listRowBackground(Cosmos.card)
            }
            .navigationTitle("使い方")
            .cosmicListBackground()
        }
    }
}

// MARK: - ページ

private struct WatchUsagePage: View {
    var body: some View {
        HelpPage(title: "Apple Watch から送る") {
            Section("Siri で送る (手を使わない)") {
                Para("「Hey Siri、WatchHook で送って」と話しかけ、「何を送りますか？」と聞かれたら送りたい内容を話します。")
                Para("「WatchHook で送る」「WatchHook に送って」でも動きます。送り先は iPhone で「既定」にしたものです (ショートカット App で送り先を指定した場合はそちら)。")
                Para("iPhone の Siri でも同じように送れます。")
            }
            Section("アプリから送る") {
                Para("時計で WatchHook を開き、オレンジの「話す」を押して話します。話し終えたら「完了」で送ります。")
                Para("Series 9 / Ultra 2 以降は、親指と人差し指をダブルタップしても「話す」を押せます。")
                Para("送れたら時計が振動し、「送りました」と出ます。")
            }
            Section("届き方") {
                Para("時計から送り先へ直接送ります。iPhone のアプリを開いていなくても、時計が Wi-Fi・モバイル通信・iPhone 経由のどれかでつながっていれば届きます。")
            }
        }
    }
}

private struct WidgetPage: View {
    var body: some View {
        HelpPage(title: "文字盤・スマートスタックに置く") {
            Section("文字盤のコンプリケーション") {
                Para("時計の文字盤を長押し →「編集」→ コンプリケーションの枠を選び、一覧の「WatchHook」から形を選びます。")
                Para("タップすると WatchHook が開き、すぐ「話す」を押せます。")
            }
            Section("スマートスタック") {
                Para("文字盤でデジタルクラウンを回す (または下からスワイプ) とスマートスタックが出ます。どれかのウィジェットを長押しして編集の状態にし、上の + から「WatchHook」を選んで足します。")
            }
            Section("iPhone の Watch アプリから") {
                Para("iPhone の「Watch」アプリ →「マイウォッチ」の文字盤 → コンプリケーションでも設定できます。")
            }
        }
    }
}

private struct ChooseDestinationPage: View {
    var body: some View {
        HelpPage(title: "送り先を切り替える") {
            Section("既定の送り先") {
                Para("「送り先」タブで送り先を右へスワイプし、「既定にする」を押します。★ が付いたものが既定です。")
                Para("Siri で送るときは、送り先を指定していなければ既定の送り先へ送ります。ショートカット App で送り先を指定したものは、既定を変えてもその送り先のままです。")
            }
            Section("時計で選ぶ") {
                Para("送り先が 2 つ以上あると、時計の「話す」の下に送り先の選択が出ます。ここで選んだものは時計のアプリから送るときだけ使います (iPhone の既定は変わりません)。")
            }
            Section("設定が時計に届かないとき") {
                Para("送り先は iPhone から時計へ自動で送られます。時計に出てこないときは、iPhone と時計の両方で WatchHook を開いてください。時計に送り先が 1 つも無いときは、時計の画面の「再読み込み」でも受け取り直せます。")
            }
        }
    }
}

private struct SlackPage: View {
    var body: some View {
        HelpPage(title: "Slack") {
            Section("URL を用意する") {
                Para("Slack で送りたいチャンネル用の Incoming Webhook を作り、URL (https://hooks.slack.com/services/... ) をコピーします。")
                Para("作り方: api.slack.com/apps → Create New App → Incoming Webhooks をオン → Add New Webhook to Workspace でチャンネルを選ぶ。")
            }
            Section("登録する") {
                Para("「送り先」タブの + →「Slack」を選び、URL を貼って保存します。本文などは自動で設定されます。")
                Para("保存の前に「テスト送信」で、チャンネルに「WatchHook のテスト送信です」と出るか確かめてください。")
            }
        }
    }
}

private struct DiscordPage: View {
    var body: some View {
        HelpPage(title: "Discord") {
            Section("URL を用意する") {
                Para("Discord で送りたいチャンネルの設定 (歯車) →「連携サービス」→「ウェブフック」→「新しいウェブフック」を作り、「ウェブフック URL をコピー」を押します。")
            }
            Section("登録する") {
                Para("「送り先」タブの + →「Discord」を選び、URL を貼って保存します。本文などは自動で設定されます。")
                Para("保存の前に「テスト送信」で、チャンネルに届くか確かめてください。")
            }
        }
    }
}

private struct CustomWebhookPage: View {
    var body: some View {
        HelpPage(title: "Webhook (自由に設定)") {
            Section("URL・メソッド") {
                Para("https の URL だけ使えます (http は使えません)。メソッドは受け取る側に合わせて選びます。ふつうは POST です。")
            }
            Section("本文の形式") {
                Para("JSON・フォーム・テキストから選びます。Content-Type は形式に合わせて自動で付きます。")
                Para("話した言葉だけを送りたいときは、形式を「テキスト」、本文を {{text}} だけにします。")
            }
            Section("本文に入れられるもの") {
                Code("{{text}}", "話した内容")
                Code("{{id}}", "メッセージごとの ID。送り直しても同じ")
                Code("{{sentAt}}", "送った日時 (UTC、ISO 8601)")
                Code("{{source}}", "送り元: watch / phone / siri-watch / siri-phone / test")
                Para("JSON では値を \"\" で囲みます。例: {\"text\":\"{{text}}\"}。話した内容に \" や改行があっても、JSON が壊れないように自動で直します。")
            }
            Section("認証ヘッダ") {
                Para("「ヘッダを追加」で Authorization などを足せます。値は Bearer <鍵> のように入れます。")
                Para("「秘密の値として伏せる」をオンにすると、画面で伏せ字になります。値は iPhone と時計の Keychain にだけ保存されます。")
                Para("Host・Content-Length・Connection・Transfer-Encoding・X-WatchHook-Message-Id は指定できません。")
            }
        }
    }
}

private struct TroublePage: View {
    var body: some View {
        HelpPage(title: "送れなかったとき") {
            Section("自動で送り直すもの") {
                Para("通信できない・時間切れ・受け取る側の混雑 (HTTP 408 / 429 / 5xx) のときは、時計や iPhone に溜めておき、次にアプリを開いたときに送り直します (最初の 1 回を含めて最大 5 回)。")
                Para("「履歴」で状態を見られます。左へスワイプすると「再送」できます。")
            }
            Section("送り直しても届かないもの") {
                Para("HTTP 4xx (401 / 403 / 404 など) は設定の誤りです。URL と認証ヘッダを確かめてください。")
                Para("リダイレクト (3xx) には付いていきません。転送先の URL を直接登録してください。")
            }
            Section("よく出るメッセージ") {
                Code("https の URL だけ使えます", "http:// の URL は登録できません")
                Code("本文が JSON になりません", "本文のテンプレートの {} や \"\" を確かめる")
                Code("設定を読み込めませんでした", "時計・iPhone のロックを解除してからもう一度")
                Code("送り先がありません", "iPhone で送り先を登録する")
            }
        }
    }
}

private struct ReceiverSpecPage: View {
    var body: some View {
        HelpPage(title: "受け取る側の仕様") {
            Section("ヘッダ") {
                Code("Content-Type", "本文の形式に合わせて application/json など")
                Code("User-Agent", "WatchHook/1")
                Code("X-WatchHook-Message-Id", "メッセージごとの ID。送り直しても同じなので重複の除去に使える")
            }
            Section("応答の扱い") {
                Code("2xx", "届いた")
                Code("408 / 429 / 5xx", "あとで送り直す")
                Code("それ以外", "失敗 (送り直さない)")
                Para("20 秒で応答が無ければ時間切れとして送り直します。")
            }
        }
    }
}

private struct PrivacyPage: View {
    var body: some View {
        HelpPage(title: "データの扱い") {
            Section {
                Para("話した内容は、あなたが登録した送り先へ直接送ります。開発者のサーバーは通りません。")
                Para("送り先の URL と認証ヘッダは、iPhone と Apple Watch の Keychain にだけ保存します。")
                Para("履歴は端末の中にだけ、新しいものから 50 件ほど残します (送り直し待ちのものは消しません)。")
            }
        }
    }
}

// MARK: - 部品

private struct HelpPage<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        List { content.listRowBackground(Cosmos.card) }
            .navigationTitle(title)
            .cosmicListBackground()
            .navigationBarTitleDisplayMode(.inline)
    }
}

private struct Step: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("\(number)")
                .font(.caption.bold())
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(Circle().fill(.orange))
            Text(text)
        }
    }
}

private struct Para: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text).fixedSize(horizontal: false, vertical: true)
    }
}

private struct Code: View {
    let code: String
    let meaning: String
    init(_ code: String, _ meaning: String) {
        self.code = code
        self.meaning = meaning
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(code).font(.system(.callout, design: .monospaced))
            Text(meaning).font(.caption).foregroundStyle(.secondary)
        }
    }
}
