# 課金: 7 日間の無料お試し + 買い切り (2026-11-10)

> **2026-11-13 に廃止を決定**: 無料・OSS にする ([FREE_OSS.md](FREE_OSS.md))。以下は当時の記録。

アプリ本体は無料で配り、アプリ内課金で次の 2 つを売る。サブスクリプションにはしない。

| 商品 | Product ID | 種類 | 価格 | 参照名 |
|---|---|---|---|---|
| 7 日間の無料お試し | `com.nabettu.watchhook.trial7d` | 非消耗型 | 0 円 | `7-day Trial` |
| 買い切り | `com.nabettu.watchhook.unlock` | 非消耗型 | $4.99 / 750 円 (下の「価格」) | `Full Unlock` |

ID と日数の正は `Packages/WatchHookCore/Sources/WatchHookCore/Entitlement.swift` の `StoreProducts`。

## なぜこの形か

- App Review Guidelines 3.1.1 が認めている形: 「サブスクリプションでないアプリは、価格 0 の非消耗型を `XX-day Trial` という名前で作り、期間限定の無料お試しを出してよい」。
  ユーザーの依頼 (参考にしたアプリ Casement がこの作り。下の「参考: Casement」) どおり
- 2026 年 4〜5 月にも Apple の DTS が「無料ダウンロード + 0 円と有料の非消耗型で機能を開ける」形を今の推奨としている (開発者がメールの返答をフォーラムに転載。https://developer.apple.com/forums/thread/823270)。
  同じ返答で「購入の時点から数えるので、利用者は条件を読んでから自分の都合のよいときに始められる」とも言っている。お試し前でも送り先の登録とテスト送信 (5 回まで) をできるようにしたのはこのため
- お試しを「購入」にすると、開始日が Apple の署名付きの取引 (`originalPurchaseDate`) に残る。アプリの入れ直し・機種変更でも同じ日から数えられ、もう一度 0 円で買い直してお試しをやり直すこともできない (非消耗型は 1 回しか買えない)。
  自前のサーバー・Keychain に開始日を置く必要がない
- お試しの開始と購入の件数が App Store Connect の売上レポートに出るので、Firebase を入れなくても「お試し → 購入」の率は追える (下の「計測」)

## 参考: Casement (2026-11-10 に調べた)

ユーザーが参考に挙げたアプリ (音声入力では「ケースメント」)。Mac のアプリのウインドウを iPhone・iPad・Vision Pro で開くアプリ。
[App Store](https://apps.apple.com/jp/app/id6816655420) / https://casement.win (作者 Shinnosuke Iwaki (MIRO)。2026-10-29 公開、v1.0.4、評価 4.7・19 件)。
同名の別アプリ「Casement: Remote Desktop」(Brandon Stellina、無料・OSS、課金なし) とは別物。

| 項目 | Casement | WatchHook (この設計) |
|---|---|---|
| アプリ本体 | 無料 (アプリ内購入あり) | 無料 |
| お試し | 非消耗型「7日間のお試し」¥0 (英語は `7-day Trial` $0.00) | 同じ形 (`7-day Trial`) |
| 買い切り | 「Casement（買い切り）」¥2,000 (米国 `Casement — One-Time Purchase` $12.99) | $4.99 / ¥750 (当初 $9.99 / ¥1,500) |
| サブスク | なし (説明文・サポートに「サブスクリプションはありません」と明記) | なし |
| 端末をまたぐ購入 | 1 回の購入で iPhone・iPad・Vision Pro・Mac すべて (ユニバーサル購入) | iPhone と時計で共有 (同じレコード) |
| ペアのソフト | Mac 側の Casement Home は無料 (サイトで配布) | なし |
| お試し後にできること | **公開情報には書かれていない** (説明文・サポート・規約のどこにも無い)。アプリの購入画面を見ないと分からない | 送り先の登録・履歴は使える。Watch / Siri / iPhone の「送る」タブ・テスト送信が止まる |

- 説明文の「■ 料金」は 3 行だけ: 「7日間無料でお試しいただけます。そのあとはアプリ内の買い切りで使い続けられます。1回の購入で…すべてで使えます。サブスクリプションはありません。」。WatchHook のストアの説明文もこの書き方にそろえるとよい
- 価格はサポートに書かず「App Store のページでご確認ください」としている (国ごとに違うため)
- レビューに「買い切りなのも良い」「即課金しました」「継続のための購入いたします」があり、買い切りであることが評価されている

## 価格: $4.99 / ¥750 (2026-11-12 に $9.99 / ¥1,500 から下げた)

**2026-11-12 にユーザーが「もっと下げよう、$5 くらい」と決め、公開前に $4.99 / ¥750 へ下げた。** 日本の ¥750 は、前と同じ比 (約 150 円/ドル) でユーザーが選んだ (¥800・¥700 と比べて)。
ASC では米国 $4.99 と日本 ¥750 を手で決め、他の国は自動換算 (`asc iap pricing schedules create --base-territory USA --prices <USA の ID>,<JPN の ID>`。価格ポイントの ID は `asc iap pricing price-points list --iap-id 6832907079 --territory <国> --min-price <> --max-price <> --paginate`)。
相場の表のうち Talon $5.99・wrist/off $2.99 のあいだで、Watch の小物アプリの買い切り ($6.99〜$7.99) より下に置いた形。

以下は最初に決めたとき (2026-11-10) の記録。**2026-11-10 にユーザーが決定。** ユーザーの希望は「$10 前後で一番売れる値段」。近い買い切りの相場 (米国の App Store、2026-11-10 に調べた):

| アプリ | 形 | 価格 |
|---|---|---|
| wrist/off (Watch → webhook) | アプリ内の買い切り | $2.99 |
| Talon (webhook) | Pro の買い切り | $5.99 |
| Just Press Record (Watch で録音・文字起こし) | 有料アプリ | $6.99 |
| FlickType (Watch のキーボード) | Premium の買い切り | $7.99 |
| Whisper Notes (文字起こし) | 有料アプリ | $7.99 |
| Casement (参考にしたアプリ) | 7 日お試し + 買い切り | $12.99 / ¥2,000 |
| Pushcut (Shortcuts + webhook) | Pro Lifetime | $39.99 (月額 $1.99 もある) |
| Whisper Memos / Monologue (音声入力) | サブスク | 月 $9.99〜$14.99 |

決めたこと:
- **$9.99 (日本 ¥1,500)**。$10 の壁の手前に置く。Watch の小物アプリの買い切り ($6.99〜$7.99) よりは上だが、
  webhook を使う人 (開発者・自動化好き) は Pushcut の Lifetime $39.99 や月額サブスクを払う層なので、$9.99 なら「サブスク 1 か月分で一生」と比べて安く見える
- 7 日間のお試しで価値を確かめてから買うので、値段の高さで入口を減らしにくい (お試しを始める数は価格に左右されない)
- 日本の ¥1,500 は $9.99 とほぼ同じ (Casement の $12.99 ↔ ¥2,000 と同じ比)。App Store Connect では米国 $9.99 と日本 ¥1,500 を両方とも手で決め、他の国は自動換算
- 非消耗型の価格はあとから変えられる。公開後 1〜2 か月、お試し → 購入の率 (下の「計測」) を見て、低ければさらに下げることを考える (当初の $9.99 のときは $7.99 を試す予定だった)。
  上げるのは下げるより反発が大きいので、最初から安くしすぎない

## 3.1.1 の条件と、どこで満たしているか

> Prior to the start of the trial, your app must clearly identify its duration, the content or services that will no longer be accessible when the trial ends, and any downstream charges the user would need to pay for full functionality.

購入画面 (`WatchHook/PurchaseView.swift` の「料金」) に次を出してから、お試しのボタンを置いている。文言を変えるときは 3 つとも残す。

- 期間: 7 日間。自動で課金されない
- 終わると使えなくなるもの: Apple Watch・Siri・iPhone の「送る」タブからの送信 (送り先のテスト送信も止まる。送り先の登録・履歴は残る)
- 続けて使うのに要る支払い: 買い切り 1 回 (StoreKit の `displayPrice` を出す。固定の文字列にしない)。**買い切りの価格を読めるまでお試しのボタンは押せない**

ほか: 「購入を復元」を購入画面に置く (3.1.1「restore mechanism」)。購入画面には送り先の一覧の上の帯と「使い方」タブの「料金」から入れる。
お試しのボタンは、まだお試しを始めていない人にだけ出す。

## 何ができなくなるか

| 状態 (`AccessState`) | Apple Watch / Siri / iPhone の「送る」タブからの新しい送信・溜まった分の再送 | 送り先のテスト送信 | 送り先の登録・履歴 |
|---|---|---|---|
| お試し前 (`trialNotStarted`) | × | 5 回まで | ○ |
| お試し中 (`trial`) | ○ | ○ | ○ |
| お試し終了 (`trialExpired`) | × | × | ○ |
| 購入済み (`unlocked`) | ○ | ○ | ○ |

- お試し前でも送り先の登録とテスト送信はできる。7 日間を設定の試行錯誤で使い切らないため。
  ただしテスト送信は、本文が固定の文でも**送り先の本文テンプレートを書き換えれば好きな内容を送れる** (2026-11-10 ai-review の指摘) ので、
  お試し前は 5 回まで (`TestSendPolicy`、回数は UserDefaults。入れ直すと戻るのは受け入れる)、お試しが終わったあとはテスト送信も止める
- **お試し前・終了後は、再送待ちも送らない** (自動の再送 `MessageDispatcher.flush` も手動の「再送」も)。再送待ちは消さずに残し、購入したら送る。
  再送は送る直前の送り先の設定で組み立て直すので、期限後に本文テンプレートを書き換えれば好きな内容を送れてしまうため (2026-11-10 ai-review の指摘。
  最初は「送れる間に受け付けたものは送り直す」にしていた)
- 止めるのは `SendTextIntent.perform` (Siri)・`WatchHomeView.send` (時計のボタン)・`ComposeView.send` (iPhone の「送る」タブ) の 3 か所。どれも送る直前に StoreKit を読み直す。**送る入口を足したら、ここにも足す**

## 時計での判定

- 時計も自分で `Transaction.currentEntitlements` を読む (iPhone と時計のアプリは同じ App Store のレコードなので購入は共有される)
- それに加えて、iPhone が読んだ状態を applicationContext (`SyncKeys.entitlement`) で送り、時計は `merging` で合わせる。iPhone で買った直後、時計の StoreKit に届くまでの間も使えるようにするため。
  秘密ではないので applicationContext と時計の UserDefaults に置いてよい (送り先の設定とは扱いが違う)
- iPhone から届いたものは「最新の 1 件」で置き換え、積み上げない。iPhone で返金されれば次の知らせで戻る
- 買い切りとお試しは取引 ID (`Transaction.originalID`。端末・復元をまたいで同じ) で「有効」「返金・取り消し済み」を持ち、合わせるときは両方を足して、取り消し済みの取引を有効から外す。
  iPhone と時計のどちらで先に返金を確かめても、もう一方の古い「購入済み」に負けない。返金のあと買い直した分は別の取引なので残る。
  取り消しは `Transaction.all` の `revocationDate` をすべて見る (`currentEntitlements` には出てこない。最新の 1 件だけだと、返金 → 買い直し → 返金で最初の返金を取りこぼす)
- 時計で送る直前の判定は、画面用の状態ではなく、その場で StoreKit から読んだ結果 (`EntitlementStore.currentAccess()`) で行う
- 状態の読み直し (`refresh`) は起動・前面化・購入・`Transaction.updates` で重なる。最後に始めた読み取りの結果だけを使う (`LatestRequestGate`)
- applicationContext は丸ごと置き換わるので、`PhoneSync.push` は設定の版と購入の状態を毎回両方載せる

## 意図した制限 (不具合ではない)

- **端末の時刻を戻すとお試しが延びる**。判定は端末の時刻と購入日の比較だけ。サーバーを持たないアプリなので受け入れる (`EntitlementPolicy.state`)
- **購入は iPhone だけ**。時計は「iPhone の WatchHook で購入してください」と出す
- 返金 (`revocationDate` あり) は数えない。署名を確かめられない取引も数えない

## 動作確認

- 単体: `scripts/verify.sh` (`EntitlementTests`: 期間の境目・返金・合わせ方・残り日数)
- 購入の流れ: Xcode で `WatchHook` スキームを実行すると `StoreKit/WatchHook.storekit` が効き、App Store Connect に商品が無くても購入・復元・返金を試せる (Debug > StoreKit > Manage Transactions)。
  **ssh の `simctl launch` で起動したときは効かない** (StoreKit の設定ファイルは Xcode から起動したときだけ使われる)。
  ただし ASC に商品を作ったあとは、シミュレータを ssh で起動しても **Sandbox の本物の商品** が読める (2026-11-10 に mini の `WatchHook-Dev` で $0.00 / $9.99 が出た。米国のストアの値)
- 画面の状態だけ見るとき (Debug ビルド): 起動引数 `-WatchHookDebugAccess none|trial|expired|unlocked` で StoreKit を通さずに状態を決められる。
  例: `xcrun simctl launch <udid> com.nabettu.watchhook.watchkitapp -WatchHookDebugAccess expired`
- 時計のロック表示は送り先がある画面に出る。署名なし (`CODE_SIGNING_ALLOWED=NO`) のビルドは Keychain が読めず送り先が出ないので、既定の署名でビルドしたものを入れる
- Sandbox: App Store Connect に商品を作ったあと、Sandbox のテストアカウントで実機から買う。**実アカウントの確認画面が出たら止める**

## 計測

v1 に Firebase を入れるかは未決 (ROADMAP)。入れない間は App Store Connect で見る:
- 売上とトレンド → アプリ内課金で、`trial7d` の件数 = お試しを始めた人、`unlock` の件数 = 買った人。比が「お試し → 購入」の率
- 入れるときは `~/work/docs/global-rules/app-analytics.md` の名前で `paywall_view`(`trigger` = `banner` / `help` / `watch`)・`purchase_start`・`purchase_success`(`free_trial` = trial7d なら true)・`purchase_cancel`・`purchase_fail`・`restore_purchases`、ユーザープロパティ `plan_status` (`AccessState` の 4 つ) を送る。呼ぶ場所は `PurchaseView` の `buyButton` / 復元と `EntitlementStore.handle`

## App Store Connect の状態 (2026-11-10 に作成)

| もの | ID | 状態 |
|---|---|---|
| アプリ「Hayate」(作成時は WatchHook。2026-11-10 に `asc apps rename` で改名) | `6832906978` (SKU `com.nabettu.watchhook`、主言語 日本語) | ASC の画面で作成 (API では作れない。`asc web apps create` は Apple ID の Web ログインが要る) |
| Bundle ID | `com.nabettu.watchhook` / `.watchkitapp` / `.watchkitapp.widget` | `asc bundle-ids create` で登録 |
| お試し `trial7d` | IAP `6832907177` | ¥0 (価格ポイント `10000`)・ja の表示名と説明・175 か国 + 新しい国も自動 |
| 買い切り `unlock` | IAP `6832907079` | **米国 $4.99・日本 ¥750 を手動で固定** (2026-11-12 に $9.99 / ¥1,500 から変更)、他の国は自動換算・ja の表示名と説明・175 か国 + 新しい国も自動 |

- 有料アプリ契約: CROSSEDGE Inc. で 175 か国とも有効 (ASC > ビジネス で確認)
- 両方ともファミリー共有はオフ (既定のまま。一度オンにすると戻せない)
- 審査用のスクリーンショットを 2026-11-10 に載せ、両方とも **`READY_TO_SUBMIT`** になった (`MISSING_METADATA` から抜けた)。
  お試しはお試し前 (`-WatchHookDebugAccess none`)、買い切りはお試し終了後 (`expired`) の購入画面。Sandbox の価格が出ている (買い切りは 2026-11-12 に $4.99 の画面で撮り直した。`update` では差し替えられないので `delete` → `create`)。
  撮り方: Debug ビルドを `WatchHook-Dev` に入れ、agent-device で `open com.nabettu.watchhook --relaunch --launch-args=-WatchHookDebugAccess --launch-args=none`
  (`--launch-args` は 1 語ずつ繰り返す。`"-WatchHookDebugAccess none"` と 1 つにすると効かない) → 帯から購入画面 → `screenshot --pixel-density 3` →
  アルファを消して (`magick in.png -background black -alpha remove -alpha off out.png`) `asc iap review-screenshots create --iap-id <id> --file <png>`。
  購入画面の文言・ボタンを変えたら撮り直して `asc iap review-screenshots update` で差し替える
- 英語のローカライズはまだ (アプリの英語化と一緒に足す)
- `asc iap setup --price 0` は「price point not found」で失敗する (IAP と表示名は作られる)。0 円は `asc iap pricing price-points list --iap-id <id> --territory USA` で `customerPrice: 0.0` の ID を探し、`asc iap pricing schedules create --prices <ID>` で付ける

## App Store Connect でやること (作ったときの手順)

1. 「アプリ内課金」→ 非消耗型を 2 つ作る (上の表の Product ID・参照名)
   - お試し: 価格は「無料 (0)」。表示名「7 日間の無料お試し」、説明「7 日間、すべての機能を無料で使えます。自動で課金されません。」
   - 買い切り: 価格は米国 $4.99・日本 750 円を手で決め、他の国は自動換算。表示名「Hayate (買い切り)」、説明「Apple Watch・Siri・iPhone からの送信をずっと使えます。1 回だけの支払いです。」
   - ファミリー共有: 両方オフ (オンにするなら買い切りだけ。お試しは共有しない)
   - 審査用のスクリーンショット: iPhone の購入画面
2. **初回は 2 つの商品を、アプリ本体と同じ提出に含める** (含め忘れると公開後に買えない)
3. App Review への注記 (英語): 「The app is free to download. Sending from Apple Watch / Siri requires either the free 7-day trial (Non-Consumable, price tier 0, per Guideline 3.1.1) or the one-time Full Unlock. Destinations and test sends work without a purchase.」
4. ストアの説明文にも「7 日間無料でお試し・その後は買い切り」と書く
