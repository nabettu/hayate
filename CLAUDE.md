# WatchHook (アプリ名: Hayate)

Apple Watch の音声入力を webhook へ送るアプリ。画面に出る名前は Hayate、コード・ターゲット・Bundle ID は WatchHook のまま ([docs/NAMING.md](docs/NAMING.md))。全体像は [README.md](README.md)、設計判断は [docs/DESIGN.md](docs/DESIGN.md)、課金 (お試し + 買い切り) は [docs/BILLING.md](docs/BILLING.md)、予定は [ROADMAP.md](ROADMAP.md)。

## ルール

- Xcode のプロジェクトは `project.yml` (XcodeGen) が正。`WatchHook.xcodeproj` を Xcode の画面で直接いじらず、`project.yml` を変えて `xcodegen generate` → 両方コミット
  (`.xcodeproj` をコミットしているのは、`heavy` が mini へ送るのが git の管理下のファイルだけで、無いと mini でビルドできないため)
- ロジックは `Packages/WatchHookCore` に置いて TDD (Swift Testing)。アプリ側 (`Shared/` 以降) は UI と OS の API をつなぐだけにする
- 送り先の設定 (認証ヘッダを含む) は Keychain だけに置く。UserDefaults・ファイル・ログに出さない
- 送信は時計から直接行う (iPhone を中継しない)。理由は docs/DESIGN.md
- Bundle ID: `com.nabettu.watchhook` / `com.nabettu.watchhook.watchkitapp`。Team `2KDR72P2RA`
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
