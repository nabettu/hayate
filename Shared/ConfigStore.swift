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
    /// 時計への同期に失敗したときの理由 (iPhone のみ)。
    private(set) var syncError: String?
    /// 保存したあとに呼ばれる。iPhone ではここで時計へ送り、失敗したら理由を返す。
    @ObservationIgnored var onChange: ((DestinationConfig) -> String?)?

    private nonisolated static let keychain = KeychainStore(service: "com.nabettu.watchhook", account: "destination-config")

    init() {
        config = Self.loadFromKeychain()
    }

    /// App Intent など、MainActor の外から最新の設定を読むとき。
    nonisolated static func loadFromKeychain() -> DestinationConfig {
        guard let data = keychain.load() else { return DestinationConfig() }
        do {
            return try DestinationConfig.decode(data)
        } catch {
            configLogger.error("decode failed: \(String(describing: error), privacy: .public)")
            return DestinationConfig()
        }
    }

    /// iPhone での編集。保存日時を付けて Keychain に保存できたときだけ画面と時計に反映する。
    @discardableResult
    func update(_ newValue: DestinationConfig) -> Bool {
        var c = newValue
        c.updatedAt = Date()
        guard save(c) else { return false }
        syncError = onChange?(c)
        return true
    }

    /// 時計で、iPhone から届いた設定を受け取る。今持っているものより古ければ捨てる。
    func receive(_ incoming: DestinationConfig) {
        guard incoming.isNewer(than: config) else { return }
        save(incoming)
    }

    @discardableResult
    private func save(_ c: DestinationConfig) -> Bool {
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
        var c = config
        c.destinations.removeAll { $0.id == id }
        if c.defaultDestinationID == id { c.defaultDestinationID = c.destinations.first?.id }
        update(c)
    }

    func setDefault(_ id: UUID) {
        var c = config
        c.defaultDestinationID = id
        update(c)
    }
}
