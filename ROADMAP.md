# ROADMAP

## 現状 (2026-11-09)

MVP の土台を作った (未リリース・シミュレータでのみ確認)。
- 送り先: 任意の webhook (メソッド・ヘッダ・本文テンプレート)、Slack / Discord の定型
- Siri (時計 / iPhone) から送る App Intent、時計のアプリ (話すボタン + ダブルタップ)
- 送信失敗の再送待ち・履歴、iPhone → 時計の設定同期

## 次にやること

- [ ] 実機 (Apple Watch) で Siri のフレーズ・ダブルタップ・時計単体 (iPhone から離れた状態) の送信を確かめる
- [x] アプリアイコン (星空を飛ぶ紙飛行機。#2)
- [ ] 英語のローカライズ (Siri のフレーズは `AppShortcuts.xcstrings` で言語ごとに要る)
- [x] コンプリケーション / Smart Stack のウィジェット (2026-11-10。タップで WatchHook を開くだけの固定表示)
- [ ] ウィジェットのタップから入力画面まで直接開く。今はアプリのホームが開き、「話す」かダブルタップがもう 1 回要る。SwiftUI の `TextFieldLink` はコードから開けないので、別の入力の出し方を調べる
- [x] アプリ内のマニュアル (iPhone の「使い方」タブ。送り先の登録・Watch での送り方・ウィジェット・困ったとき・受け取る側の仕様。2026-11-10)
- [ ] バックグラウンドでの自動再送
- [ ] AI の API へ直接送る送り先 (OpenAI / Anthropic / Gemini。ユーザーの API キー。返答を時計に表示)。**入力を第三者 AI へ送るので、送る前の同意が要る (App Review 5.1.2(i))**
- [ ] 受け口のサンプル (Cloudflare Workers 等) と、署名ヘッダ (HMAC) の任意対応

## 公開前に要るもの (`~/work/docs/global-rules/new-app-project.md`)

- [ ] プライバシーポリシー (アプリ専用)・サポート URL
- [ ] プライバシーラベル: 自前で集めるものは無い (送信先はユーザーが登録したもの)。SDK を入れたら `docs/privacy-labels.md` を作る
- [ ] 強制アップデートと GA4 の計測 (`~/work/docs/global-rules/app-analytics.md`) を v1 に入れるか決める (Firebase を入れるかどうか)
- [ ] 課金するか決める
