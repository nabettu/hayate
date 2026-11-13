# WatchHook (アプリ名: Hayate)

Apple Watch の音声入力を webhook へ送るアプリ。画面に出る名前は Hayate、コード・ターゲット・Bundle ID は WatchHook のまま ([docs/NAMING.md](docs/NAMING.md))。全体像は [README.md](README.md)、設計判断は [docs/DESIGN.md](docs/DESIGN.md)、課金 (お試し + 買い切り。2026-11-13 にやめた。経緯だけ) は [docs/BILLING.md](docs/BILLING.md)、無料・OSS 化と機能変更は [docs/FREE_OSS.md](docs/FREE_OSS.md)、予定は [ROADMAP.md](ROADMAP.md)。

## ルール

- Xcode のプロジェクトは `project.yml` (XcodeGen) が正。`WatchHook.xcodeproj` を Xcode の画面で直接いじらず、`project.yml` を変えて `xcodegen generate` → 両方コミット
  (`.xcodeproj` をコミットしているのは、`heavy` が mini へ送るのが git の管理下のファイルだけで、無いと mini でビルドできないため)
- ロジックは `Packages/WatchHookCore` に置いて TDD (Swift Testing)。アプリ側 (`Shared/` 以降) は UI と OS の API をつなぐだけにする
- 送り先の設定 (認証ヘッダを含む) は Keychain だけに置く。UserDefaults・ファイル・ログに出さない
- webhook は時計から直接送る (iPhone を中継しない)。理由は docs/DESIGN.md。リマインダー・Markdown は iPhone が受け持つ (メモの正は iPhone。docs/FREE_OSS.md の「実装」)
- ライセンスは MIT (`LICENSE`)。リポジトリは公開する予定なので、秘密・個人の情報をコミットしない
- Bundle ID: `com.nabettu.watchhook` / `com.nabettu.watchhook.watchkitapp`。Team `2KDR72P2RA`
- 文言は日本語で書き、44 言語に訳してある (String Catalog・ストア・スクショ)。文言を足したら訳も足す。手順は [scripts/l10n/README.md](scripts/l10n/README.md)
- 新しい依存を足さない (今は Apple のフレームワークだけ)。足すなら `~/work/docs/global-rules/supply-chain.md`

## 完了の定義

| 変更 | 通すもの |
|---|---|
| Core | `scripts/verify.sh` |
| アプリ・`project.yml` | `scripts/verify.sh --full` + シミュレータで目視 (iPhone と Watch のペア) |
| doc だけ | なし |

人に確認する操作: TestFlight / ストアへのアップロード・審査提出・App Store Connect でのアプリ作成。それ以外は聞かずに進めてよい。

## シミュレータ

台帳は `~/work/docs/ios-simulator-registry.md`。**mini** の `WatchHook-Dev` (iPhone) と `WatchHook-Watch-Dev` (Apple Watch) をペアで使う。

- `heavy xcodebuild` は母艦で走ることがある (mini の `build/` は古いまま)。母艦の `build/Build/Products/Debug-*simulator/*.app` を rsync で mini に送って `simctl install` する
- iPhone は T3 の `device_open` (hostId `mac-mini`) で操作する。**Watch は Device パネルに出ない**ので、ssh 越しに `simctl launch` / `simctl io screenshot`
- Keychain は署名なし (`CODE_SIGNING_ALLOWED=NO`) のビルドだと書けない。動作確認は既定の署名でビルドしたものを入れる

## ハマりどころ

- **WatchConnectivity などの完了ハンドラを `Task { @MainActor in ... }` の中で作らない**。MainActor 所属とみなされ、OS のキューから呼ばれた瞬間に Swift 6 の実行時チェックで落ちる (`dispatch_assert_queue`)。nonisolated の関数でクロージャを作り、中で `Task { @MainActor in }` に移る
- **実機の時計に Watch アプリが入らないときは、署名のプロファイルに時計が入っているかを見る** (2026-11-10)。母艦の Xcode には Apple ID のログインが無く、`-allowProvisioningUpdates` だけだと手元の古い汎用プロファイル (`iOS Team Provisioning Profile: *`) を使い回す。時計 (Apple Watch S10、2026-09-19 登録) を登録する前に作られたものだと、時計にだけ入らない。
  実機ビルドは ASC の API キーを付けて Xcode にプロファイルを取り直させる: `-allowProvisioningUpdates -authenticationKeyPath ~/.appstoreconnect/private_keys/AuthKey_A2M34D6GQG.p8 -authenticationKeyID A2M34D6GQG -authenticationKeyIssuerID <TypeAI/scripts/.env の ISSUER_ID>`。
  確かめ方: `security cms -D -i <.app>/embedded.mobileprovision | grep 00008310-0008A21821D2601E`
- **実機の iPhone へは `roamrun` で入れる** (2026-11-12。Tailscale 経由なので USB も同じ Wi-Fi も要らない)。上のビルドの .app を `roamrun up iphon15pro -d` → `roamrun install iphon15pro <.app>` → `roamrun down iphon15pro`。
  iPhone がロック中だと断られる (ロックを解除して画面をつけたままにしてもらう)。`xcrun devicectl` だと Mac の近くに無い iPhone は unavailable のままで入らない
- **TestFlight へは `scripts/testflight.sh [build番号]` で上げる** (2026-11-13 に 1.0 (1) を初回アップロード)。設定は gitignore の `scripts/testflight.env` (中身の説明はスクリプトの先頭。値は `~/work/docs/asc-api-keys.md` と locktodo の `scripts/appstore/.env`)。
  export は manual signing で、プロファイル `Hayate AppStore App / WatchApp / WatchWidget` (IOS_APP_STORE、証明書は iPhone Distribution: CROSSEDGE。秘密鍵は専用 keychain `lockdo-build.keychain` にあり、スクリプトがアンロックする) を名前で指す。API キーにクラウド署名の権限が無いので automatic にはしない。証明書を作り直したらこの 3 つも `asc profiles create` で作り直す。
  build 番号は既定で `project.yml` の `CURRENT_PROJECT_VERSION`。上げたら次の番号に進めてコミットしておく
