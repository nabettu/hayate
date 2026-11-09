# 課金: 7 日間の無料お試し + 買い切り (2026-11-10)

アプリ本体は無料で配り、アプリ内課金で次の 2 つを売る。サブスクリプションにはしない。

| 商品 | Product ID | 種類 | 価格 | 参照名 |
|---|---|---|---|---|
| 7 日間の無料お試し | `com.nabettu.watchhook.trial7d` | 非消耗型 | 0 円 | `7-day Trial` |
| 買い切り | `com.nabettu.watchhook.unlock` | 非消耗型 | 1,500 円 (日本) | `Full Unlock` |

ID と日数の正は `Packages/WatchHookCore/Sources/WatchHookCore/Entitlement.swift` の `StoreProducts`。

## なぜこの形か

- App Review Guidelines 3.1.1 が認めている形: 「サブスクリプションでないアプリは、価格 0 の非消耗型を `XX-day Trial` という名前で作り、期間限定の無料お試しを出してよい」。
  ユーザーの依頼 (参考にしたアプリがこの作り。アプリ名は音声入力で「ケースメント」と書き起こされ、綴りは未確認) どおり
- お試しを「購入」にすると、開始日が Apple の署名付きの取引 (`originalPurchaseDate`) に残る。アプリの入れ直し・機種変更でも同じ日から数えられ、もう一度 0 円で買い直してお試しをやり直すこともできない (非消耗型は 1 回しか買えない)。
  自前のサーバー・Keychain に開始日を置く必要がない
- お試しの開始と購入の件数が App Store Connect の売上レポートに出るので、Firebase を入れなくても「お試し → 購入」の率は追える (下の「計測」)

## 3.1.1 の条件と、どこで満たしているか

> Prior to the start of the trial, your app must clearly identify its duration, the content or services that will no longer be accessible when the trial ends, and any downstream charges the user would need to pay for full functionality.

購入画面 (`WatchHook/PurchaseView.swift` の「料金」) に次を出してから、お試しのボタンを置いている。文言を変えるときは 3 つとも残す。

- 期間: 7 日間。自動で課金されない
- 終わると使えなくなるもの: Apple Watch と Siri からの送信 (送り先の登録・テスト送信・履歴は残る)
- 続けて使うのに要る支払い: 買い切り 1 回 (StoreKit の `displayPrice` を出す。固定の文字列にしない)

ほか: 「購入を復元」を購入画面に置く (3.1.1「restore mechanism」)。購入画面には送り先の一覧の上の帯と「使い方」タブの「料金」から入れる。
お試しのボタンは、まだお試しを始めていない人にだけ出す。

## 何ができなくなるか

| 状態 (`AccessState`) | Apple Watch / Siri からの新しい送信 | 送り先の登録・テスト送信・履歴・溜まった分の再送 |
|---|---|---|
| お試し前 (`trialNotStarted`) | × | ○ |
| お試し中 (`trial`) | ○ | ○ |
| お試し終了 (`trialExpired`) | × | ○ |
| 購入済み (`unlocked`) | ○ | ○ |

- お試し前でも送り先の登録とテスト送信はできる。7 日間を設定の試行錯誤で使い切らないため。テスト送信は固定の文 (「WatchHook のテスト送信です」) しか送れないので、本来の使い方の代わりにはならない
- 再送待ちは、送れる間に受け付けたものなので、期限が過ぎても送り直す
- 止めるのは `SendTextIntent.perform` (Siri) と `WatchHomeView.send` (時計のボタン) の 2 か所。どちらも送る直前に StoreKit を読み直す

## 時計での判定

- 時計も自分で `Transaction.currentEntitlements` を読む (iPhone と時計のアプリは同じ App Store のレコードなので購入は共有される)
- それに加えて、iPhone が読んだ状態を applicationContext (`SyncKeys.entitlement`) で送り、時計は `merging` で合わせる。iPhone で買った直後、時計の StoreKit に届くまでの間も使えるようにするため。
  秘密ではないので applicationContext と時計の UserDefaults に置いてよい (送り先の設定とは扱いが違う)
