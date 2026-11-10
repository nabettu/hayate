# Translation brief: Hayate (Apple Watch app)

Hayate sends what you say to your Apple Watch straight to a webhook you registered (Slack, Discord, your own API).
Source language is Japanese. Translate natural, concise, native UI copy (as Apple's own apps would phrase it), not literal.

## Input files (in this directory)
- `units.json`: app UI strings. Each item: `file`, `id` (the KEY), `ja` (source text), `note`.
  - For `Shared/AppShortcuts.xcstrings` the `ja` is empty: the source is a SET of 3 Siri phrases:
    `${applicationName}で送って`, `${applicationName}で送る`, `${applicationName}に送って` ("Send with Hayate" style). Give 2-3 natural phrases a user would SAY to Siri, each containing `${applicationName}` exactly once.
  - `InfoPlist.xcstrings` items: `CFBundleDisplayName` → always `Hayate`. `CFBundleName` → keep the id's ja value unchanged. `はやて` (INAlternativeAppName, a spoken alias for Siri) → `Hayate` in your language's script if Siri would need it (e.g. ハヤテ-like transliteration in Cyrillic/Arabic/Devanagari...), otherwise `Hayate`.
- `store-ja.json`: App Store metadata + 2 in-app purchase names/descriptions.
- `shots-ja.json`: text drawn on App Store screenshots (marketing headlines + mock app screen text).

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
  - `screen.*` is text inside the mock app UI: translate like the app (consistent with your units.json translations: e.g. `speak` = the app's "話す" button, `statusSent`/`statusPending` = the app's 送信済み/未送信, `history`, `destinationsTitle`). `screen.spoken` = 3 short example dictations a user might say (localize them culturally: groceries, dentist, parking spot). `screen.destinations` = keep "Slack #memo", "Discord #todo", translate "家計簿 API" (expenses API). `screen.siriAsk` MUST equal your FIRST AppShortcuts phrase with `${applicationName}` replaced by `Hayate`. `screen.siriQuestion` = how Siri asks "What do you want to send?". `screen.siriDialog` = "Sent to Slack #memo." `screen.sent` = "Sent to “Slack #memo”" (use your quotes). `screen.quote` = [open, close] quote marks of your language. `screen.defaultMark` = "(Default)". `screen.edit.*` = mock of the destination edit screen (bodyTemplate: keep as is).
  - FORBIDDEN in all screenshot text (App Store rule 2.3.7): words for free/price/sale/discount/best/top/#1/number one/guaranteed/proven/cheap/limited time, and their equivalents in your language.
- Store metadata (`store-ja.json`), App Store limits (characters): `name` keep `Hayate`; `subtitle` ≤ 30; `promotionalText` ≤ 170; `keywords` ≤ 100 total, comma-separated, no spaces after commas, localized search terms people in that market would type (keep webhook,Slack,Discord,Siri); `description` ≤ 4000 (keep structure, ■ headings may become your language's heading style; keep the {{...}} and header names). Description MAY mention the free trial and one-time purchase (it's the pricing section) — that is fine there.
  - IAP: `name` ≤ 30, `description` ≤ 55. Trial name should mean "7-Day Free Trial".

## Output
Write ONE JSON file per language to `out/<lang>.json` (UTF-8, valid JSON) with this shape:
```
{
  "lang": "<lang>",
  "app": { "<id>": "<translation>", ...  ALL ids from units.json except the AppShortcuts one },
  "appShortcuts": ["phrase 1 with ${applicationName}", "phrase 2", "phrase 3 (optional)"],
  "store": { same keys as store-ja.json, including "iap" },
  "shots": { same shape as shots-ja.json }
}
```
Then validate your file with: `python3 check.py out/<lang>.json` and fix every reported problem until it prints OK.
