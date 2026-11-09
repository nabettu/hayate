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

- iPhone で編集 → Keychain (`AfterFirstUnlockThisDeviceOnly`。Siri から裏で読めるように) に保存できたときだけ反映
- **`applicationContext` には版 (`revision` + `epoch`) だけを置く**。applicationContext は端末に保存され続けるので、認証ヘッダを含む本体を入れると「秘密は Keychain だけ」が崩れる (2026-11-09 ai-review の指摘)
- 時計は版が手元より新しければ `sendMessage` で本体を取りに行き、返信で受け取って時計の Keychain に保存する。iPhone に届かないときは、前面に来たとき・つながったときに取り直す
- 版は保存のたびに 1 増える整数。**日時で比べない** (端末の時刻が戻ると以後の更新を全部古いと判定して同期が止まる)。iPhone でアプリを入れ直すと版が 0 からになるので、`epoch` (設定を作り直したときに変わる UUID) が違えば受け入れる
- Keychain が読めない (ロック中など) ときと「設定が無い」ときを区別する。読めないまま保存すると本物の設定を空で上書きするので、保存を止めて画面に出す。再送も「送り先が消えた」と決めつけず次の機会に回す
- 履歴 (本文を含む) はアプリのファイルに `completeUntilFirstUserAuthentication` で保存。サーバーには何も送らない (自前のサーバーは無い)

## 再送

- 送信中の ID を持って二重送信を防ぐ (actor でも await の間は割り込まれる)。再送は 1 件ずつ、送る直前の履歴と設定を読み直す。結果は 1 件ごとに保存する
- リダイレクトには従わない。従うと POST が GET に変わり、ログイン画面などの 200 を「届いた」と誤認する
- 受け手の重複除去用に `X-WatchHook-Message-Id` は予約ヘッダ (利用者の設定で上書きできない)

## 他社の AI アプリへの連携

ChatGPT / Claude / Gemini のアプリの会話に外から書き込む公開の口は無いので、アプリ連携はしない。代わりの候補 (ROADMAP):
各社 API に直接送る (ユーザーの API キー)、Shortcuts の「ChatGPT に尋ねる」等にテキストを渡す、n8n / Zapier / Dify の webhook 経由。

### 「時計から各社 AI アプリのチャットを始める」の調査 (2026-11-10)

結論: **時計の上だけでは無理。iPhone 側でアプリを開かせる 1 手 (通知のタップ等) が要る**。API に送った会話は各社アプリの履歴に出ない (API と消費者向けアプリは別)。

- watchOS のアプリから他社アプリ・任意の URL は開けない (`openURL` / 旧 `openSystemURL` は `tel:` `sms:` 等のシステムのものだけ)。各社とも公式の watchOS アプリは無い
- 時計のショートカットからも、iPhone アプリだけが持つ App Intent (「ChatGPT に尋ねる」等) は動かない
- iPhone のアプリも裏からは他のアプリを開けない (`UIApplication.open` は前面のときだけ)。WatchConnectivity で iPhone に渡しても、前面に出す手段が無い
- プロンプト付きで新しいチャットを開くリンク (iPhone で開く前提。✅ は公式の記載あり、他は agy の検索結果のみで**実機未検証**):

| アプリ | リンク | 備考 |
|---|---|---|
| Claude | ✅ `claude://new?q=` / `https://claude.ai/new?q=` | 入力欄に入るだけ (送信はしない) |
| Perplexity | `perplexity-app://search?q=` / `https://www.perplexity.ai/search?q=` | すぐ検索が始まるとの情報 |
| ChatGPT | `https://chatgpt.com/?q=` | Safari では効くが、アプリで開くと `q` が捨てられるとの情報。ショートカットの「ChatGPT に尋ねる」なら履歴に残るとの情報 |
| Grok / Copilot | `https://grok.com/?q=` / `https://copilot.microsoft.com/?q=` | アプリで効くかは未確認 |
| Gemini | なし (`googlegemini://` で開くだけ) | プロンプトを渡す口が無い |

- 実現するなら: 時計 → (WatchHook の webhook で ntfy / Pushcut 等、または自前の APNs) → iPhone に通知 → タップで上のリンクを開く。
  本文テンプレートに **URL 用のエスケープ** (今は `.form` の本文全体にしか効かない) が要る。**2026-11-10 にいったん見送り** (ユーザー判断)。やるなら実機でリンクの効き方を確かめてから
