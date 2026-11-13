import EventKit
import Foundation
import Observation
import WatchHookCore

/// リマインダー・Markdown の設定 (iPhone だけ)。秘密は無いので UserDefaults に置く。
/// フォルダは security-scoped bookmark で別に持つ (場所の情報なので時計へは送らない)。
@MainActor
@Observable
final class IntegrationStore {
    static let shared = IntegrationStore()

    private nonisolated static let settingsKey = "integrationSettings"
    private nonisolated static let bookmarkKey = "markdownFolderBookmark"

    private(set) var settings: IntegrationSettings

    init() {
        settings = Self.load()
    }

    /// 送信の処理 (MainActor の外) から読む。
    nonisolated static func load() -> IntegrationSettings {
        guard let data = UserDefaults.standard.data(forKey: settingsKey),
              let saved = try? JSONDecoder().decode(IntegrationSettings.self, from: data) else { return IntegrationSettings() }
        return saved
    }

    func update(_ change: (inout IntegrationSettings) -> Void) {
        var s = settings
        change(&s)
        settings = s
        if let data = try? JSONEncoder().encode(s) { UserDefaults.standard.set(data, forKey: Self.settingsKey) }
    }

    nonisolated static func markdownBookmark() -> Data? {
        UserDefaults.standard.data(forKey: bookmarkKey)
    }

    /// フォルダを選んだとき。あとで (裏でも) 開けるよう bookmark にして覚える。
    func setMarkdownFolder(_ url: URL) throws {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        let bookmark = try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
        UserDefaults.standard.set(bookmark, forKey: Self.bookmarkKey)
        update { $0.markdown.folderName = url.lastPathComponent }
    }

    func clearMarkdownFolder() {
        UserDefaults.standard.removeObject(forKey: Self.bookmarkKey)
        update {
            $0.markdown.folderName = nil
            $0.markdown.isEnabled = false
        }
    }
}

/// iOS のリマインダーに 1 件足す。画面は出さない (権限・リストは設定画面で先に決める)。
enum ReminderWriter {
    /// 同じメモを二重に足さないための印。リマインダーの URL 欄に入れる (タップで Hayate が開く)
    static func marker(for memoID: UUID) -> URL {
        URL(string: "hayate://memo/\(memoID.uuidString)")!
    }

    static var isAuthorized: Bool {
        EKEventStore.authorizationStatus(for: .reminder) == .fullAccess
    }

    static func save(title: String, memoID: UUID, settings: IntegrationSettings.Reminder) async -> DeliveryOutcome {
        guard isAuthorized else {
            return .permanent(reason: String(localized: "リマインダーへのアクセスが許可されていません (設定 App で許可してから送り直してください)"))
        }
        guard let listID = settings.listID else {
            return .permanent(reason: String(localized: "保存先のリストが選ばれていません"))
        }
        let store = EKEventStore()
        guard let calendar = store.calendar(withIdentifier: listID) else {
            return .permanent(reason: String(localized: "保存先のリストが見つかりません"))
        }
        let marker = marker(for: memoID)
        // 前の保存が終わったあと、結果を書く前にアプリが終わっていた場合に二重に足さない。
        // その間にリストを変えた・リマインダーを別のリストへ移したこともあるので、すべてのリストから探す
        switch await findReminder(with: marker, store: store) {
        case .found:
            return .done(detail: nil)
        case .failed:
            return .retryable(reason: String(localized: "リマインダーを読み込めませんでした"))
        case .notFound:
            break
        }
        let reminder = EKReminder(eventStore: store)
        reminder.calendar = calendar
        reminder.title = title
        reminder.url = marker
        do {
            try store.save(reminder, commit: true)
            return .done(detail: nil)
        } catch {
            return .retryable(reason: error.localizedDescription)
        }
    }

    private enum Lookup { case found, notFound, failed }

    private static func findReminder(with marker: URL, store: EKEventStore) async -> Lookup {
        let predicate = store.predicateForReminders(in: nil)
        return await withCheckedContinuation { continuation in
            store.fetchReminders(matching: predicate) { reminders in
                // nil は読み込みの失敗 (無いとみなして足すと二重になりうる)
                guard let reminders else { return continuation.resume(returning: .failed) }
                continuation.resume(returning: reminders.contains { $0.url == marker } ? .found : .notFound)
            }
        }
    }
}

/// 選んだフォルダの `YYYY-MM-DD.md` に 1 行足す。
enum MarkdownWriter {
    static func append(text: String, createdAt: Date) -> DeliveryOutcome {
        guard let bookmark = IntegrationStore.markdownBookmark() else {
            return .permanent(reason: String(localized: "Markdown の保存先フォルダが選ばれていません"))
        }
        var stale = false
        let folder: URL
        do {
            folder = try URL(resolvingBookmarkData: bookmark, options: [], relativeTo: nil, bookmarkDataIsStale: &stale)
        } catch {
            return .permanent(reason: String(localized: "保存先フォルダを開けません。フォルダを選び直してください"))
        }
        let accessing = folder.startAccessingSecurityScopedResource()
        defer { if accessing { folder.stopAccessingSecurityScopedResource() } }
        if stale, let renewed = try? folder.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil) {
            UserDefaults.standard.set(renewed, forKey: "markdownFolderBookmark")
        }

        let file = folder.appending(path: MarkdownJournal.fileName(for: createdAt))
        let line = MarkdownJournal.line(text: text, date: createdAt)
        var coordinationError: NSError?
        var writeError: Error?
        // iCloud Drive・他のアプリ (Obsidian など) と同時に書いても壊さないよう、ファイルの調整役を通す
        NSFileCoordinator().coordinate(writingItemAt: file, options: .forMerging, error: &coordinationError) { url in
            do {
                let existing: String
                if FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) {
                    existing = try String(contentsOf: url, encoding: .utf8)
                } else {
                    existing = ""
                }
                guard let updated = MarkdownJournal.appending(line, to: existing) else { return }  // 既に足してある
                try Data(updated.utf8).write(to: url, options: .atomic)
            } catch {
                writeError = error
            }
        }
        if let error = coordinationError ?? writeError {
            return .retryable(reason: error.localizedDescription)
        }
        return .done(detail: file.lastPathComponent)
    }
}
