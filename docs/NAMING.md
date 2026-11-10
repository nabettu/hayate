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

ROADMAP の「公開前に要るもの」に書いた (商標・実機の Siri・ドメイン)。
