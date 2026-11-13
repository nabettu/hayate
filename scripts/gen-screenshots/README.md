# App Store のスクショ (gen-screenshots)

HTML で描いて Playwright (インストール済みの Google Chrome、`channel: "chrome"`) で PNG にする。
**端末の中のアプリ画面もシミュレータで撮らずに HTML で描く** (言語ごとに作り直しやすく、架空の例文を載せられる)。形式は「広告としてのスクショ」(見出し + 端末 + 一言)。

```sh
cd scripts/gen-screenshots && npm ci
node index.mjs        # 全言語 → <repo>/screenshots/app-store/<lang>/ (ja と同じ形でない言語があると止まる)
node index.mjs ja en  # 一部の言語だけ (2026-11-13 の作り直しのあと、通るのは ja / en だけ)
npm test              # 禁止語のチェック・en が ja と同じ形か
```

生成物 (`/screenshots/`) は git に入れない。入れるのは文言・テンプレート・スクリプトだけ。

| 出力 | サイズ | 中身 |
|---|---|---|
| `iphone-01_hero` / `02_siri` / `03_reminder` / `04_integrations` / `05_more` | 1320x2868 (6.9") | 見出し + 端末 (時計 / iPhone) + 吹き出し + 下の一言。話す → メモ → 連携 / Siri / 合図でリマインダー / 複数の送り先と Markdown / 他にもいろいろ |
| `watch-01_home` / `02_memos` / `03_detail` | 416x496 (Series 10/11 46mm) | 時計の画面だけ (App Store が枠を付けて見せるので文字は載せない)。メモのボタン / メモの一覧 / 連携ごとの状態 |

6.9" だけ作る。ASC が小さい iPhone に流用する。Watch も 1 サイズで足りる。

## ファイル

| ファイル | 役割 |
|---|---|
| `copy.mjs` / `copy/<lang>.json` | 文言 (言語ごと)。見出しの `*...*` が強調、`\n` で改行。画面の中の例 (送り先名・話した内容) もここ。形は `copy/ja.json` が正で、違う言語は `index.mjs` が止める |
| `render.mjs` | HTML。背景 (夜空)・時計 / iPhone の枠・アプリの画面・5 枚の構図 |
| `validate.mjs` | 価格・順位・誇大の語 (Guideline 2.3.7) を探す。見つかったら生成を止める |
| `index.mjs` | 入口。見出しが縮みすぎた・要素が重なったときも止める (画像は書き出すので見て直す)。書き出す前に、その言語の前の画像 (`iphone-*` / `watch-*`) を消す (名前を変えたときに古い画像が一緒に上がらないように) |

## 英語を足すとき

1. `copy.mjs` の `LANGS` に `en`、`ASC_LOCALES` に `en: ["en-US"]` を足し、`COPY.en` を `ja` と同じ形で書く
2. `node index.mjs en` → 全枚を開いて確かめる (見出しの切れ・はみ出し)
3. 欧文は長いので、見出しの改行を増やす。縮みすぎると `index.mjs` が止める

## 画面を変えたとき

`render.mjs` の `watchScreens` / `phoneScreens` は、実際の SwiftUI の画面 (`WatchHookWatch/WatchHomeView.swift` のホーム・メモの一覧・メモの詳細、`WatchHook/MemoListView.swift` のメモの詳細、`WatchHook/DestinationListView.swift` の「連携」、`WatchHook/WatchHookApp.swift` のタブ、`Shared/Cosmos.swift` の色) を見て描いている。
アプリの見た目を変えたら、シミュレータで今の画面を一度見て、ここも合わせる (2026-11-10 にアプリが Hayate の夜空の見た目に変わり、描き直した)。

## 注意

- 文言はアプリが実際にすることだけを言う。再送は「次に開いたとき」(裏での自動再送はまだ無い)。リマインダー・Markdown に書くのは iPhone (時計からは iPhone に渡す)。webhook は時計で入力した分は時計から直接送る
- 2026-11-13 に無料・OSS・メモ保存の方針 (`docs/FREE_OSS.md`) に合わせて作り直した。「無料」はスクショ・サブタイトル・プロモーション・キーワードに書かない (Guideline 2.3.7。スクショは `validate.mjs` が止める。ストアの文言は止める仕組みが無いので目で見る)。説明文の「無料・オープンソース」の節だけで言う。「オープンソース」「広告も追跡もなし」はスクショに出してよい
- Slack・Discord・Notion・Obsidian などは名前だけ出し、ロゴは使わない (他社の商標)
- 例文の数字にも禁止語の規則が当たる (「980 円」が `0円` に当たった)

## アップロード (asc)

2026-11-10 にバージョン 1.0 の ja へ初めて上げた。差し替えは本番のストアのページに出るので、ユーザーの OK を取ってから。

```sh
cd screenshots/app-store/ja && d=$(~/bin/rmtmp --new wh-upload) && mkdir $d/iphone $d/watch && cp iphone-*.png $d/iphone/ && cp watch-*.png $d/watch/
asc --profile crossedge screenshots upload --app 6832906978 --version 1.0 --locale ja --path $d/iphone --device-type IPHONE_67 --replace --confirm
asc --profile crossedge screenshots upload --app 6832906978 --version 1.0 --locale ja --path $d/watch --device-type WATCH_SERIES_10 --replace --confirm
~/bin/rmtmp $d
```

- 6.9" (1320x2868) は `IPHONE_67` の枠に入れる (locktodo と同じ)。ASC が小さい iPhone に流用する
- Watch は 416x496 = `WATCH_SERIES_10`。iPhone と Watch を 1 つのディレクトリにまとめず、端末ごとに分けて渡す
- 表示順はファイル名の連番 (`01_` 〜)
- `--dry-run` で上がる・消える枚数を先に見られる
