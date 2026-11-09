# WatchHook

Apple Watch の音声入力を webhook へ送るアプリ。全体像は [README.md](README.md)、設計判断は [docs/DESIGN.md](docs/DESIGN.md)、予定は [ROADMAP.md](ROADMAP.md)。

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

台帳は `~/work/docs/ios-simulator-registry.md`。`WatchHook-Dev` (iPhone) と `WatchHook-Watch-Dev` (Apple Watch) をペアで使う。
