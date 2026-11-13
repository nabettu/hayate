# 多言語化 (scripts/l10n)

2026-11-10 に、アプリ・App Store の文言・スクショを ASC の全ロケール (50。言語にすると日本語 + 44) に訳した。元は日本語。

| もの | 置き場 |
|---|---|
| アプリの文言 | `Shared/Localizable.xcstrings` ほか各ターゲットの `*.xcstrings` (Siri のフレーズは `Shared/AppShortcuts.xcstrings`、表示名は `*/InfoPlist.xcstrings`、Core のエラーは `Packages/WatchHookCore/.../Localizable.xcstrings`) |
| ストアの文言 (名前・サブタイトル・説明文・キーワード・プロモーション) | `store/metadata/<lang>.json` |
| スクショの文言 | `scripts/gen-screenshots/copy/<lang>.json` |
| 言語 → ASC のロケール | `locales.json` |

## 文言を足した・変えたとき

1. コードに日本語で書く。SwiftUI の `Text`・`Label`・`Button` などはそのまま訳の対象になる。`String` の変数に入れる文言は `String(localized: "…")`、Core は `String(localized: "…", bundle: .module)`。自前の部品は引数を `LocalizedStringKey` にする
   (`SWIFT_EMIT_LOC_STRINGS: YES` が無いと `Text` 以外を拾わない。2026-11-10 に拾えたのが 41 / 248 件だった)
2. 書き出す: `xcodebuild -exportLocalizations -project WatchHook.xcodeproj -localizationPath <dir>/export -exportLanguage en`。`.xcstrings` にキーが入り、`<dir>/export/en.xcloc/Localized Contents/en.xliff` に一覧ができる
3. 一覧を `units.json` (file / id / ja / note) にする (下のコード)。`store/metadata/ja.json` を `store-ja.json`、`scripts/gen-screenshots/copy/ja.json` を `shots-ja.json` として同じ作業ディレクトリに置き、`BRIEF.md`・`check.py`・`Packages/WatchHookCore/Sources/WatchHookCore/ReminderTrigger.swift` (各言語のリマインダーの合図) もコピーする
4. 訳す: `BRIEF.md` を読ませて言語ごとに `out/<lang>.json` を作らせ、`python3 check.py out/<lang>.json` が OK になるまで直させる (2026-11-10 は 9 本のエージェントに 5 言語ずつ。1 本 6〜8 分)
5. 取り込む: `python3 -I scripts/l10n/apply.py <dir>/units.json <dir>/out` → `xcodegen generate` → ビルド
6. スクショ: `cd scripts/gen-screenshots && node index.mjs`。全言語を一覧にして目で見る (右から左の ar / he / ur は特に)
7. ASC へ (本番のストアのページに出る。ユーザーの OK を取ってから): `node scripts/l10n/push-store.mjs --dry-run` → `node scripts/l10n/push-store.mjs`、`cd scripts/gen-screenshots && node upload.mjs --dry-run` → `node upload.mjs`

```python
# XLIFF → units.json
import json, sys, xml.etree.ElementTree as ET
ns = {'x': 'urn:oasis:names:tc:xliff:document:1.2'}
out = []
for f in ET.parse(sys.argv[1]).getroot().findall('x:file', ns):
    for u in f.iter('{urn:oasis:names:tc:xliff:document:1.2}trans-unit'):
        note = u.find('x:note', ns)
        out.append({'file': f.get('original'), 'id': u.get('id'), 'ja': u.find('x:source', ns).text or '', 'note': note.text if note is not None else ''})
json.dump(out, open(sys.argv[2], 'w'), ensure_ascii=False, indent=1)
```

## 2026-11-13 の作り直し (無料・メモ寄り) で、ja / en 以外が古いまま

ストアの文言とスクショを、無料・OSS・メモ保存の方針 (`docs/FREE_OSS.md`) に合わせて **ja と en だけ**作り直した。ほかの 43 言語は訳し直すまで古いまま (課金・「送る」の文言)。

- スクショの文言 (`copy/<lang>.json`) の形を変えた (スライドが hero / siri / reminder / integrations / more、時計が home / memos / detail。`screen` のキーも入れ替え)。
  **古い形の言語は `node index.mjs` が「copy/ja.json と同じ形でない」で止まる** (`node index.mjs ja en` は通る)。訳し直すと `check.py` が同じ形かを見る
- ストアの文言から `iap` を外した (IAP の商品を消したので `push-store.mjs` も送らない)。古い言語のファイルに `iap` が残っていても無視され、`apply.py` で取り込み直すと消える
- 訳し直すときは、上の「文言を足した・変えたとき」の 3〜6 をそのままやる (`BRIEF.md` は新しい形に合わせてある)

## ハマりどころ

- **アプリ名はロケールごとに他社と重ならないものしか使えない**。en-US は「Hayate」が他社に使われていて、App 情報もバージョンのロケールも作れなかった (en-GB / en-AU / en-CA は通った)。
  en-US だけストアの名前を変えている (`store/metadata/en.json` の `nameByLocale`)。2026-11-10 に「Hayate: Voice to Webhook」(ユーザー決定)、2026-11-13 のメモ寄りの作り直しで「Hayate: Voice Memo & Webhook」に変えた (ASC へはまだ送っていない)。アイコンの下の名前は全言語「Hayate」のまま
- App 情報のロケールを作ると、ASC がバージョンのロケールも自動で作る。`push-store.mjs` は作る前に取り直す
- スクショは 1 セットに数分かかる (asc がサーバー側の処理を待つ)。`upload.mjs` は 6 ロケールずつ並行で上げる。100 セット (50 ロケール × iPhone / Watch)
- zsh で `node upload.mjs $LIST` と渡すと 1 つの引数になり、どの言語にも一致しない。両スクリプトとも知らない引数では止まる
- 右から左の言語のスクショ: 縮小して入れる端末の中の画面は、置き場だけ左から右にしないと右に寄ってはみ出す (`render.mjs`)
- 禁止語の誤検出: 英語の hands-free (free)・スペイン語の sale (出ていく) は言い換えた。
  **`copy/<lang>.json`・`store/metadata/<lang>.json` を手で直したら、訳の元 (`out/<lang>.json`) も同じに直す**。`apply.py` で取り込み直すと訳の元で上書きされる (2026-11-10 に一度戻った。`npm test` の禁止語チェックで気づける)
- サポート URL・プライバシーポリシーの URL はまだ無い (審査提出に要る)。決まったら `store/metadata/<lang>.json` に `supportUrl` を書けば `push-store.mjs` が送る
