import SwiftUI

/// アプリ内のマニュアル。目次 → 各ページ。
struct HelpView: View {
    var body: some View {
        NavigationStack {
            List {
                Group {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Apple Watch で話した内容をメモに保存し、リマインダー・Markdown ファイル・登録した webhook (Slack・Discord など) へ送るアプリです。無料で、広告もありません。")
                            Text("はじめに").font(.headline).padding(.top, 4)
                            Step(number: 1, text: "「連携」タブでリマインダー・Markdown・送り先を選ぶ (選ばなくてもメモは残ります)")
                            Step(number: 2, text: "送り先は編集画面の「テスト送信」で届くか確かめる")
                            Step(number: 3, text: "Apple Watch で「Hey Siri、はやてで送って」と話しかける")
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
                        NavigationLink { MemoPage() } label: {
                            Label("メモの一覧・後から送る", systemImage: "note.text")
                        }
                        NavigationLink { ReminderPage() } label: {
                            Label("リマインダーに追加する", systemImage: "checklist")
                        }
                        NavigationLink { MarkdownPage() } label: {
                            Label("Markdown ファイルに追記する", systemImage: "doc.text")
                        }
                        NavigationLink { ChooseDestinationPage() } label: {
                            Label("送り先を選ぶ", systemImage: "paperplane")
                        }
                    }

                    Section("送り先の登録") {
                        NavigationLink { SlackPage() } label: {
                            Label("Slack", systemImage: "number")
                        }
                        NavigationLink { DiscordPage() } label: {
                            Label("Discord", systemImage: "bubble.left.and.bubble.right")
                        }
                        NavigationLink { OtherServicesPage() } label: {
                            Label("ほかのサービス", systemImage: "square.grid.2x2")
                        }
                        NavigationLink { CustomWebhookPage() } label: {
                            Label("Webhook (自由に設定)", systemImage: "curlybraces")
                        }
                    }

                    Section("Hayate について") {
                        NavigationLink { AboutPage() } label: {
                            Label("ソースコード・応援", systemImage: "heart")
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
                Para("「Hey Siri、はやてで送って」と話しかけ、「何を送りますか？」と聞かれたら送りたい内容を話します。")
                Para("「はやてで送る」「はやてに送って」でも動きます。話した内容はメモに保存し、iPhone で有効にした送り先へ送ります。")
                Para("iPhone の Siri でも同じように送れます。")
            }
            Section("アプリから送る") {
                Para("時計で Hayate を開き、紫の「メモ」を押して、話すか文字を入力します。終えたら「完了」で保存します。")
                Para("Series 9 / Ultra 2 以降は、親指と人差し指をダブルタップしても「メモ」を押せます。")
                Para("保存して送れたら時計が振動し、「保存して送りました」と出ます。")
                Para("デジタルクラウンを回すか下へスクロールすると、直近 50 件のメモと送った結果を見られます。")
            }
            Section("届き方") {
                Para("webhook は時計から送り先へ直接送ります。iPhone のアプリを開いていなくても、時計が Wi-Fi・モバイル通信・iPhone 経由のどれかでつながっていれば届きます。")
                Para("メモは iPhone にも渡します。リマインダー・Markdown への保存は、iPhone が受け取ったときに iPhone で行います。")
            }
        }
    }
}

private struct WidgetPage: View {
    var body: some View {
        HelpPage(title: "文字盤・スマートスタックに置く") {
            Section("文字盤のコンプリケーション") {
                Para("時計の文字盤を長押し →「編集」→ コンプリケーションの枠を選び、一覧の「Hayate」から形を選びます。")
                Para("タップすると Hayate が開き、すぐ「メモ」を押せます。")
            }
            Section("スマートスタック") {
                Para("文字盤でデジタルクラウンを回す (または下からスワイプ) とスマートスタックが出ます。どれかのウィジェットを長押しして編集の状態にし、上の + から「Hayate」を選んで足します。")
            }
            Section("iPhone の Watch アプリから") {
                Para("iPhone の「Watch」アプリ →「マイウォッチ」の文字盤 → コンプリケーションでも設定できます。")
            }
        }
    }
}

private struct ChooseDestinationPage: View {
    var body: some View {
        HelpPage(title: "送り先を選ぶ") {
            Section("有効にした送り先すべてへ送る") {
                Para("「連携」タブで、送り先ごとのスイッチをオンにしたものすべてへ送ります。時計で送り先を選ぶ画面はありません。")
                Para("どれもオンにしていなければ、メモとして保存するだけです。あとから iPhone のメモの一覧で送れます。")
            }
            Section("前後に付ける文") {
                Para("送り先の編集画面の「前後に付ける文」に書いた文を、話した内容の前後に付けて送ります。例: 前に「#買い物 」と書くと、「牛乳」と話せば「#買い物 牛乳」と届きます。")
            }
            Section("設定が時計に届かないとき") {
                Para("送り先は iPhone から時計へ自動で送られます。時計に出てこないときは、iPhone と時計の両方で Hayate を開いてください。")
            }
        }
    }
}

private struct MemoPage: View {
    var body: some View {
        HelpPage(title: "メモの一覧・後から送る") {
            Section("メモの一覧") {
                Para("iPhone の「メモ」タブに、iPhone と Apple Watch で入力したメモがすべて残ります。Apple Watch には直近 50 件を残します。")
                Para("メモを開くと、送り先・リマインダー・Markdown ごとに送れたかどうかが分かります。送れなかったものは「送り直す」で送れます。")
            }
            Section("後から送る・共有・削除") {
                Para("メモを開いて「送り先へ送る」から、登録してある送り先を選んで送れます (有効にしていない送り先にも送れます)。")
                Para("「コピー」「共有」で、ほかのアプリにも渡せます。")
                Para("削除すると、まだ送っていない分は送るのをやめます。送り終えたもの・作ったリマインダーは消えません。")
            }
        }
    }
}

private struct ReminderPage: View {
    var body: some View {
        HelpPage(title: "リマインダーに追加する") {
            Section("合図の言葉で始める") {
                Para("「リマインダー、牛乳を買う」のように合図の言葉で始めると、合図を除いた「牛乳を買う」をリマインダーに追加します。")
                Para("合図の言葉は使う言語ごとにいくつか用意してあり、「連携」タブ →「リマインダー」で足したり消したりできます。")
                Para("合図だけで本文が無いときは、メモにだけ残します。")
            }
            Section("はじめに") {
                Para("「連携」タブ →「リマインダー」でオンにし、リマインダーへのアクセスを許可して、追加するリストを選びます。")
                Para("Apple Watch で入力したメモも、iPhone が受け取ったときに iPhone で追加します。")
            }
        }
    }
}

private struct MarkdownPage: View {
    var body: some View {
        HelpPage(title: "Markdown ファイルに追記する") {
            Section {
                Para("「連携」タブ →「Markdown」でフォルダを選ぶと、すべてのメモを日付ごとのファイル (例: 2026-11-13.md) に「- 10:15 内容」の形で追記します。")
                Para("iCloud Drive の中の Obsidian の保管庫などを選べます。Apple Watch のメモも、iPhone が受け取ったときに追記します。")
            }
        }
    }
}

private struct OtherServicesPage: View {
    var body: some View {
        HelpPage(title: "ほかのサービス") {
            Section("ひな形から登録する") {
                Para("「連携」タブの + から、Google Chat・Microsoft Teams・Telegram・ntfy・Notion・Todoist・Home Assistant・n8n・IFTTT のひな形を選べます。")
                Para("URL・ヘッダ・本文の <TOKEN> のような <…> の部分を、自分の値に書き換えてから保存してください。")
            }
        }
    }
}

private struct AboutPage: View {
    var body: some View {
        HelpPage(title: "ソースコード・応援") {
            Section {
                Para("Hayate は無料のオープンソース (MIT ライセンス) です。")
                Link("ソースコード (GitHub)", destination: URL(string: "https://github.com/nabettu/hayate")!)
                Link("GitHub Sponsors で応援する", destination: URL(string: "https://github.com/sponsors/nabettu")!)
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
                Para("「連携」タブの + →「Slack」を選び、URL を貼って保存します。本文などは自動で設定されます。")
                Para("保存の前に「テスト送信」で、チャンネルに「Hayate のテスト送信です」と出るか確かめてください。")
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
                Para("「連携」タブの + →「Discord」を選び、URL を貼って保存します。本文などは自動で設定されます。")
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
                Para("メモを開くと状態を見られ、「送り直す」で送れます。Apple Watch から送る分は時計のメモから、iPhone から送る分は iPhone のメモから送り直します。")
            }
            Section("送り直しても届かないもの") {
                Para("HTTP 4xx (401 / 403 / 404 など) は設定の誤りです。URL と認証ヘッダを確かめてください。")
                Para("リダイレクト (3xx) には付いていきません。転送先の URL を直接登録してください。")
            }
            Section("よく出るメッセージ") {
                Code("https の URL だけ使えます", "http:// の URL は登録できません")
                Code("本文が JSON になりません", "本文のテンプレートの {} や \"\" を確かめる")
                Code("設定を読み込めませんでした", "時計・iPhone のロックを解除してからもう一度")
                Code("送り先が無効になっています", "「連携」タブで送り先をオンにしてから送り直す")
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
                Para("話した内容は、あなたが登録した送り先へ直接送ります。開発者のサーバーは通りません。利用状況の計測もしていません。")
                Para("送り先の URL と認証ヘッダは、iPhone と Apple Watch の Keychain にだけ保存します。")
                Para("メモは iPhone と Apple Watch の中にだけ保存します (iCloud には送りません)。Apple Watch には直近 50 件を残し、iPhone にはすべて残します。")
            }
        }
    }
}

// MARK: - 部品

private struct HelpPage<Content: View>: View {
    let title: LocalizedStringKey
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
    let text: LocalizedStringKey

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("\(number)")
                .font(.caption.bold())
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(Circle().fill(Cosmos.glow))
            Text(text)
        }
    }
}

private struct Para: View {
    let text: LocalizedStringKey
    init(_ text: LocalizedStringKey) { self.text = text }

    var body: some View {
        Text(text).fixedSize(horizontal: false, vertical: true)
    }
}

private struct Code: View {
    let code: LocalizedStringKey
    let meaning: LocalizedStringKey
    init(_ code: LocalizedStringKey, _ meaning: LocalizedStringKey) {
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
