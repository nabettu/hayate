# Hayate (はやて。開発名: WatchHook)

[English](#english) · MIT License · [GitHub Sponsors で応援する](https://github.com/sponsors/nabettu)

アプリ名は **Hayate** (2026-11-10 決定。経緯は [docs/NAMING.md](docs/NAMING.md))。コード・ターゲット・Bundle ID・`X-WatchHook-*` ヘッダなどの内部の名前は WatchHook のまま。

Apple Watch で話した内容をメモとして保存し、リマインダー・Markdown ファイル・登録した webhook (Slack・Discord・自分の API など) へ送るアプリ。無料・広告なし・計測なし。

- **起動**: 「Hey Siri、はやてで送って」→ 続けて話す (手を使わない)。またはアプリを開いてダブルタップ (Series 9 / Ultra 2 以降)
- **音声 → テキスト**: OS の音声入力 (Siri の聞き取り / watchOS の入力画面) をそのまま使う
- **メモ**: 入力はまず端末に保存する (送れなくても残る)。メモの正は iPhone (全件)、時計は直近 50 件
- **webhook**: iPhone でオンにした送り先すべてへ、時計から直接送る。iPhone のアプリが閉じていても届く。送れなければ溜めて次に開いたとき送り直す
- **リマインダー**: 「リマインダー、牛乳を買う」のように合図の言葉 (44 言語に既定あり・追加可) で始めると、iPhone がリマインダーに追加する
- **Markdown**: iPhone で選んだフォルダ (iCloud Drive の Obsidian の保管庫など) の `YYYY-MM-DD.md` に追記する
- **送り先の設定**: iPhone アプリで登録 (URL・メソッド・ヘッダ (Authorization など)・本文テンプレート。Slack・Discord・Google Chat・Teams・Telegram・ntfy・Notion・Todoist・Home Assistant・n8n・IFTTT のひな形あり)。Keychain に保存し、WatchConnectivity で時計へ同期

仕様と決めたことは [docs/FREE_OSS.md](docs/FREE_OSS.md)、設計は [docs/DESIGN.md](docs/DESIGN.md)。

## 構成

| パス | 中身 |
|---|---|
| `Packages/WatchHookCore` | 送り先のモデルとひな形・本文テンプレート・リクエストの組み立てと検証・送信結果の分類・メモと連携ごとの状態 (`MemoLog`)・リマインダーの合図・Markdown の追記。プラットフォームに依存しない (macOS で `swift test`) |
| `Shared/` | iPhone と時計の両方に入るもの: Keychain・設定ストア・メモの保存と連携の送信 (`MemoDispatcher`)・App Intent / Siri のフレーズ・見た目の部品 (`Cosmos.swift`: 配色・星空・紙飛行機と飛ぶ演出) |
| `WatchHook/` | iPhone アプリ (メモの入力・メモの一覧と詳細・連携 (送り先・リマインダー・Markdown) の設定・テスト送信・時計との同期・使い方のマニュアル `HelpView.swift`) |
| `WatchHookWatch/` | watchOS アプリ (メモのボタン = 音声入力・手書き・キーボード・メモの一覧・iPhone との同期) |
| `WatchHookWidget/` | watchOS のウィジェット (文字盤のコンプリケーション・スマートスタック)。タップで WatchHook を開くだけの固定表示。見た目は `LauncherViews.swift` (Watch アプリの DEBUG ビルドの見本 `-widgetGallery 1\|2\|3` でも使う) |
| `project.yml` | XcodeGen の定義。`WatchHook.xcodeproj` はここから作る (コミットしてある) |

## 開発

```bash
brew install xcodegen          # 初回のみ
xcodegen generate              # project.yml を変えたら
scripts/verify.sh              # Core の単体テスト
scripts/verify.sh --full       # + プロジェクトの一致確認 + iOS / watchOS ビルド
scripts/render-app-icon.sh     # design/app-icon.svg を変えたら (iPhone / Watch の AppIcon.png を作り直す)
(cd scripts/gen-screenshots && npm ci && node index.mjs)  # App Store のスクショ (scripts/gen-screenshots/README.md)
```

アプリアイコンの元は `design/app-icon.svg` (星空を飛ぶ紙飛行機。PC のカーソルに見えないよう、奥の翼・竜骨・折り目の面を描いている)。
`AppIcon.png` はビルドの入力なのでコミットしている。SVG を変えたら作り直して両方コミットする。

## 受け取る側の仕様

- `Content-Type` は本文の形式 (JSON / フォーム / テキスト) に合わせて付く
- `X-WatchHook-Message-Id`: メモごとの UUID。**再送しても同じ値**なので重複除去に使える (同じメモを複数の送り先へ送るときも同じ)
- `User-Agent: WatchHook/1`
- 2xx を成功、408 / 429 / 5xx / 通信エラーを再送対象 (最大 5 回)、それ以外の 4xx を失敗として扱う
- 本文テンプレートの差し込み: `{{text}}` `{{id}}` `{{sentAt}}` (ISO8601 UTC) `{{source}}` (`watch` / `phone` / `siri-watch` / `siri-phone` / `test`)

## 作者

[nabettu](https://github.com/nabettu)。気に入ったら [GitHub Sponsors](https://github.com/sponsors/nabettu) で応援してください (アプリの機能は変わりません)。

---

## English

**Hayate** saves what you say to your Apple Watch as a memo, then sends it to Reminders, a Markdown file, and the webhooks you registered (Slack, Discord, your own API, …). Free, no ads, no analytics. MIT License.

- **Start**: "Hey Siri, send with Hayate" and speak, or open the app and double tap (Series 9 / Ultra 2 or later).
- **Memos**: every input is saved on the device first, so nothing is lost when sending fails. The iPhone keeps all memos; the watch keeps the latest 50.
- **Webhooks**: sent directly from the watch to every destination you turned on in the iPhone app (presets for Slack, Discord, Google Chat, Teams, Telegram, ntfy, Notion, Todoist, Home Assistant, n8n and IFTTT). Failed sends are retried.
- **Reminders**: start a memo with a trigger word (defaults for 44 languages, editable), e.g. "Reminder, buy milk", and the iPhone adds "buy milk" to Reminders.
- **Markdown**: the iPhone appends each memo to `YYYY-MM-DD.md` in a folder you choose (e.g. an Obsidian vault in iCloud Drive).
- **Privacy**: destination URLs and auth headers stay in the Keychain of your iPhone and watch. There is no server of ours in between.

Build: `brew install xcodegen && xcodegen generate`, then open `WatchHook.xcodeproj`. Tests: `scripts/verify.sh` (`--full` also builds the apps).
Receiver spec: `X-WatchHook-Message-Id` (the same UUID on retries), `User-Agent: WatchHook/1`, 2xx = delivered, 408 / 429 / 5xx = retried (up to 5 times).

Made by [nabettu](https://github.com/nabettu). If you like it, you can support the work via [GitHub Sponsors](https://github.com/sponsors/nabettu).
