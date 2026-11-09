import Foundation
import Observation
import WatchHookCore

/// 時計から届いた履歴の写し (iPhone の履歴画面で見せるだけ。再送・削除は時計で行う)。
/// 時計の最新の状態だけを持てばよいので、届くたびに丸ごと置き換える。
@MainActor
@Observable
final class WatchHistoryStore {
    static let shared = WatchHistoryStore()

    private(set) var entries: [MessageLogEntry] = []
    private(set) var updatedAt: Date?
    private let fileURL: URL

    /// 保存した写しを読めなかった (再起動後の初回ロック解除前など)。読めるまで `reloadIfNeeded` で読み直す。
    private var loadFailed = false

    init(fileURL: URL = WatchHistoryStore.defaultFileURL) {
        self.fileURL = fileURL
        load()
    }

    private func load() {
        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            loadFailed = false
            return
        } catch {
            loadFailed = true
            return
        }
        loadFailed = false
        // 壊れた写しは読み直しても直らない。次に時計から届いたもので置き換わる
        guard let saved = try? HistorySnapshot.decode(data) else { return }
        entries = saved.entries
        updatedAt = saved.updatedAt
    }

    /// 前面に来たとき・履歴画面を開いたとき。前に読めなかったときだけ読み直す。
    /// その間に時計から届いた写しがあれば、そちらが新しいので読み直さない。
    func reloadIfNeeded() {
        guard loadFailed, updatedAt == nil else { return }
        load()
    }

    static var defaultFileURL: URL {
        let dir = URL.applicationSupportDirectory
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appending(path: "watch-history.json")
    }

    /// 届いた写しで丸ごと置き換える。applicationContext は最新の 1 件だけが届くので、新旧は比べない
    /// (時計の時刻で比べると、時刻が過去に直されたときに以後の写しを全部捨ててしまう)。`updatedAt` は表示にだけ使う。
    func receive(_ snapshot: HistorySnapshot) {
        entries = snapshot.entries
        updatedAt = snapshot.updatedAt
        loadFailed = false
        if let data = try? snapshot.encoded() {
            // 本文は他人に見せたくない内容のこともあるので、起動後の初回ロック解除までは読めないようにする (時計側の履歴と同じ)
            try? data.write(to: fileURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        }
    }
}
