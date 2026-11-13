# Privacy Policy

**English** · [日本語](PRIVACY.ja.md) · Last updated: 2026-11-13

This policy describes how Hayate (the iPhone / Apple Watch app, "the app") handles your information.

## What the developer collects

**Nothing.** The app has no developer server, analytics, ads or tracking. The developer never receives your input, settings or usage.

## What is stored on your devices

- **Memos** (what you entered, when, and delivery results) are stored on your iPhone and Apple Watch. They are not synced to iCloud (they are included in device backups).
- **Destination settings** (URLs, headers including credentials, body templates) are stored in the Keychain of your iPhone and Apple Watch.
- The iPhone and Apple Watch exchange data directly via Apple's WatchConnectivity.

## What is sent elsewhere, only at your direction

- **Webhooks**: memo contents are sent to the destinations you registered and turned on. What happens to the data after that is governed by the policies of those services (Slack, Discord, etc.).
- **Reminders**: only if you allow it, memos that start with a trigger word are added to the Reminders list you chose on your iPhone. The app reads your reminders to avoid adding duplicates.
- **Markdown**: memos are appended to files in the folder you chose. If that folder is in iCloud Drive, the files sync to iCloud.
- **Dictation**: speech is turned into text by the OS (Siri's listening / the watchOS input screen). The app does not receive microphone audio. Audio is handled under Apple's policies.

## Deletion

You can delete memos and destinations in the app at any time. Deleting the app removes the memos on the device, but destination settings stored in the Keychain may remain on the device by OS design. To remove them for sure, delete the destinations in the app before deleting the app.

## Contact

Please use [GitHub Issues](https://github.com/nabettu/hayate/issues). The source code is available at [github.com/nabettu/hayate](https://github.com/nabettu/hayate).

If this policy changes, this page will be updated.
