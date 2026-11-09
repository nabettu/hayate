import Foundation
import Observation
import OSLog
import WatchHookCore

private let configLogger = Logger(subsystem: "com.nabettu.watchhook", category: "config")

/// 送り先の設定の読み書き。iPhone では編集して時計へ送り、時計では iPhone から届いたものを保存する。
@MainActor
@Observable
final class ConfigStore {
    static let shared = ConfigStore()

    private(set) var config: DestinationConfig
    /// 直近の保存に失敗したときの理由。画面に出す。
    private(set) var saveError: String?
    /// 時計との同期に失敗したときの理由。
    private(set) var syncError: String?
    /// 保存したあとに呼ばれる。iPhone ではここで時計へ送り、失敗したら理由を返す。
    @ObservationIgnored var onChange: ((DestinationConfig) -> String?)?

    private nonisolated static let keychain = KeychainStore(service: "com.nabettu.watchhook", account: "destination-config")

    init() {
        config = .unsaved
        load()
    }

    /// Keychain から読む。起動時と、読めなかったあとの読み直しで同じ分け方をする。
    private func load() {
        do {
            config = try Self.loadFromKeychain()
            loadFailed = false
            saveError = nil
        } catch is DecodingError {
            // 保存されている設定の形式が読めない (壊れた・古い形式)。待っても直らないので空から始め、上書きを許す
            config = .unsaved
            loadFailed = false
            saveError = "保存されていた設定を読めなかったため、空の状態から始めます"
        } catch {
            // Keychain が一時的に読めない (ロック中など)。このまま保存すると本物の設定を空で上書きしてしまうので、保存を止めて知らせる
            config = .unsaved
            loadFailed = true
            saveError = "設定を読み込めませんでした。アプリを開き直してください"
        }
    }

    @ObservationIgnored private var loadFailed = false

    /// App Intent など、MainActor の外から最新の設定を読むとき。まだ何も無ければ空の設定。
    /// Keychain が読めなければ `KeychainStore.ReadError`、中身が読めなければ `DecodingError` を投げる。
    nonisolated static func loadFromKeychain() throws -> DestinationConfig {
        guard let data = try keychain.load() else { return .unsaved }
        do {
            return try DestinationConfig.decode(data)
        } catch {
            configLogger.error("decode failed: \(String(describing: error), privacy: .public)")
            throw error
        }
    }

    /// iPhone での編集。版を 1 つ進め、Keychain に保存できたときだけ画面と時計に反映する。
    @discardableResult
    func update(_ newValue: DestinationConfig) -> Bool {
        var c = newValue
        c.epoch = config.epoch
        c.revision = config.revision
        c = c.nextRevision()
        do {
            try c.validateSize()
        } catch {
            saveError = error.localizedDescription
            return false
        }
        guard save(c) else { return false }
        resync()
        return true
    }

    /// 時計へ送り直す (iPhone のみ。時計とのつながりが変わったときにも呼ぶ)。
    func resync() {
        syncError = onChange?(config)
    }

    /// 起動時に Keychain が読めなかった (ロック中など) とき、前面に来たタイミングで読み直す。
    /// 読めていれば true。変更を作る前に呼ぶ (読めていない空の設定から変更を作って上書きしないため)。
    @discardableResult
    func reloadIfNeeded() -> Bool {
        if loadFailed { load() }
        return !loadFailed
    }

    /// 時計で、iPhone から設定を受け取れなかったとき。
    func setSyncError(_ message: String?) {
        syncError = message
    }

    /// 時計で、iPhone から届いた設定を受け取る。今持っているものより古ければ捨てる。
    func receive(_ incoming: DestinationConfig) {
        guard reloadIfNeeded(), incoming.isNewer(than: config) else { return }
        save(incoming)
    }

    @discardableResult
    private func save(_ c: DestinationConfig) -> Bool {
        // ここで読み直さない: 変更案は読み直す前の設定から作られているので、読めたとしても上書きしてはいけない
        guard !loadFailed else { return false }
        guard let data = try? c.encoded(), Self.keychain.save(data) else {
            saveError = "設定を端末に保存できませんでした"
            return false
        }
        config = c
        saveError = nil
        return true
    }

    @discardableResult
    func upsert(_ destination: Destination) -> Bool {
        guard reloadIfNeeded() else { return false }
        var c = config
        if let i = c.destinations.firstIndex(where: { $0.id == destination.id }) {
            c.destinations[i] = destination
        } else {
            c.destinations.append(destination)
            if c.defaultDestinationID == nil { c.defaultDestinationID = destination.id }
        }
        return update(c)
    }

    func delete(_ id: UUID) {
        guard reloadIfNeeded() else { return }
        var c = config
        c.destinations.removeAll { $0.id == id }
        if c.defaultDestinationID == id { c.defaultDestinationID = c.destinations.first?.id }
        update(c)
    }

    func setDefault(_ id: UUID) {
        guard reloadIfNeeded() else { return }
        var c = config
        c.defaultDestinationID = id
        update(c)
    }
}
