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
- [x] コンプリケーション / Smart Stack のウィジェット (2026-11-10。タップでアプリを開くだけの固定表示)
- [ ] ウィジェットのタップから入力画面まで直接開く。今はアプリのホームが開き、「話す」かダブルタップがもう 1 回要る。SwiftUI の `TextFieldLink` はコードから開けないので、別の入力の出し方を調べる
- [x] アプリ内のマニュアル (iPhone の「使い方」タブ。送り先の登録・Watch での送り方・ウィジェット・困ったとき・受け取る側の仕様。2026-11-10)
- [x] 見た目をアイコン (星空と紙飛行機) に合わせる・送信時に紙飛行機が飛ぶ演出 (iPhone / Watch。2026-11-10)
- [x] iPhone の「送る」タブ (テキストを入力して送る。`source` は `phone`。2026-11-10)
- [ ] 実機の時計で紙飛行機の演出を見る (シミュレータでは時計の入力画面を操作できず、iPhone 側でしか動きを確かめていない)
- [ ] ウィジェットの見た目も合わせる (今は SF Symbols の紙飛行機。文字盤では OS が色を付けるので形だけ)
- [ ] バックグラウンドでの自動再送
- [ ] AI の API へ直接送る送り先 (OpenAI / Anthropic / Gemini。ユーザーの API キー。返答を時計に表示)。**入力を第三者 AI へ送るので、送る前の同意が要る (App Review 5.1.2(i))**
- [ ] 受け口のサンプル (Cloudflare Workers 等) と、署名ヘッダ (HMAC) の任意対応

## 公開前に要るもの (`~/work/docs/global-rules/new-app-project.md`)

- [ ] 「Hayate」の商標を J-PlatPat と USPTO で確かめる (第 9 類・第 42 類。JR 東日本の新幹線「はやて」の権利がソフトウェアに及ぶか)。App Store Connect でアプリを作る前に
- [ ] 実機の Siri が「はやてで送って」を Hayate と結びつけるか確かめる (`INAlternativeAppNames` に「はやて」を入れてある)
- [ ] サイトのドメイン: hayate.app / hayate.io / gethayate.com は取られている。hayateapp.com は空いていた (2026-11-10)
- [ ] プライバシーポリシー (アプリ専用)・サポート URL
- [ ] プライバシーラベル: 自前で集めるものは無い (送信先はユーザーが登録したもの)。SDK を入れたら `docs/privacy-labels.md` を作る
- [ ] 強制アップデートと GA4 の計測 (課金のイベントは `docs/BILLING.md` の「計測」) (`~/work/docs/global-rules/app-analytics.md`) を v1 に入れるか決める (Firebase を入れるかどうか)
- [x] 課金の形: 7 日間の無料お試し (0 円の非消耗型) + 買い切り $9.99 / 1,500 円 (2026-11-10 決定。`docs/BILLING.md`)
- [x] App Store Connect にアプリと IAP 商品を 2 つ作る (2026-11-10。`docs/BILLING.md` の「App Store Connect の状態」)
- [x] IAP の審査用スクリーンショット (購入画面) を載せる (2026-11-10。両方とも `READY_TO_SUBMIT`。撮り方は `docs/BILLING.md`)
- [ ] App Store のスクショ (iPhone 5 枚・Apple Watch 3 枚、日本語) を ASC に載せる。作り方は `scripts/gen-screenshots/README.md`。英語化のときに `copy.mjs` に `en` を足す
- [ ] Sandbox で購入・復元・時計への反映を実機で確かめる
