# プライバシーポリシー / Privacy Policy

最終更新: 2026-11-13 · [English](#english)

Hayate (iPhone / Apple Watch のアプリ。以下「本アプリ」) の個人情報の扱いについて定めます。

## 開発者が集めるもの

**ありません。** 本アプリには開発者のサーバー・計測 (アナリティクス)・広告・トラッキングの仕組みがなく、開発者があなたの入力・設定・利用状況を受け取ることはありません。

## 端末の中に保存するもの

- **メモ** (入力した内容・日時・送った結果): iPhone と Apple Watch の中に保存します。iCloud への同期はしません (端末のバックアップには含まれます)
- **送り先の設定** (URL・ヘッダ (認証情報を含む)・本文のテンプレート): iPhone と Apple Watch の Keychain に保存します
- iPhone と Apple Watch の間では、Apple の WatchConnectivity で直接やり取りします

## あなたの指示で外へ送るもの

- **webhook**: あなたが登録してオンにした送り先へ、メモの内容を送ります。送った後のデータの扱いは、送り先のサービス (Slack・Discord など) のポリシーに従います
- **リマインダー**: 許可した場合に限り、合図の言葉で始めたメモを、iPhone のリマインダーの選んだリストに追加します。重複を避けるため、リマインダーの項目を読みます
- **Markdown**: あなたが選んだフォルダのファイルに追記します。そのフォルダが iCloud Drive の中なら、ファイルは iCloud に同期されます
- **音声入力**: 文字にするのは OS の音声入力 (Siri の聞き取り / watchOS の入力画面) です。本アプリはマイクの音声を受け取りません。音声の扱いは Apple のポリシーに従います

## 削除

メモと送り先はアプリの中でいつでも削除できます。アプリを削除すると端末の中のメモは消えますが、Keychain に入れた送り先の設定は OS の仕様で端末に残ることがあります。確実に消すには、アプリを削除する前にアプリの中で送り先を削除してください。

## 問い合わせ

[GitHub の Issues](https://github.com/nabettu/hayate/issues) へ。ソースコードは [github.com/nabettu/hayate](https://github.com/nabettu/hayate) で公開しています。

このポリシーを変えたときは、このページを更新します。

---

## English

Last updated: 2026-11-13

This policy describes how Hayate (the iPhone / Apple Watch app, "the app") handles your information.

**What the developer collects: nothing.** The app has no developer server, analytics, ads or tracking. The developer never receives your input, settings or usage.

**Stored on your devices**
- Memos (what you entered, when, and delivery results) are stored on your iPhone and Apple Watch. They are not synced to iCloud (they are included in device backups).
- Destination settings (URLs, headers including credentials, body templates) are stored in the Keychain of your iPhone and Apple Watch.
- The iPhone and Apple Watch exchange data directly via Apple's WatchConnectivity.

**Sent elsewhere only at your direction**
- Webhooks: memos are sent to the destinations you registered and turned on. What happens after that is governed by those services' policies.
- Reminders: only if you allow it, memos that start with a trigger word are added to the list you chose. The app reads reminders to avoid duplicates.
- Markdown: memos are appended to files in the folder you chose. If that folder is in iCloud Drive, the files sync to iCloud.
- Dictation is done by the OS (Siri / the watchOS input screen). The app does not receive microphone audio.

**Deletion**: you can delete memos and destinations in the app at any time. Deleting the app removes its memos, but destination settings in the Keychain may remain on the device by OS design. To remove them for sure, delete the destinations in the app before deleting the app.

**Contact**: [GitHub Issues](https://github.com/nabettu/hayate/issues). Source code: [github.com/nabettu/hayate](https://github.com/nabettu/hayate).
