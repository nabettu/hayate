<p align="center"><img src="design/app-icon.svg" width="128" alt="Hayate app icon"></p>

# Hayate

**English** · [日本語](README.ja.md) · [MIT License](LICENSE) · [Privacy](PRIVACY.md) · [Sponsor on GitHub](https://github.com/sponsors/nabettu)

Hayate is an iPhone / Apple Watch app that saves what you say to your watch as a memo, then sends it to Reminders, a Markdown file, and the webhooks you registered (Slack, Discord, your own API, …). **Free, no ads, no analytics, no server of ours in between.**

> Status: not released yet (being tested in TestFlight). A link will be added here once it is on the App Store.

## Features

- **Start**: say "Hey Siri, send with Hayate" and keep talking (hands-free). Or open the app and double tap (Series 9 / Ultra 2 or later), or tap the complication on your watch face.
- **Memos**: every input is saved on the device first, so nothing is lost when sending fails. The iPhone keeps all memos; the watch keeps the latest 50. On the iPhone you can view, copy, share and delete memos, and send any of them to a webhook later.
- **Webhooks**: sent directly from the watch (not relayed through the iPhone) to every destination you turned on in the iPhone app. If a send fails, it is kept and retried the next time you open the app (there is no automatic retry in the background).
- **Reminders**: start a memo with a trigger word (defaults for 44 languages; you can add your own), e.g. "Reminder, buy milk", and the iPhone adds "buy milk" to the Reminders list you chose.
- **Markdown**: the iPhone appends each memo as a line (`- HH:mm text`) to `YYYY-MM-DD.md` in a folder you choose (e.g. an Obsidian vault in iCloud Drive).
- **Destination settings**: URL, method, headers (e.g. `Authorization`) and a body template. Presets for Slack, Discord, Google Chat, Teams, Telegram, ntfy, Notion, Todoist, Home Assistant, n8n and IFTTT. Stored in the Keychain and synced to the watch over WatchConnectivity.
- **Languages**: 45 languages, Japanese plus 44 machine translations (corrections are very welcome).

The spec and decisions are in [docs/FREE_OSS.md](docs/FREE_OSS.md), the design in [docs/DESIGN.md](docs/DESIGN.md), and plans in [ROADMAP.md](ROADMAP.md) (all in Japanese).
The app is named Hayate, while the code, targets, bundle IDs and internal names such as the `X-WatchHook-*` header keep the development name WatchHook ([docs/NAMING.md](docs/NAMING.md)).

## Receiving webhooks

- Only `https` URLs are accepted. Redirects are not followed.
- `Content-Type` matches the body format you chose: JSON (`application/json`), form (`application/x-www-form-urlencoded`) or text (`text/plain; charset=utf-8`).
- `X-WatchHook-Message-Id`: a UUID per memo. **It stays the same on retries** (and across destinations for the same memo), so you can use it to drop duplicates. Hayate does not guarantee exactly-once delivery if the receiver does not deduplicate.
- `User-Agent: WatchHook/1`
- 2xx is treated as delivered; 408 / 429 / 5xx / network errors are retried (up to 5 attempts); any other 4xx is treated as failed.
- Body template placeholders: `{{text}}` `{{id}}` `{{sentAt}}` (ISO 8601, UTC) `{{source}}` (`watch` / `phone` / `siri-watch` / `siri-phone` / `test`).

## Building it yourself

Requirements: Xcode (developed with Xcode 27, Swift 6) and devices on iOS 18 / watchOS 11 or later. The only dependencies are Apple's frameworks.

```bash
brew install xcodegen          # only needed when you change project.yml (the .xcodeproj is committed too)
open WatchHook.xcodeproj
```

To run it on your own devices, change `DEVELOPMENT_TEAM` in `project.yml` to your team and the bundle IDs starting with `com.nabettu.watchhook` (iPhone, watch and widget) to your own, then run `xcodegen generate`.
Destinations are stored in the Keychain, so an unsigned simulator build (`CODE_SIGNING_ALLOWED=NO`) cannot save them.

```bash
scripts/verify.sh              # unit tests for the core package (swift test on macOS)
scripts/verify.sh --full       # + project consistency check + iOS / watchOS builds
scripts/render-app-icon.sh     # after changing design/app-icon.svg (regenerates AppIcon.png)
(cd scripts/gen-screenshots && npm ci && node index.mjs)  # App Store screenshots (scripts/gen-screenshots/README.md)
```

## Project layout

| Path | Contents |
|---|---|
| `Packages/WatchHookCore` | Destination models and presets, body templates, building and validating requests, classifying send results, memos and per-integration state (`MemoLog`), reminder trigger words, Markdown appending. Platform independent (`swift test` on macOS) |
| `Shared/` | Code shared by the iPhone and watch apps: Keychain, settings store, saving memos and sending integrations (`MemoDispatcher`), App Intent / Siri phrases, UI parts (`Cosmos.swift`) |
| `WatchHook/` | iPhone app (memo input, memo list and details, integration settings, test sends, syncing with the watch, help `HelpView.swift`) |
| `WatchHookWatch/` | watchOS app (memo button = dictation, scribble and keyboard; memo list; syncing with the iPhone) |
| `WatchHookWidget/` | watchOS widget (complications and Smart Stack). Tapping it opens Hayate |
| `store/metadata/` / `scripts/gen-screenshots/` / `scripts/l10n/` | App Store text, screenshot generation, translation workflow |
| `project.yml` | XcodeGen definition. `WatchHook.xcodeproj` is generated from it |

## Contributing

Issues and pull requests are welcome, in English or Japanese. Docs and code comments are mostly in Japanese.

- Put logic in `Packages/WatchHookCore` together with tests (Swift Testing), and make sure `scripts/verify.sh` passes.
- Never move destination settings (URLs, auth headers) out of the Keychain (into UserDefaults, files or logs).
- We avoid adding dependencies. If you really need one, please open an issue first.
- New UI strings go into `Shared/Localizable.xcstrings`. For translations see [scripts/l10n/README.md](scripts/l10n/README.md).
- Development rules and pitfalls are in [CLAUDE.md](CLAUDE.md) (written for AI coding agents, but it applies to humans too).

Report bugs and requests in [Issues](https://github.com/nabettu/hayate/issues). Please report security issues privately via [GitHub security advisories](https://github.com/nabettu/hayate/security/advisories/new), not in a public issue.

## Author

Made by [nabettu](https://github.com/nabettu). If you like it, you can support the work via [GitHub Sponsors](https://github.com/sponsors/nabettu) (sponsoring does not change any app features).