- iPhone から届いたものは「最新の 1 件」で置き換え、積み上げない。iPhone で返金されれば次の知らせで戻る
- applicationContext は丸ごと置き換わるので、`PhoneSync.push` は設定の版と購入の状態を毎回両方載せる

## 意図した制限 (不具合ではない)

- **端末の時刻を戻すとお試しが延びる**。判定は端末の時刻と購入日の比較だけ。サーバーを持たないアプリなので受け入れる (`EntitlementPolicy.state`)
- **購入は iPhone だけ**。時計は「iPhone の WatchHook で購入してください」と出す
- 返金 (`revocationDate` あり) は数えない。署名を確かめられない取引も数えない

## 動作確認

- 単体: `scripts/verify.sh` (`EntitlementTests`: 期間の境目・返金・合わせ方・残り日数)
- 購入の流れ: Xcode で `WatchHook` スキームを実行すると `StoreKit/WatchHook.storekit` が効き、App Store Connect に商品が無くても購入・復元・返金を試せる (Debug > StoreKit > Manage Transactions)。
  **ssh の `simctl launch` で起動したときは効かない** (StoreKit の設定ファイルは Xcode から起動したときだけ使われる)
- 画面の状態だけ見るとき (Debug ビルド): 起動引数 `-WatchHookDebugAccess none|trial|expired|unlocked` で StoreKit を通さずに状態を決められる。
  例: `xcrun simctl launch <udid> com.nabettu.watchhook.watchkitapp -WatchHookDebugAccess expired`
- 時計のロック表示は送り先がある画面に出る。署名なし (`CODE_SIGNING_ALLOWED=NO`) のビルドは Keychain が読めず送り先が出ないので、既定の署名でビルドしたものを入れる
- Sandbox: App Store Connect に商品を作ったあと、Sandbox のテストアカウントで実機から買う。**実アカウントの確認画面が出たら止める**

## 計測

v1 に Firebase を入れるかは未決 (ROADMAP)。入れない間は App Store Connect で見る:
- 売上とトレンド → アプリ内課金で、`trial7d` の件数 = お試しを始めた人、`unlock` の件数 = 買った人。比が「お試し → 購入」の率
- 入れるときは `~/work/docs/global-rules/app-analytics.md` の名前で `paywall_view`(`trigger` = `banner` / `help` / `watch`)・`purchase_start`・`purchase_success`(`free_trial` = trial7d なら true)・`purchase_cancel`・`purchase_fail`・`restore_purchases`、ユーザープロパティ `plan_status` (`AccessState` の 4 つ) を送る。呼ぶ場所は `PurchaseView` の `buyButton` / 復元と `EntitlementStore.handle`

## App Store Connect でやること (ユーザーの OK を待つ)

まだ作っていない。作る前に、有料アプリ契約・銀行口座・税務フォームが有効か確かめる (反映に数日かかることがある)。

1. 「アプリ内課金」→ 非消耗型を 2 つ作る (上の表の Product ID・参照名)
   - お試し: 価格は「無料 (0)」。表示名「7 日間の無料お試し」、説明「7 日間、すべての機能を無料で使えます。自動で課金されません。」
   - 買い切り: 価格は日本 1,500 円を基準に他の国は自動換算。表示名「WatchHook (買い切り)」、説明「Apple Watch と Siri からの送信をずっと使えます。1 回だけの支払いです。」
   - ファミリー共有: 両方オフ (オンにするなら買い切りだけ。お試しは共有しない)
   - 審査用のスクリーンショット: iPhone の購入画面
2. **初回は 2 つの商品を、アプリ本体と同じ提出に含める** (含め忘れると公開後に買えない)
3. App Review への注記 (英語): 「The app is free to download. Sending from Apple Watch / Siri requires either the free 7-day trial (Non-Consumable, price tier 0, per Guideline 3.1.1) or the one-time Full Unlock. Destinations and test sends work without a purchase.」
4. ストアの説明文にも「7 日間無料でお試し・その後は買い切り」と書く
