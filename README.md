# Hayate (はやて。開発名: WatchHook)

アプリ名は **Hayate** (2026-11-10 決定。経緯は [docs/NAMING.md](docs/NAMING.md))。コード・ターゲット・Bundle ID・`X-WatchHook-*` ヘッダなどの内部の名前は WatchHook のまま。

Apple Watch で話した内容を、登録した webhook (自社の受け口・Slack・Discord など) へそのまま送るアプリ。

- **起動**: 「Hey Siri、はやてで送って」→ 続けて話す (手を使わない)。またはアプリを開いてダブルタップ (Series 9 / Ultra 2 以降)
- **音声 → テキスト**: OS の音声入力 (Siri の聞き取り / watchOS の入力画面) をそのまま使う
- **送信**: 時計から送り先へ直接 POST する。iPhone のアプリが閉じていても届く。送れなければ溜めて次に開いたとき送り直す
- **送り先の設定**: iPhone アプリで登録 (URL・メソッド・ヘッダ (Authorization など)・本文テンプレート)。Keychain に保存し、WatchConnectivity で時計へ同期

## 構成

| パス | 中身 |
|---|---|
| `Packages/WatchHookCore` | 送り先のモデル・本文テンプレート・リクエストの組み立てと検証・送信結果の分類・履歴 / 再送待ち。プラットフォームに依存しない (macOS で `swift test`) |
| `Shared/` | iPhone と時計の両方に入るもの: Keychain・設定ストア・送信 (`MessageDispatcher`)・App Intent / Siri のフレーズ・見た目の部品 (`Cosmos.swift`: 配色・星空・紙飛行機と飛ぶ演出) |
| `WatchHook/` | iPhone アプリ (テキストを入力して送る `ComposeView.swift`・送り先の編集・テスト送信・履歴・時計への同期・使い方のマニュアル `HelpView.swift`) |
| `WatchHookWatch/` | watchOS アプリ (話すボタン・送り先の選択・履歴・iPhone からの設定の受け取り) |
| `WatchHookWidget/` | watchOS のウィジェット (文字盤のコンプリケーション・スマートスタック)。タップで WatchHook を開くだけの固定表示。見た目は `LauncherViews.swift` (Watch アプリの DEBUG ビルドの見本 `-widgetGallery 1\|2\|3` でも使う) |
| `StoreKit/WatchHook.storekit` | Xcode から実行したときの課金商品 (7 日間お試し・買い切り)。`docs/BILLING.md` |
| `project.yml` | XcodeGen の定義。`WatchHook.xcodeproj` はここから作る (コミットしてある) |

## 開発

```bash
brew install xcodegen          # 初回のみ
xcodegen generate              # project.yml を変えたら
scripts/verify.sh              # Core の単体テスト
scripts/verify.sh --full       # + プロジェクトの一致確認 + iOS / watchOS ビルド
scripts/render-app-icon.sh     # design/app-icon.svg を変えたら (iPhone / Watch の AppIcon.png を作り直す)
```

アプリアイコンの元は `design/app-icon.svg` (星空を飛ぶ紙飛行機。PC のカーソルに見えないよう、奥の翼・竜骨・折り目の面を描いている)。
`AppIcon.png` はビルドの入力なのでコミットしている。SVG を変えたら作り直して両方コミットする。

## 受け取る側の仕様

- `Content-Type` は本文の形式 (JSON / フォーム / テキスト) に合わせて付く
- `X-WatchHook-Message-Id`: メッセージごとの UUID。**再送しても同じ値**なので重複除去に使える
- `User-Agent: WatchHook/1`
- 2xx を成功、408 / 429 / 5xx / 通信エラーを再送対象 (最大 5 回)、それ以外の 4xx を失敗として扱う
- 本文テンプレートの差し込み: `{{text}}` `{{id}}` `{{sentAt}}` (ISO8601 UTC) `{{source}}` (`watch` / `phone` / `siri-watch` / `siri-phone` / `test`)
