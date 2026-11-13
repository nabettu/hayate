<p align="center"><img src="design/app-icon.svg" width="128" alt="Hayate のアイコン"></p>

# Hayate (はやて)

[English](#english) · [MIT License](LICENSE) · [プライバシー](PRIVACY.md) · [GitHub Sponsors で応援する](https://github.com/sponsors/nabettu)

Apple Watch で話した内容をメモとして保存し、リマインダー・Markdown ファイル・登録した webhook (Slack・Discord・自分の API など) へ送る iPhone / Apple Watch のアプリ。**無料・広告なし・計測なし・開発者のサーバーなし**。

> 状態: 未リリース (TestFlight で試しているところ)。App Store に出したらここにリンクを置きます。

## できること

- **起動**: 「Hey Siri、はやてで送って」→ 続けて話す (手を使わない)。またはアプリを開いてダブルタップ (Series 9 / Ultra 2 以降)・文字盤のコンプリケーションから
- **メモ**: 入力はまず端末に保存する (送れなくても残る)。iPhone が全件を持ち、時計は直近 50 件。iPhone で閲覧・コピー・共有・削除、後から webhook へ送れる
- **webhook**: iPhone でオンにした送り先すべてへ、時計から直接送る (iPhone を中継しない)。送れなければ溜めて、次に開いたとき送り直す
- **リマインダー**: 「リマインダー、牛乳を買う」のように合図の言葉 (44 言語に既定あり・追加できる) で始めると、iPhone がリマインダーに追加する
- **Markdown**: iPhone で選んだフォルダ (iCloud Drive の Obsidian の保管庫など) の `YYYY-MM-DD.md` に追記する
- **送り先の設定**: URL・メソッド・ヘッダ (Authorization など)・本文テンプレート。Slack・Discord・Google Chat・Teams・Telegram・ntfy・Notion・Todoist・Home Assistant・n8n・IFTTT のひな形あり。Keychain に保存し、WatchConnectivity で時計へ同期
- **言語**: 日本語 + 44 言語 (機械翻訳。直してもらえると助かります)

仕様と決めたことは [docs/FREE_OSS.md](docs/FREE_OSS.md)、設計は [docs/DESIGN.md](docs/DESIGN.md)、予定は [ROADMAP.md](ROADMAP.md)。
アプリ名は Hayate、コード・ターゲット・Bundle ID・`X-WatchHook-*` ヘッダなど内部の名前は開発名の WatchHook のまま ([docs/NAMING.md](docs/NAMING.md))。

## 受け取る側の仕様

- `Content-Type` は本文の形式 (JSON / フォーム / テキスト) に合わせて付く
- `X-WatchHook-Message-Id`: メモごとの UUID。**再送しても同じ値**なので重複除去に使える (同じメモを複数の送り先へ送るときも同じ)
- `User-Agent: WatchHook/1`
- 2xx を成功、408 / 429 / 5xx / 通信エラーを再送対象 (最大 5 回)、それ以外の 4xx を失敗として扱う
- 本文テンプレートの差し込み: `{{text}}` `{{id}}` `{{sentAt}}` (ISO8601 UTC) `{{source}}` (`watch` / `phone` / `siri-watch` / `siri-phone` / `test`)

## 自分でビルドする

必要なもの: Xcode (作者は Xcode 27 で開発。Swift 6)、iOS 18 / watchOS 11 以降の端末。依存は Apple のフレームワークだけ。

```bash
brew install xcodegen          # project.yml を変えるときだけ要る (.xcodeproj もコミットしてある)
open WatchHook.xcodeproj
```

自分の端末に入れるときは、`project.yml` の `DEVELOPMENT_TEAM` を自分のチームに、`com.nabettu.watchhook` で始まる Bundle ID (iPhone・Watch・ウィジェットの 3 つ) を自分のものに変えて `xcodegen generate` する。
Keychain を使うので、署名なしのシミュレータ用ビルド (`CODE_SIGNING_ALLOWED=NO`) では送り先を保存できない。

```bash
scripts/verify.sh              # Core の単体テスト (macOS で swift test)
scripts/verify.sh --full       # + プロジェクトの一致確認 + iOS / watchOS ビルド
scripts/render-app-icon.sh     # design/app-icon.svg を変えたら (AppIcon.png を作り直す)
(cd scripts/gen-screenshots && npm ci && node index.mjs)  # App Store のスクショ (scripts/gen-screenshots/README.md)
```

## 構成

| パス | 中身 |
|---|---|
| `Packages/WatchHookCore` | 送り先のモデルとひな形・本文テンプレート・リクエストの組み立てと検証・送信結果の分類・メモと連携ごとの状態 (`MemoLog`)・リマインダーの合図・Markdown の追記。プラットフォームに依存しない (macOS で `swift test`) |
| `Shared/` | iPhone と時計の両方に入るもの: Keychain・設定ストア・メモの保存と連携の送信 (`MemoDispatcher`)・App Intent / Siri のフレーズ・見た目の部品 (`Cosmos.swift`) |
| `WatchHook/` | iPhone アプリ (メモの入力・一覧と詳細・連携の設定・テスト送信・時計との同期・使い方 `HelpView.swift`) |
| `WatchHookWatch/` | watchOS アプリ (メモのボタン = 音声入力・手書き・キーボード、メモの一覧、iPhone との同期) |
| `WatchHookWidget/` | watchOS のウィジェット (コンプリケーション・スマートスタック)。タップで Hayate を開く |
| `store/metadata/` / `scripts/gen-screenshots/` / `scripts/l10n/` | App Store の文言・スクショの生成・翻訳の手順 |
| `project.yml` | XcodeGen の定義。`WatchHook.xcodeproj` はここから作る |

## 貢献

Issue・PR を歓迎します (日本語でも英語でも)。

- ロジックは `Packages/WatchHookCore` にテスト (Swift Testing) と一緒に書き、`scripts/verify.sh` を通す
- 送り先の設定 (URL・認証ヘッダ) は Keychain の外 (UserDefaults・ファイル・ログ) に出さない
- 新しい依存は足さない方針。どうしても要るときは Issue で相談してください
- 文言を足したら `Shared/Localizable.xcstrings` に入る。訳は [scripts/l10n/README.md](scripts/l10n/README.md)
- 開発のルールとハマりどころは [CLAUDE.md](CLAUDE.md) (AI エージェント向けに書いているが、人が読んでも同じ)

不具合・要望は [Issues](https://github.com/nabettu/hayate/issues) へ。セキュリティの問題は公開の Issue ではなく [GitHub の非公開の報告](https://github.com/nabettu/hayate/security/advisories/new) でお願いします。

## 作者

[nabettu](https://github.com/nabettu)。気に入ったら [GitHub Sponsors](https://github.com/sponsors/nabettu) で応援してください (アプリの機能は変わりません)。

---

## English

**Hayate** is an iPhone / Apple Watch app that saves what you say to your watch as a memo, then sends it to Reminders, a Markdown file, and the webhooks you registered (Slack, Discord, your own API, …). Free, no ads, no analytics, no server of ours in between. MIT License.

> Status: not released yet (in TestFlight testing).

- **Start**: "Hey Siri, send with Hayate" and speak, or open the app and double tap (Series 9 / Ultra 2 or later), or tap the complication.
- **Memos**: every input is saved on the device first, so nothing is lost when sending fails. The iPhone keeps all memos; the watch keeps the latest 50.
- **Webhooks**: sent directly from the watch to every destination you turned on in the iPhone app (presets for Slack, Discord, Google Chat, Teams, Telegram, ntfy, Notion, Todoist, Home Assistant, n8n and IFTTT). Failed sends are retried the next time you open the app.
- **Reminders**: start a memo with a trigger word (defaults for 44 languages, editable), e.g. "Reminder, buy milk", and the iPhone adds "buy milk" to Reminders.
- **Markdown**: the iPhone appends each memo to `YYYY-MM-DD.md` in a folder you choose (e.g. an Obsidian vault in iCloud Drive).
- **Privacy**: destination URLs and auth headers stay in the Keychain of your iPhone and watch. See [PRIVACY.md](PRIVACY.md).

**Receiver spec**: `X-WatchHook-Message-Id` (a UUID per memo, the same on retries), `User-Agent: WatchHook/1`, 2xx = delivered, 408 / 429 / 5xx / network errors = retried (up to 5 times), other 4xx = failed. Body template placeholders: `{{text}}` `{{id}}` `{{sentAt}}` `{{source}}`.

**Build**: Xcode (developed with Xcode 27, Swift 6), iOS 18 / watchOS 11+. Open `WatchHook.xcodeproj`. To run on your devices, change `DEVELOPMENT_TEAM` and the `com.nabettu.watchhook*` bundle IDs in `project.yml`, then `xcodegen generate`. Tests: `scripts/verify.sh` (`--full` also builds the apps).

**Contributing**: issues and PRs are welcome, in English or Japanese. Docs and code comments are mostly in Japanese. Please report security issues privately via [GitHub security advisories](https://github.com/nabettu/hayate/security/advisories/new).

Made by [nabettu](https://github.com/nabettu). If you like it, you can support the work via [GitHub Sponsors](https://github.com/sponsors/nabettu).
