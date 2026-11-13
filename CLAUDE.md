# WatchHook (アプリ名: Hayate)

Apple Watch の音声入力を webhook へ送るアプリ。画面に出る名前は Hayate、コード・ターゲット・Bundle ID は WatchHook のまま ([docs/NAMING.md](docs/NAMING.md))。全体像は [README.md](README.md)、設計判断は [docs/DESIGN.md](docs/DESIGN.md)、課金 (お試し + 買い切り。2026-11-13 にやめた。経緯だけ) は [docs/BILLING.md](docs/BILLING.md)、無料・OSS 化と機能変更は [docs/FREE_OSS.md](docs/FREE_OSS.md)、予定は [ROADMAP.md](ROADMAP.md)。

## ルール

- Xcode のプロジェクトは `project.yml` (XcodeGen) が正。`WatchHook.xcodeproj` を Xcode の画面で直接いじらず、`project.yml` を変えて `xcodegen generate` → 両方コミット
  (`.xcodeproj` もコミットしている。XcodeGen を入れていない環境でもそのまま開いてビルドできるように)
- ロジックは `Packages/WatchHookCore` に置いて TDD (Swift Testing)。アプリ側 (`Shared/` 以降) は UI と OS の API をつなぐだけにする
- 送り先の設定 (認証ヘッダを含む) は Keychain だけに置く。UserDefaults・ファイル・ログに出さない
- webhook は時計から直接送る (iPhone を中継しない)。理由は docs/DESIGN.md。リマインダー・Markdown は iPhone が受け持つ (メモの正は iPhone。docs/FREE_OSS.md の「実装」)
- ライセンスは MIT (`LICENSE`)。リポジトリは公開している。秘密 (webhook の URL・鍵)・個人の情報・作者の手元の環境の話をコミットしない
- Bundle ID: `com.nabettu.watchhook` / `com.nabettu.watchhook.watchkitapp`。Team `2KDR72P2RA`
- 文言は日本語で書き、44 言語に訳してある (String Catalog・ストア・スクショ)。文言を足したら訳も足す。手順は [scripts/l10n/README.md](scripts/l10n/README.md)
- 新しい依存を足さない (今は Apple のフレームワークだけ)。足すなら理由を PR に書き、バージョンを固定する

## 完了の定義

| 変更 | 通すもの |
|---|---|
| Core | `scripts/verify.sh` |
| アプリ・`project.yml` | `scripts/verify.sh --full` + シミュレータで目視 (iPhone と Watch のペア) |
| doc だけ | なし |

人に確認する操作: TestFlight / ストアへのアップロード・審査提出・App Store Connect でのアプリ作成。それ以外は聞かずに進めてよい。

## シミュレータ・実機

- iPhone と Apple Watch のシミュレータをペアにして確かめる
- Keychain は署名なし (`CODE_SIGNING_ALLOWED=NO`) のビルドだと書けない。動作確認は署名したビルドで行う
- 作者の手元の手順 (使うマシン・実機への入れ方・App Store Connect の鍵) は gitignore した `CLAUDE.local.md` にある。手元にあれば読む (worktree ではメインのチェックアウトのもの)

## ハマりどころ

- **WatchConnectivity などの完了ハンドラを `Task { @MainActor in ... }` の中で作らない**。MainActor 所属とみなされ、OS のキューから呼ばれた瞬間に Swift 6 の実行時チェックで落ちる (`dispatch_assert_queue`)。nonisolated の関数でクロージャを作り、中で `Task { @MainActor in }` に移る
- **実機の時計に Watch アプリが入らないときは、署名のプロファイルに時計が入っているかを見る**。Xcode に Apple ID のログインが無いと、`-allowProvisioningUpdates` だけでは時計を登録する前の古い汎用プロファイルを使い回し、時計にだけ入らない。App Store Connect の API キー (`-authenticationKeyPath` / `-authenticationKeyID` / `-authenticationKeyIssuerID`) を付けて取り直させる。確かめ方: `security cms -D -i <.app>/embedded.mobileprovision` に時計の UDID があるか
