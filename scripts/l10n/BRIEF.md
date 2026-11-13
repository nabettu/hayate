# Translation brief: Hayate (Apple Watch app)

Hayate saves what you say to your Apple Watch (or iPhone / Siri) as a memo, then sends it to the integrations you switched on: iOS Reminders (memos that start with a trigger word such as “Reminder, buy milk”), a daily Markdown file (e.g. an Obsidian vault), and any number of webhooks (Slack, Discord, Notion, your own API...). Free, open source (MIT), no ads, no tracking (since 2026-11-13; there are no in-app purchases any more).
Source language is Japanese. Translate natural, concise, native UI copy (as Apple's own apps would phrase it), not literal.

## Input files (in this directory)
- `units.json`: app UI strings. Each item: `file`, `id` (the KEY), `ja` (source text), `note`.
  - For `Shared/AppShortcuts.xcstrings` the `ja` is empty: the source is a SET of 3 Siri phrases:
    `${applicationName}で送って`, `${applicationName}で送る`, `${applicationName}に送って` ("Send with Hayate" style). Give 2-3 natural phrases a user would SAY to Siri, each containing `${applicationName}` exactly once.
  - `InfoPlist.xcstrings` items: `CFBundleDisplayName` → always `Hayate`. `CFBundleName` → keep the id's ja value unchanged. `はやて` (INAlternativeAppName, a spoken alias for Siri) → `Hayate` in your language's script if Siri would need it (e.g. ハヤテ-like transliteration in Cyrillic/Arabic/Devanagari...), otherwise `Hayate`.
- `store-ja.json`: App Store metadata (no in-app purchases).
- `shots-ja.json`: text drawn on App Store screenshots (marketing headlines + mock app screen text).
- `ReminderTrigger.swift`: `defaultKeywordsByLanguage` lists the default reminder trigger words of each language (your “first trigger word” below is the first one for your language).

## Rules
- Keep placeholders EXACTLY: `%@`, `%lld`, `%1$@`, `%2$@`, `${applicationName}`, `{{text}}`, `{{id}}`, `{{sentAt}}`, `{{source}}`. Keep their count; you may reorder only positional ones (`%1$@`).
- Never translate: Hayate, Apple Watch, iPhone, Siri, Slack, Discord, webhook (you may use the common local word if one is standard, else keep "webhook"), Keychain, Authorization, JSON, URL, HTTP, POST, API, Content-Type, User-Agent, X-WatchHook-Message-Id, WatchHook/1, n8n, Zapier, Wi-Fi, ISO 8601, UTC, code like `watch / phone / siri-watch`, `Bearer <...>` (translate only the word inside <> if any).
- Apple UI terms: use the official localized names Apple uses in that language for: Shortcuts app, Smart Stack, complication, watch face, Digital Crown, Double tap, Restore Purchases, Settings.
- Numbers with counts (e.g. "あと %lld 日" = "%lld days left"): phrase so it reads correctly for any number (e.g. "Days left: %lld") since we have no plural rules.
- 「」 quotes in ja → use your language's normal quotation marks.
- Polite but short. UI labels/buttons: very short. No exclamation marks.
- Screenshots (`shots-ja.json`):
  - `h1` and `closing` are big 2-line headlines: keep the `\n` line break (exactly 2 lines) and mark 1-3 key words with `*...*` (emphasis). Each line must be SHORT: aim ≤ 16 Latin chars / ≤ 9 CJK chars per line; ≤ 20 Latin chars hard limit. Rewrite freely as ad copy — meaning over literal.
  - `chips`: 1-2 words each, very short (≤ 12 chars).
  - `floats`, `cells` (cells keep one `\n` → 2 short lines).
  - `screen.*` is text inside the mock app UI: use EXACTLY the app's own translation from your units.json where one exists: `memoButton` = the watch button 「メモ」, `savedAndSent` = 「保存して送りました」, `destinationCount` = 「送り先 %lld 件」 with 3, `memosTitle` = the 「メモ」 screen title, `summary.*` / `status.*` = 送信済み・送信待ち・メモ・完了, `tabs` = 入力 / メモ / 連携 / 使い方, `detail.*` and `integrations.*` = the memo detail and 「連携」 screens (`reminderDetail` = 「「%@」で始めると「%@」に追加」 filled with your FIRST default reminder trigger word and the list name, `markdownDetail` = 「「%@」に日付ごとに追記」 with "Obsidian"), `reminderTarget` = 「リマインダー (%@)」 with a localized "Groceries" list name.
    `screen.spoken` = 3 short example dictations (localize culturally: parking spot, dentist, an idea). `screen.reminderSpoken` = your language's FIRST default reminder trigger word + separator + a short to-do (“Reminder, buy milk”), and `screen.reminderTitle` = that to-do WITHOUT the trigger word, exactly as the app would add it. `iphone.reminder.floats[0]` must contain `reminderTitle`. `screen.date` = a local short date + time for Nov 13 10:09. `screen.destinations` / `markdownFile` / `markdownTarget` / `integrations.kinds`: keep as is (names). `screen.siriAsk` MUST equal your FIRST AppShortcuts phrase with `${applicationName}` replaced by `Hayate`. `screen.siriQuestion` = the app's 「何をメモしますか？」. `screen.siriDialog` = `savedAndSent`. `screen.quote` = [open, close] quote marks of your language.
  - FORBIDDEN in all screenshot text (App Store rule 2.3.7): words for free/price/sale/discount/best/top/#1/number one/guaranteed/proven/cheap/limited time, and their equivalents in your language. (“Open source” and “no ads / no tracking” are fine.)
- Store metadata (`store-ja.json`), App Store limits (characters): `name` keep `Hayate`; `subtitle` ≤ 30; `promotionalText` ≤ 170; `keywords` ≤ 100 total, comma-separated, no spaces after commas, localized search terms people in that market would type (keep webhook,Obsidian,Markdown,Slack,Notion,Siri; don't repeat words already in the subtitle); `description` ≤ 4000 (keep structure, ■ headings may become your language's heading style; keep the {{...}}, header names and the GitHub URL). Only the description may say “free” (the 無料・オープンソース section); never put price words in `subtitle`, `promotionalText` or `keywords`. The Siri phrase and 「何をメモしますか？」 in the description must match your appShortcuts / units.json translations, and the reminder example must use your first trigger word.

## Output
Write ONE JSON file per language to `out/<lang>.json` (UTF-8, valid JSON) with this shape:
```
{
  "lang": "<lang>",
  "app": { "<id>": "<translation>", ...  ALL ids from units.json except the AppShortcuts one },
  "appShortcuts": ["phrase 1 with ${applicationName}", "phrase 2", "phrase 3 (optional)"],
  "store": { same keys as store-ja.json },
  "shots": { same shape as shots-ja.json }
}
```
Then validate your file with: `python3 check.py out/<lang>.json` and fix every reported problem until it prints OK.
