# App Store のスクショ (gen-screenshots)

HTML で描いて Playwright (インストール済みの Google Chrome、`channel: "chrome"`) で PNG にする。
**端末の中のアプリ画面もシミュレータで撮らずに HTML で描く** (`~/work/docs/global-rules/mobile.md`)。形式は autofill / TypeAI の「広告としてのスクショ」。

```sh
cd scripts/gen-screenshots && npm ci
node index.mjs        # 全言語 → <repo>/screenshots/app-store/<lang>/
node index.mjs ja     # 一部の言語だけ
npm test              # 禁止語のチェックのテスト
```

生成物 (`/screenshots/`) は git に入れない。入れるのは文言・テンプレート・スクリプトだけ。

| 出力 | サイズ | 中身 |
|---|---|---|
| `iphone-01_hero` 〜 `iphone-05_more` | 1320x2868 (6.9") | 見出し + 端末 (時計 / iPhone) + 吹き出し + 下の一言。5 枚目は「他にもいろいろ」 |
| `watch-01_home` 〜 `watch-03_destinations` | 416x496 (Series 10/11 46mm) | 時計の画面だけ (App Store が枠を付けて見せるので文字は載せない) |

6.9" だけ作る。ASC が小さい iPhone に流用する。Watch も 1 サイズで足りる。

## ファイル

| ファイル | 役割 |
|---|---|
| `copy.mjs` | 文言 (言語ごと)。見出しの `*...*` が強調、`\n` で改行。画面の中の例 (送り先名・話した内容) もここ |
| `render.mjs` | HTML。背景 (夜空)・時計 / iPhone の枠・アプリの画面・5 枚の構図 |
| `validate.mjs` | 価格・順位・誇大の語 (Guideline 2.3.7) を探す。見つかったら生成を止める |
| `index.mjs` | 入口。見出しが縮みすぎた・要素が重なったときも止める (画像は書き出すので見て直す) |

## 英語を足すとき

1. `copy.mjs` の `LANGS` に `en`、`ASC_LOCALES` に `en: ["en-US"]` を足し、`COPY.en` を `ja` と同じ形で書く
2. `node index.mjs en` → 全枚を開いて確かめる (見出しの切れ・はみ出し)
3. 欧文は長いので、見出しの改行を増やす。縮みすぎると `index.mjs` が止める

## 画面を変えたとき

`render.mjs` の `watchScreens` / `phoneScreens` は、実際の SwiftUI の画面 (`WatchHookWatch/WatchHomeView.swift`・`WatchHook/DestinationEditView.swift`・`Shared/Cosmos.swift` の色) を見て描いている。
アプリの見た目を変えたら、シミュレータで今の画面を一度見て、ここも合わせる (2026-11-10 にアプリが Hayate の夜空の見た目に変わり、描き直した)。

## 注意

- 文言はアプリが実際にすることだけを言う。再送は「次に開いたとき」(裏での自動再送はまだ無い)、お試し前・終了後は送信も再送も止まる (`docs/BILLING.md`)
- Slack・Discord は名前だけ出し、ロゴは使わない (他社の商標)
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
