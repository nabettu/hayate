# 設計判断 (2026-11-09)

## 起動方法: Siri を主、ダブルタップを補助

調べた結果 (2026-11 時点・watchOS 11〜27):

| 方法 | 手を使わない | サードパーティアプリで使えるか |
|---|---|---|
| Siri + App Intent (`SendTextIntent`) | ◎ | ◎ 「Hey Siri、WatchHook で送って」→ Siri が `requestValueDialog` でテキストを聞き取る。画面は開かない (`openAppWhenRun = false`) |
| ダブルタップ (`.handGestureShortcut(.primaryAction)`) | ○ | △ **アプリの画面を開いているときだけ**。文字盤からアプリを起動するのには使えない |
| Ultra のアクションボタン | × (押す) | ◎ ショートカット / アプリを割り当てられる |
| AssistiveTouch (手を握る) | ○ | 未検証。アクセシビリティ機能なので一般の利用者向けの案内にはしにくい |

「ジェスチャーだけで起動」は OS の制約で完全にはできない。Siri を主にした。

## 音声 → テキスト: OS の音声入力

- Siri 経由: Siri の聞き取り結果が App Intent の `String` パラメータに入る
- アプリ内: `TextFieldLink` (標準の入力画面。音声入力・スクリブル)。**アプリから音声入力を自動で始める公開 API は無い**ので、ボタン (またはダブルタップ) を押す 1 手が要る
- 自前の録音 + 文字起こし (Speech / サーバー) はしない。watchOS に Speech フレームワークが無く、録音を iPhone / サーバーへ送る経路が増えるため

## 送信: 時計から直接

- iPhone を中継すると、iPhone アプリが落ちている / 起こせないときに止まる。時計は iPhone 経由・Wi-Fi・LTE のどれでも `URLSession` で外へ出られるので、時計から直接 POST する
- 失敗は `MessageLog` に再送待ちとして残し、アプリが前面に来たとき・次に送れたときにまとめて送る (最大 5 回)。バックグラウンドでの自動再送 (`BGTask` 等) は未実装
- 重複を受け手で除けるよう、メッセージ ID を `X-WatchHook-Message-Id` で毎回同じ値で送る

## 設定の同期と秘密

- iPhone で編集 → Keychain (`AfterFirstUnlockThisDeviceOnly`。Siri から裏で読めるように) → `WCSession.updateApplicationContext` で時計へ → 時計の Keychain
- 時計に設定が無いとき (初回) は `sendMessage` で iPhone に取りに行く
- 履歴 (本文を含む) はアプリのファイルに `completeUntilFirstUserAuthentication` で保存。サーバーには何も送らない (自前のサーバーは無い)

## 他社の AI アプリへの連携

ChatGPT / Claude / Gemini のアプリの会話に外から書き込む公開の口は無いので、アプリ連携はしない。代わりの候補 (ROADMAP):
各社 API に直接送る (ユーザーの API キー)、Shortcuts の「ChatGPT に尋ねる」等にテキストを渡す、n8n / Zapier / Dify の webhook 経由。
