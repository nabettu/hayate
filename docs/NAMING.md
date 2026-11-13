# アプリ名: Hayate

2026-11-10 に決めた。画面・ストアに出る名前は **Hayate** (疾風・はやて)。

## 条件

- Apple Watch 専用に見えない名前 (iPhone の Siri やショートカットからも使える)
- webhook のような専門用語を入れない (技術的な説明はストアのサブタイトルに回す)
- 海外でもそのまま読める。日本語なら発音しやすい音だけ (ず・つ などは避ける)
- 「言った瞬間に飛んでいく」速さが出る

## 見送った候補と理由 (App Store の米国・日本ストアを検索した結果)

| 候補 | 見送った理由 |
|---|---|
| Blurt | 同名アプリがある。**Blurt: Wrist Voice Notes** (Apple Watch の声メモ、2026-09 公開) と AssemblyAI の Blurt (Mac の音声入力) は用途まで近い |
| Blurt 系 (Blurtify・Blurtpost など) | 先頭が blur なので、ぼかしアプリ (Blurify など) と見間違える・聞き間違える。「blurt」の検索結果もぼかしアプリが上位 |
| Whoosh / Spout / Holler / Swoop / Yeet | 同名アプリが多い。Holler は声で ToDo を送るアプリまである |
| Sugu / Hayai / Koe / Kotoba / Kaze / Tayori | 同名アプリが多い。SuguMemo・Hayai Notes・Koe - Voice Notes など声やメモのアプリと近い |
| Shun (瞬) | 英語の shun は「避ける」 |
| Hibana (火花) | 次点。Hayate のほうが速さが伝わる |

Hayate の同名は App Store にゲーム 2 つ (HAYATE: Katana Racer など) だけで、ジャンルが違う。

## 決めたこと

- 内部の名前 (ターゲット・`WatchHookCore`・Bundle ID `com.nabettu.watchhook`・ウィジェットの kind・`X-WatchHook-Message-Id`・`User-Agent: WatchHook/1`) は変えない。
  Bundle ID はストアに出した後は変えられず、ヘッダ名は受け手の実装が依存するため。リリース前に変えるなら別途決める
- Siri には日本語で「はやてで送って」と話すので、`INAlternativeAppNames` に「はやて」を入れた (iOS・watchOS のアプリ)

## まだ確かめていないこと

ROADMAP の「公開前に要るもの」に書いた (商標・実機の Siri・ドメイン)。商標は下の「商標」も見る。

## リポジトリ名 (2026-11-13)

公開に合わせて GitHub のリポジトリを `nabettu/watchhook` から **`nabettu/hayate`** に変えた (旧 URL は GitHub が転送する)。
コード・Xcode のターゲット・Core パッケージ・Bundle ID・`X-WatchHook-*` ヘッダ・`User-Agent: WatchHook/1` は **WatchHook のまま** (ユーザー決定)。
Bundle ID は App Store Connect に登録済みで変えられず、ヘッダは受け口の仕様なので、名前を揃えるためだけに変えない。

## 商標 (2026-11-13。Web 検索だけ。J-PlatPat は直接引いていない)

Google 検索 (agy) で調べた結果。J-PlatPat は検索エンジンに全件出ないので、**出願・強く名乗る前に J-PlatPat で称呼「ハヤテ」「シップウ」、類似群 11C01 (第 9 類)・42P02 (第 42 類) を直接引く**。

- 米国 (USPTO): 第 9 類・第 42 類で「HAYATE」単体の有効な登録は見つからなかった (他の類に包丁・炭素繊維素材の登録がある)
- 日本: ソフトウェア・SaaS で「HAYATE」を名乗るサービスがある (クラウド電子カルテ「HAYATE/NEO」、印刷業向け「颯 -HAYATE-」、データ基盤「HAYATE」)。商標の登録番号までは確かめられていない。
  登録が確認できたのは別の類 (「疾風＼HAYATE＼はやて」第 7 類 第5929255号) と、複合商標「ハヤテのごとく！」(第 9 類を含む 第5160983号)
- App Store: 同名で近い分野は日本語キーボード「HAYATE (早手)」(ユーティリティ)。ほかに「疾風出退」(打刻)・「ハヤメモ」(メモ)・ゲーム「HAYATE: Katana Racer」。
  音声メモを webhook へ送るアプリで同名は見つからなかった

ストア名は「Hayate: …」と説明を付けた形にしていて、上のサービスとは分野が違う (医療・印刷・データ分析)。それでも商標を取るか・名前を変えるかは J-PlatPat を引いてから決める。
